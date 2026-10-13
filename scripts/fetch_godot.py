"""Fetch official portable Godot and only the export templates we use.

Range reads avoid downloading the 1.2GB all-platform template archive.
ZipFile validates each extracted entry's CRC. The editor is SHA512-verified.
"""
import hashlib
import io
import json
from pathlib import Path
import shutil
import time
import urllib.request
import zipfile

VERSION = "4.6.3-stable"
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / ".tools"
BASE = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}/"


def request(url, headers=None):
    for attempt in range(4):
        try:
            return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "NaijaStreetLife-build", **(headers or {})}), timeout=60)
        except (OSError, urllib.error.URLError):
            if attempt == 3:
                raise
            time.sleep(1 + attempt)


class RangeArchive(io.RawIOBase):
    def __init__(self, url):
        self.url = url
        self.pos = 0
        with request(url, {"Range": "bytes=0-0"}) as response:
            content_range = response.headers.get("Content-Range")
            if response.status != 206 or not content_range:
                raise RuntimeError("Template host did not support range requests")
            self.size = int(content_range.split("/")[-1])
            self.url = response.url

    def seekable(self):
        return True

    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.size + offset
        return self.pos

    def tell(self):
        return self.pos

    def read(self, amount=-1):
        if amount < 0:
            amount = self.size - self.pos
        amount = min(amount, self.size - self.pos)
        if amount <= 0:
            return b""
        with request(self.url, {"Range": f"bytes={self.pos}-{self.pos + amount - 1}"}) as response:
            if response.status != 206:
                raise RuntimeError("Unexpected full-archive response")
            chunk = response.read()
        if len(chunk) != amount:
            raise RuntimeError(f"Incomplete range {len(chunk)}/{amount}")
        self.pos += len(chunk)
        return chunk


def main():
    DEST.mkdir(exist_ok=True)
    editor_name = f"Godot_v{VERSION}_win64.exe.zip"
    editor_zip = DEST / editor_name
    with request(BASE + "SHA512-SUMS.txt") as response:
        checksums = response.read().decode()
    expected = next(line.split()[0] for line in checksums.splitlines() if line.split()[-1].lstrip("*") == editor_name)
    if not editor_zip.exists():
        print("Downloading portable editor", flush=True)
        with request(BASE + editor_name) as response, editor_zip.open("wb") as output:
            shutil.copyfileobj(response, output)
    actual = hashlib.sha512(editor_zip.read_bytes()).hexdigest()
    if actual != expected:
        raise RuntimeError("Editor SHA512 did not match official release")
    editor_dir = DEST / "godot"
    with zipfile.ZipFile(editor_zip) as archive:
        archive.extractall(editor_dir)
    print("Editor checksum verified", flush=True)
    template_dir = DEST / "templates"
    template_dir.mkdir(exist_ok=True)
    names = {"web_nothreads_release.zip", "web_nothreads_debug.zip", "android_debug.apk", "android_release.apk", "android_source.zip"}
    missing = []
    for name in names:
        try:
            with zipfile.ZipFile(template_dir / name) as existing:
                if existing.testzip() is not None:
                    missing.append(name)
        except (OSError, zipfile.BadZipFile):
            missing.append(name)
    if missing:
        print("Reading remote template archive index", flush=True)
        with zipfile.ZipFile(RangeArchive(BASE + f"Godot_v{VERSION}_export_templates.tpz")) as archive:
            for name in missing:
                info = next(info for info in archive.infolist() if info.filename.split("/")[-1] == name)
                print(f"Fetching {name}: {info.compress_size / 1024 / 1024:.1f} MB", flush=True)
                temporary = template_dir / (name + ".part")
                with archive.open(info) as source, temporary.open("wb") as output:
                    shutil.copyfileobj(source, output, 4 * 1024 * 1024)
                temporary.replace(template_dir / name)
    (editor_dir / "_sc_").touch()
    installed = editor_dir / "editor_data" / "export_templates" / "4.6.3.stable"
    installed.mkdir(parents=True, exist_ok=True)
    for name in names:
        shutil.copy2(template_dir / name, installed / name)
    print(json.dumps({"editor": str(editor_dir), "templates": str(template_dir), "version": VERSION}), flush=True)


if __name__ == "__main__":
    main()
