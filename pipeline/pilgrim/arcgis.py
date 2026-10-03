"""BBox queries against public ArcGIS services. Cached. One page at a time."""

import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

from .http_cache import USER_AGENT


def query_features(base_url: str, params: dict, cache_path: Path, page_size: int = 8) -> list[dict]:
    if cache_path.exists() and cache_path.stat().st_size > 50:
        return json.loads(cache_path.read_text(encoding="utf-8"))
    features: list[dict] = []
    offset = 0
    while True:
        page = dict(params)
        page.update(
            {
                "f": "geojson",
                "outSR": "4326",
                "returnGeometry": "true",
                "resultOffset": str(offset),
                "resultRecordCount": str(page_size),
            }
        )
        url = base_url + "?" + urllib.parse.urlencode(page)
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=180) as response:
            payload = json.loads(response.read().decode("utf-8"))
        if "error" in payload:
            raise RuntimeError(f"{base_url}: {payload['error']}")
        batch = payload.get("features") or []
        features.extend(batch)
        exceeded = payload.get("exceededTransferLimit") or (payload.get("properties") or {}).get(
            "exceededTransferLimit"
        )
        if not batch or (len(batch) < page_size and not exceeded):
            break
        offset += len(batch)
        if offset > 400:
            break
        time.sleep(1)
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(json.dumps(features), encoding="utf-8")
    return features
