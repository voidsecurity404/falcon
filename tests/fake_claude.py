#!/usr/bin/env python3
# Soxta `claude` buyrug'i: testlarda AI chatning Claude Code yo'lini sinash uchun.
import json, os, sys, time
args = sys.argv[1:]
if args[:2] == ["auth", "status"]:
    print(json.dumps({"loggedIn": True, "authMethod": "claude.ai"}))
    sys.exit(0)
with open("/tmp/fake-claude.log", "a") as log:
    log.write(json.dumps({"args": args, "api_key": os.environ.get("ANTHROPIC_API_KEY"), "token": os.environ.get("ANTHROPIC_AUTH_TOKEN"), "cwd": os.getcwd(), "pid": os.getpid()}) + "\n")
def value(flag):
    return args[args.index(flag) + 1] if flag in args else None
prompt = sys.stdin.read().strip()
resume = value("--resume")
def out(**d):
    print(json.dumps(d), flush=True)
if resume == "lost-session":
    out(type="result", subtype="error_during_execution", is_error=True, result="No conversation found with session ID: lost-session", session_id="x", stop_reason=None)
    sys.exit(1)
sid = resume or "session-1"
out(type="system", subtype="init", session_id=sid, tools=[])
if "login" in prompt:
    out(type="result", subtype="success", is_error=True, result="Not logged in · Please run /login", session_id=sid, stop_reason=None)
    sys.exit(1)
if "limit" in prompt:
    out(type="result", subtype="success", is_error=True, result="You've hit your limit · resets 3pm", session_id=sid, stop_reason=None)
    sys.exit(1)
if "refuse" in prompt:
    out(type="result", subtype="success", is_error=False, result="", session_id=sid, stop_reason="refusal")
    sys.exit(0)
for word in ["Salom, ", "bu ", "javob: ", prompt[:40]]:
    out(type="stream_event", session_id=sid, event={"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": word}})
    time.sleep(4 if "sekin" in prompt else 0.03)
out(type="result", subtype="success", is_error=False, result="done", session_id=sid, stop_reason="max_tokens" if "uzun" in prompt else "end_turn")
