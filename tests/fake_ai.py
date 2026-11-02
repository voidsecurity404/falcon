#!/usr/bin/env python3
# Soxta Messages API: faqat test uchun, VM ichida 127.0.0.1 da ishlaydi.
import json, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
LOG = "/tmp/fake-ai.log"
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["content-length"])))
        open(LOG, "a").write(json.dumps({"path": self.path, "beta": self.headers.get("anthropic-beta"), "key": self.headers.get("x-api-key"), "body": body}, ensure_ascii=False) + "\n")
        last = body["messages"][-1]["content"]
        last = last if isinstance(last, str) else json.dumps(last)
        if "401" in last: return self.err(401, "authentication_error")
        if "429" in last: return self.err(429, "rate_limit_error")
        if "500" in last: return self.err(500, "api_error")
        stop = "refusal" if "refuse" in last else "max_tokens" if "uzun" in last else "end_turn"
        self.send_response(200); self.send_header("content-type", "text/event-stream"); self.end_headers()
        def ev(name, data):
            self.wfile.write(f"event: {name}\ndata: {json.dumps(data)}\n\n".encode()); self.wfile.flush()
        ev("message_start", {"type": "message_start", "message": {"id": "msg_1", "type": "message", "role": "assistant", "model": body["model"], "content": [], "stop_reason": None, "stop_sequence": None, "usage": {"input_tokens": 1, "output_tokens": 1}}})
        ev("content_block_start", {"type": "content_block_start", "index": 0, "content_block": {"type": "thinking", "thinking": "", "signature": ""}})
        ev("content_block_delta", {"type": "content_block_delta", "index": 0, "delta": {"type": "signature_delta", "signature": "sig123"}})
        ev("content_block_stop", {"type": "content_block_stop", "index": 0})
        ev("content_block_start", {"type": "content_block_start", "index": 1, "content_block": {"type": "text", "text": ""}})
        slow = "sekin" in last
        for w in ["Salom, ", "bu ", "javob: ", last[:40]]:
            ev("content_block_delta", {"type": "content_block_delta", "index": 1, "delta": {"type": "text_delta", "text": w}})
            time.sleep(4 if slow else 0.05)
        ev("content_block_stop", {"type": "content_block_stop", "index": 1})
        ev("message_delta", {"type": "message_delta", "delta": {"stop_reason": stop, "stop_sequence": None}, "usage": {"output_tokens": 5}})
        ev("message_stop", {"type": "message_stop"})
    def err(self, code, kind):
        p = json.dumps({"type": "error", "error": {"type": kind, "message": kind}}).encode()
        self.send_response(code); self.send_header("content-type", "application/json"); self.send_header("content-length", str(len(p))); self.end_headers(); self.wfile.write(p)
ThreadingHTTPServer(("127.0.0.1", 8765), H).serve_forever()
