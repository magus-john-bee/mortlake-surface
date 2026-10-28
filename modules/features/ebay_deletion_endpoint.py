# Marketplace Account Deletion endpoint (eBay production keyset gate)
# GET /ebay-deletion?challenge_code=X returns the challenge hash;
# POST /ebay-deletion acks + logs deletion notifications.

import hashlib
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

TOKEN_FILE = os.environ.get(
    "EBAY_VERIFICATION_TOKEN_FILE", "/run/secrets/ebay-verification-token"
)
ENDPOINT_URL = os.environ["EBAY_ENDPOINT_URL"]
PORT = int(os.environ.get("PORT", "8647"))


def token() -> str:
    with open(TOKEN_FILE) as f:
        return f.read().strip()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        u = urlparse(self.path)
        if u.path.rstrip("/") != "/ebay-deletion":
            self.send_error(404)
            return
        code = parse_qs(u.query).get("challenge_code", [""])[0]
        digest = hashlib.sha256((code + token() + ENDPOINT_URL).encode()).hexdigest()
        body = json.dumps({"challengeResponse": digest}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        payload = self.rfile.read(length)
        # Notifications land in the systemd journal (stderr) — no state
        # directory needed, nothing to persist, review with journalctl.
        sys.stderr.write(
            "DELETION NOTIFICATION "
            + json.dumps(
                {
                    "ts": self.log_date_time_string(),
                    "signature": self.headers.get("X-Ebay-Signature", ""),
                    "body": payload.decode("utf-8", "replace"),
                }
            )
            + "\n"
        )
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.log_date_time_string(), fmt % args))


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
