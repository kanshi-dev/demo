FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 go build -o /checkout .

FROM scratch
COPY --from=build /checkout /checkout
EXPOSE 8081
ENTRYPOINT ["/checkout"]
