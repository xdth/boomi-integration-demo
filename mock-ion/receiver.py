#!/usr/bin/env python3
import os, re, json
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime
from pathlib import Path
import xml.etree.ElementTree as ET
from xml.dom import minidom

HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8888"))
ENDPOINT = "/boomi/orders"
INBOX = Path(os.getenv("INBOX_DIR", "./inbox"))
INBOX.mkdir(parents=True, exist_ok=True)

# Track duplicates for this process lifetime
SEEN_IDS = set()

ORDER_ID_PAT = re.compile(r"\b(?:ORD|BULK|AUTO)-\d{8}-\d{6}\b")

def pretty_xml(xml_bytes: bytes) -> str:
    try:
        dom = minidom.parseString(xml_bytes)
        return dom.toprettyxml(indent="  ")
    except Exception:
        # Fallback: raw decode
        return xml_bytes.decode("utf-8", errors="replace")

def extract_order_id(root: ET.Element, raw_text: str) -> str | None:
    # Try common tags first
    COMMON_XPATHS = [
        ".//OrderID", ".//OrderId", ".//OrderNumber", ".//Order/ID",
        ".//ID", ".//DocumentID", ".//SalesOrder/OrderID",
        ".//Header/OrderID", ".//OrderHeader/OrderID",
    ]
    for xp in COMMON_XPATHS:
        node = root.find(xp)
        if node is not None and node.text and node.text.strip():
            return node.text.strip()

    # Fallback: pattern seen in your generator (ORD-/BULK-/AUTO-YYYYMMDD-HHMMSS)
    m = ORDER_ID_PAT.search(raw_text)
    return m.group(0) if m else None

class BoomiHandler(BaseHTTPRequestHandler):
    server_version = "MockBoomiReceiver/1.0"

    def log_message(self, fmt, *args):
        # Quieter default logging; keep your own prints
        pass

    def _write(self, code: int, body: dict, content_type="application/json"):
        payload = json.dumps(body).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_POST(self):
        if self.path != ENDPOINT:
            self._write(404, {"error": f"Not found: {self.path}"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        ts = datetime.now().strftime("%Y%m%d-%H%M%S")

        # Try to parse XML
        try:
            root = ET.fromstring(raw)
            is_xml = True
        except ET.ParseError as e:
            is_xml = False
            msg = f"XML parse error: {e}"
            print(f"[{ts}] 400 MALFORMED from {self.client_address[0]} - {msg}")
            # Save raw anyway for debugging
            (INBOX / f"{ts}_malformed.xml").write_bytes(raw)
            meta = {
                "timestamp": ts,
                "client": self.client_address[0],
                "status": 400,
                "reason": "malformed_xml",
                "headers": {k: v for k, v in self.headers.items()},
            }
            (INBOX / f"{ts}_malformed.meta.json").write_text(json.dumps(meta, indent=2))
            self._write(400, {"status": "error", "reason": "malformed_xml", "detail": str(e)})
            return

        # Extract ORDER_ID (best-effort)
        text = raw.decode("utf-8", errors="replace")
        order_id = extract_order_id(root, text) or "UNKNOWN"
        duplicate = order_id in SEEN_IDS

        # Save prettified XML + metadata
        pretty = pretty_xml(raw)
        xml_name = f"{ts}_{order_id}.xml"
        meta_name = f"{ts}_{order_id}.meta.json"
        (INBOX / xml_name).write_text(pretty)
        meta = {
            "timestamp": ts,
            "client": self.client_address[0],
            "status": 409 if duplicate else 200,
            "order_id": order_id,
            "headers": {k: v for k, v in self.headers.items()},
            "bytes": len(raw),
            "endpoint": ENDPOINT,
        }
        (INBOX / meta_name).write_text(json.dumps(meta, indent=2))

        # Console view
        print("=" * 80)
        print(f"[{ts}] POST {ENDPOINT} from {self.client_address[0]}")
        print(f"X-Source: {self.headers.get('X-Source','(none)')} | Content-Type: {self.headers.get('Content-Type')}")
        print(f"ORDER_ID: {order_id} | Size: {len(raw)} bytes")
        print("-" * 80)
        preview = pretty if len(pretty) < 1600 else pretty[:1600] + "\n... [truncated]"
        print(preview)
        print("=" * 80)

        # Respond according to duplicate rule
        if duplicate and order_id != "UNKNOWN":
            self._write(409, {"status": "duplicate", "order_id": order_id})
        else:
            if order_id != "UNKNOWN":
                SEEN_IDS.add(order_id)
            self._write(200, {"status": "ok", "order_id": order_id})

def run():
    httpd = HTTPServer((HOST, PORT), BoomiHandler)
    print(f"📥 Receiver ready on http://{HOST}:{PORT}{ENDPOINT}")
    print(f"   Saving incoming payloads into: {INBOX.resolve()}")
    httpd.serve_forever()

if __name__ == "__main__":
    run()
