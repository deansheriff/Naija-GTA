"""Create a self-contained static browser build with compressed engine delivery."""
from pathlib import Path
import gzip
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build" / "web" / "play"
SITE = ROOT / "web"
DIST = SITE / "dist"
PLAY = DIST / "play"
PLAY.mkdir(parents=True, exist_ok=True)
for item in SOURCE.iterdir():
    if item.is_file() and item.suffix != ".wasm":
        shutil.copy2(item, PLAY / item.name)
wasm = (SOURCE / "index.wasm").read_bytes()
engine_hash = hashlib.sha256((SOURCE / "index.js").read_bytes()).hexdigest()[:12]
shell_path = PLAY / "index.html"
shell_path.write_text(shell_path.read_text(encoding="utf-8").replace('src="index.js"', f'src="index.js?v={engine_hash}"').rstrip() + "\n", encoding="utf-8")
(PLAY / "index.wasm.gz").write_bytes(gzip.compress(wasm, compresslevel=9, mtime=0))
shutil.copy2(SITE / "index.html", DIST / "index.html")
shutil.copy2(ROOT / "game" / "icon.svg", DIST / "icon.svg")
shutil.copy2(ROOT / "game" / "assets" / "street-painted.png", DIST / "street-painted.png")
report = {"version": "0.4.1", "engine": "4.6.3", "files": []}
for item in sorted(PLAY.iterdir()):
    if item.is_file():
        report["files"].append({"name": item.name, "bytes": item.stat().st_size, "sha256": hashlib.sha256(item.read_bytes()).hexdigest()})
(DIST / "build-info.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
total = sum(item["bytes"] for item in report["files"])
print(f"Browser artifact: {total / 1048576:.2f} MiB total; raw engine {len(wasm) / 1048576:.2f} MiB")
