package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	otellog "go.opentelemetry.io/otel/log"
	"go.opentelemetry.io/otel/log/global"
	sdklog "go.opentelemetry.io/otel/sdk/log"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/semconv/v1.39.0"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	res, err := resource.New(ctx, resource.WithAttributes(semconv.ServiceName("checkout")))
	if err != nil {
		log.Fatal(err)
	}
	traceExporter, err := otlptracegrpc.New(ctx, otlptracegrpc.WithInsecure())
	if err != nil {
		log.Fatal(err)
	}
	logExporter, err := otlploggrpc.New(ctx, otlploggrpc.WithInsecure())
	if err != nil {
		log.Fatal(err)
	}

	traces := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExporter),
		sdktrace.WithResource(res),
	)
	logs := sdklog.NewLoggerProvider(
		sdklog.WithProcessor(sdklog.NewBatchProcessor(logExporter)),
		sdklog.WithResource(res),
	)
	otel.SetTracerProvider(traces)
	global.SetLoggerProvider(logs)

	client := &http.Client{
		Transport: otelhttp.NewTransport(http.DefaultTransport),
		Timeout:   5 * time.Second,
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/checkout", func(w http.ResponseWriter, r *http.Request) {
		request, err := http.NewRequestWithContext(r.Context(), http.MethodGet, os.Getenv("PAYMENTS_URL"), nil)
		if err != nil {
			http.Error(w, "invalid payment request", http.StatusInternalServerError)
			return
		}
		response, err := client.Do(request)
		if err != nil {
			http.Error(w, "payment unavailable", http.StatusBadGateway)
			return
		}
		defer response.Body.Close()

		var record otellog.Record
		record.SetTimestamp(time.Now())
		record.SetSeverity(otellog.SeverityInfo)
		record.SetBody(otellog.StringValue("checkout completed"))
		global.Logger("checkout").Emit(r.Context(), record)
		w.WriteHeader(response.StatusCode)
		fmt.Fprintln(w, "checkout completed")
	})

	server := &http.Server{
		Addr:              ":8081",
		Handler:           otelhttp.NewHandler(mux, "checkout"),
		ReadHeaderTimeout: 5 * time.Second,
	}
	go func() {
		log.Printf("checkout listening on %s", server.Addr)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	}()

	<-ctx.Done()
	shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = server.Shutdown(shutdown)
	_ = logs.Shutdown(shutdown)
	_ = traces.Shutdown(shutdown)
}
