"""Local review server. Bind loopback only; no external service credentials."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--port", type=int, default=8765)
args = parser.parse_args()
directory = Path(__file__).resolve().parents[1] / "web" / "dist"
handler = partial(SimpleHTTPRequestHandler, directory=str(directory))
server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
print(f"Naija Street Life: http://127.0.0.1:{args.port}/", flush=True)
server.serve_forever()
