"""Minimal webhook sink for the Kanshi alerting demo.

Logs each received alert webhook (signature header and JSON body) to stdout so
you can watch deliveries with `docker compose logs -f alert-sink`.
"""
import http.server


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode()
        print("--- alert webhook received ---", flush=True)
        print("X-Kanshi-Signature:", self.headers.get("X-Kanshi-Signature", "(unsigned)"), flush=True)
        print(body, flush=True)
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):
        pass


http.server.HTTPServer(("0.0.0.0", 9000), Handler).serve_forever()
