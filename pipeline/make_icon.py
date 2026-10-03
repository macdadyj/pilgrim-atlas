#!/usr/bin/env python3
"""Original Pilgrim Atlas icon. A path, a mesa, and a plain cross. Not a church trademark."""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def _icon(size: int) -> Image.Image:
    image = Image.new("RGB", (size, size), "#1C3D5A")
    draw = ImageDraw.Draw(image)
    for y in range(size):
        t = y / size
        red = int(28 + (196 - 28) * t)
        green = int(61 + (107 - 61) * t)
        blue = int(90 + (74 - 90) * t)
        draw.line([(0, y), (size, y)], fill=(red, green, blue))
    mesa = [
        (0, int(size * 0.78)),
        (int(size * 0.18), int(size * 0.62)),
        (int(size * 0.36), int(size * 0.70)),
        (int(size * 0.55), int(size * 0.48)),
        (int(size * 0.72), int(size * 0.60)),
        (int(size * 0.86), int(size * 0.42)),
        (size, int(size * 0.55)),
        (size, size),
        (0, size),
    ]
    draw.polygon(mesa, fill="#2C241C")
    path = [
        (int(size * 0.16), int(size * 0.86)),
        (int(size * 0.30), int(size * 0.74)),
        (int(size * 0.40), int(size * 0.78)),
        (int(size * 0.52), int(size * 0.62)),
        (int(size * 0.66), int(size * 0.66)),
        (int(size * 0.78), int(size * 0.50)),
    ]
    draw.line(path, fill="#E6D3A3", width=max(4, size // 48), joint="curve")
    cx, cy = path[-1]
    arm = size // 16
    thick = max(6, size // 40)
    draw.rectangle([cx - thick // 2, cy - arm, cx + thick // 2, cy + arm], fill="#F2E2B6")
    draw.rectangle([cx - arm, cy - thick // 2, cx + int(arm * 0.72), cy + thick // 2], fill="#F2E2B6")
    margin = size // 14
    box = [margin, margin, margin + size // 5, margin + size // 5]
    draw.ellipse(box, outline="#E6D3A3", width=max(3, size // 80))
    mid_x = (box[0] + box[2]) // 2
    mid_y = (box[1] + box[3]) // 2
    draw.line([(mid_x, box[1] + 6), (mid_x, box[3] - 6)], fill="#E6D3A3", width=max(2, size // 160))
    draw.line([(box[0] + 6, mid_y), (box[2] - 6, mid_y)], fill="#E6D3A3", width=max(2, size // 160))
    return image


def _marker(kind: str, size: int = 64) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if kind == "catholic":
        draw.ellipse([4, 4, size - 4, size - 4], fill="#8C2F39")
        draw.rectangle([size // 2 - 4, 14, size // 2 + 4, size - 16], fill="#F2E2B6")
        draw.rectangle([18, size // 2 - 8, size - 22, size // 2], fill="#F2E2B6")
    elif kind == "worship":
        draw.ellipse([4, 4, size - 4, size - 4], fill="#3D5A80")
        draw.ellipse([size // 2 - 6, size // 2 - 6, size // 2 + 6, size // 2 + 6], fill="#E7EEF6")
    else:
        draw.polygon(
            [(size // 2, 6), (size - 8, size // 2), (size // 2, size - 6), (8, size // 2)],
            fill="#8C5A3C",
        )
    return image


def main() -> None:
    icons = ROOT / "Sources" / "PilgrimAtlas" / "Resources"
    icons.mkdir(parents=True, exist_ok=True)
    _icon(1024).save(ROOT / "AppIcon.png", "PNG")
    _marker("catholic").save(icons / "marker-catholic.png")
    _marker("worship").save(icons / "marker-worship.png")
    _marker("landmark").save(icons / "marker-landmark.png")


if __name__ == "__main__":
    main()
