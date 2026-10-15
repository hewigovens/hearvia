#!/usr/bin/env python3
"""Probe whether a ChatGPT plan (Sign in with ChatGPT, open-source flow) can power Hearvia.

1. OAuth (PKCE, loopback 127.0.0.1:1455) with dynamic client registration.
2. GET /v1/models with the plan token.
3. Streams a short text translation through the Responses API and times it.
Then run hearvia-translate with the printed token to test the Realtime endpoint.

Credentials: ~/.config/hearvia/chatgpt.json (0600). Never commit or log them.
Test-only: the ID token signature is not verified here.
"""
import base64, hashlib, http.server, json, os, secrets, sys, time, urllib.parse, urllib.request, uuid, webbrowser

CONFIG = os.path.expanduser("~/.config/hearvia")
CREDS = os.path.join(CONFIG, "chatgpt.json")
HOST_ID = os.path.join(CONFIG, "host_id")
AUTH = "https://auth.openai.com/api/accounts/authorize"
TOKEN = "https://auth.openai.com/api/accounts/oauth/token"
RESOURCE = "https://api.openai.com/v1"
REDIRECT = "http://127.0.0.1:1455/auth/callback"
SCOPES = "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"


def save(path, text):
    os.makedirs(CONFIG, mode=0o700, exist_ok=True)
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def host_id():
    if os.path.exists(HOST_ID):
        return open(HOST_ID).read().strip()
    value = f"urn:uuid:{uuid.uuid4()}"
    save(HOST_ID, value)
    return value


def post_form(url, fields):
    req = urllib.request.Request(url, data=urllib.parse.urlencode(fields).encode(),
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"token endpoint {e.code}: {e.read().decode()[:500]}")


def sign_in(saved_client_id=None):
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state, nonce = secrets.token_urlsafe(24), secrets.token_urlsafe(24)
    params = {"client_id": saved_client_id or "dynamic_agent_client", "ext_agent_host_id": host_id(),
              "response_type": "code", "redirect_uri": REDIRECT, "scope": SCOPES, "resource": RESOURCE,
              "state": state, "nonce": nonce, "code_challenge_method": "S256", "code_challenge": challenge}
    if not saved_client_id:
        params["agent_name_hint"] = "Hearvia"
    result = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            url = urllib.parse.urlparse(self.path)
            if url.path != "/auth/callback":
                self.send_response(404); self.end_headers(); return
            result.update({k: v[0] for k, v in urllib.parse.parse_qs(url.query).items()})
            self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8"); self.end_headers()
            self.wfile.write("<h2>Hearvia: sign-in received. You can close this tab.</h2>".encode())
        def log_message(self, *a): pass

    server = http.server.HTTPServer(("127.0.0.1", 1455), Handler)  # listener first, then browser
    url = AUTH + "?" + urllib.parse.urlencode(params)
    print("Opening browser for Sign in with ChatGPT. If nothing opens, visit:\n" + url, flush=True)
    webbrowser.open(url)
    server.timeout = 5
    deadline = time.time() + 900
    while not result:
        if time.time() > deadline:
            server.server_close(); sys.exit("timed out waiting for the browser callback")
        server.handle_request()
    server.server_close()
    if result.get("state") != state:
        sys.exit("state mismatch")
    if "error" in result:
        sys.exit(f"authorization error: {result}")
    client_id = saved_client_id or result.get("client_id")
    if not client_id or client_id == "dynamic_agent_client":
        sys.exit(f"registration incomplete, callback: {sorted(result)}")
    tokens = post_form(TOKEN, {"grant_type": "authorization_code", "client_id": client_id, "code": result["code"],
                               "code_verifier": verifier, "redirect_uri": REDIRECT, "resource": RESOURCE})
    record = dict(tokens, client_id=client_id, ext_agent_host_id=host_id(), saved_at=time.time())
    save(CREDS, json.dumps(record, indent=2))
    return record


def refresh(record):
    tokens = post_form(TOKEN, {"grant_type": "refresh_token", "client_id": record["client_id"],
                               "refresh_token": record["refresh_token"], "resource": RESOURCE})
    record.update(tokens, saved_at=time.time())
    save(CREDS, json.dumps(record, indent=2))
    return record


def credentials():
    if os.path.exists(CREDS):
        record = json.load(open(CREDS))
        if time.time() < record["saved_at"] + record.get("expires_in", 3600) - 120:
            return record
        return refresh(record)
    return sign_in()


def api(path, body=None, token=None):
    req = urllib.request.Request(RESOURCE + path, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    return urllib.request.urlopen(req, timeout=60)


def main():
    record = credentials()
    token = record["access_token"]
    scopes = record.get("scope", "")
    print(f"granted scopes: {scopes}")
    if "chatgpt.tokens.use.direct" not in scopes:
        sys.exit("ChatGPT plan usage was not granted")

    try:
        models = json.load(api("/models", token=token))
        listed = [m.get("slug") for m in models.get("models", []) if m.get("visibility") == "list"]
        print(f"models: {listed}")
    except urllib.error.HTTPError as e:
        print(f"/models {e.code}: {e.read().decode()[:300]}"); listed = []

    model = os.environ.get("MODEL") or (listed[-1] if listed else "gpt-6.1-sol")
    sentence = "Researchers followed two hundred volunteers for six months, and those who kept a consistent bedtime fell asleep twenty minutes faster."
    body = {"model": model, "store": False, "stream": True, **({"reasoning": {"effort": os.environ["EFFORT"]}} if os.environ.get("EFFORT") else {}),
            "instructions": "You translate live subtitles. Output only the Simplified Chinese translation, nothing else.",
            "input": [{"role": "user", "content": sentence}]}
    start = time.time(); first = None; text = ""; final = "?"
    try:
        with api("/responses", body, token) as stream:
            for raw in stream:
                line = raw.decode().strip()
                if not line.startswith("data:"):
                    continue
                event = json.loads(line[5:])
                kind = event.get("type")
                if kind == "response.output_text.delta":
                    first = first or time.time() - start
                    text += event["delta"]
                elif kind in ("response.completed", "response.failed", "response.incomplete"):
                    final = kind
                    if kind != "response.completed":
                        print(json.dumps(event.get("response", {}).get("error"), ensure_ascii=False))
    except urllib.error.HTTPError as e:
        print(f"/responses {e.code}: {e.read().decode()[:500]}")
    print(f"model={model} result={final} first_token={first and round(first, 2)}s total={round(time.time() - start, 2)}s")
    print(f"translation: {text}")


if __name__ == "__main__":
    if sys.argv[1:] == ["--token"]:
        print(credentials()["access_token"])
    else:
        main()
