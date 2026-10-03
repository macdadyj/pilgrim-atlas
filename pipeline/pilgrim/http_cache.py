"""One polite download per URL, then the cache."""

import time
import urllib.request
from pathlib import Path

USER_AGENT = (
    "PilgrimAtlasPackBuilder/0.1 "
    "(offline northern New Mexico pack; https://github.com/macdadyj/pilgrim-atlas)"
)


def fetch(url: str, dest: Path, *, minimum_bytes: int = 1000) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size >= minimum_bytes:
        return dest
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=180) as response:
        payload = response.read()
    if len(payload) < minimum_bytes:
        raise RuntimeError(f"Download too small ({len(payload)} bytes): {url}")
    dest.write_bytes(payload)
    time.sleep(1)
    return dest
