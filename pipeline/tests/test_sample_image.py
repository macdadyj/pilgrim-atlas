"""Open a sample image and run it through the terrain decoders.

The pack downloads terrarium PNGs and opens them with Pillow. This stays
offline: it writes a small PNG, opens that file, and derives elevation and a
hillshade JPEG the same way the pack does.
"""

from io import BytesIO
from pathlib import Path

import numpy as np
from PIL import Image

from pilgrim.terrain import _contours, _elevation, _hillshade_jpeg


def _write_sample_terrarium(path: Path) -> None:
    height, width = 16, 16
    rgb = np.zeros((height, width, 3), dtype=np.uint8)
    for y in range(height):
        for x in range(width):
            meters = 1800 + x * 40 + y * 10
            value = meters + 32768
            rgb[y, x, 0] = (value // 256) & 255
            rgb[y, x, 1] = value & 255
    Image.fromarray(rgb, "RGB").save(path, format="PNG")


def test_open_and_process_sample_image(tmp_path: Path) -> None:
    path = tmp_path / "sample.png"
    _write_sample_terrarium(path)
    with Image.open(path) as image:
        loaded = image.convert("RGB")
        grid = _elevation(loaded)
        jpeg = _hillshade_jpeg(loaded, zoom=12, lat=35.7)
        lines = _contours(loaded, (-106.1, 35.6, -105.9, 35.8))
    assert loaded.size == (16, 16)
    assert grid.shape == (16, 16)
    assert float(grid.max()) - float(grid.min()) > 100
    assert jpeg[:3] == b"\xff\xd8\xff"
    with Image.open(BytesIO(jpeg)) as shade:
        shade.load()
        assert shade.size == (16, 16)
        assert shade.mode == "RGB"
        assert len(set(shade.tobytes())) > 1
    assert lines
