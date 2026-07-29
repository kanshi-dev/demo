import http.server
import json
import os
import threading
import time
import urllib.request


API = "http://core:8080/api/v1"
RULE_NAME = "Demo high memory"


def request(url, *, data=None):
    headers = {"Authorization": f"Bearer {os.environ['KANSHI_DASHBOARD_KEY']}"}
    if data is not None:
        data = json.dumps(data).encode()
        headers["Content-Type"] = "application/json"
    with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers)) as response:
        return json.load(response)


def drive_demo():
    try:
        rules = request(f"{API}/alerts/rules")["data"]
        if not any(rule["name"] == RULE_NAME for rule in rules):
            request(f"{API}/alerts/rules", data={
                "name": RULE_NAME,
                "metric": "mem.used_percent",
                "comparator": "gt",
                "threshold": 1,
                "enabled": True,
            })
            print(f"created alert rule: {RULE_NAME}", flush=True)
    except Exception as error:
        print(f"could not create alert rule: {error}", flush=True)

    interval = int(os.getenv("DEMO_INTERVAL_SECONDS", "30"))
    print(f"generating checkout traffic every {interval}s", flush=True)
    while True:
        try:
            urllib.request.urlopen("http://checkout:8081/checkout").read()
        except Exception:
            pass
        time.sleep(interval)


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


threading.Thread(target=drive_demo, daemon=True).start()
http.server.HTTPServer(("0.0.0.0", 9000), Handler).serve_forever()
