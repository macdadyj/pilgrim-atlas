#!/usr/bin/env python3
"""Original Pilgrim Atlas icon. A path, a mesa, and a plain cross. Not a church trademark."""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def _icon(size: int) -> Image.Image:
    image = Image.new("RGB", (size, size), "#F4EBD8")
    draw = ImageDraw.Draw(image)
    draw.rectangle([0, int(size * 0.72), size, size], fill="#E4D2B4")
    mesa = [
        (0, int(size * 0.72)),
        (int(size * 0.22), int(size * 0.56)),
        (int(size * 0.40), int(size * 0.66)),
        (int(size * 0.62), int(size * 0.44)),
        (int(size * 0.80), int(size * 0.58)),
        (size, int(size * 0.48)),
        (size, int(size * 0.72)),
    ]
    draw.polygon(mesa, fill="#6E5344")
    path = [
        (int(size * 0.16), int(size * 0.88)),
        (int(size * 0.34), int(size * 0.78)),
        (int(size * 0.48), int(size * 0.80)),
        (int(size * 0.64), int(size * 0.66)),
        (int(size * 0.76), int(size * 0.58)),
    ]
    draw.line(path, fill="#C4553A", width=max(12, size // 24), joint="curve")
    cx, cy = path[-1]
    arm = size // 10
    thick = max(14, size // 20)
    draw.rectangle([cx - thick // 2, cy - arm, cx + thick // 2, cy + int(arm * 0.9)], fill="#7A2E36")
    draw.rectangle([cx - arm, cy - thick // 2, cx + int(arm * 0.75), cy + thick // 2], fill="#7A2E36")
    return image


def _marker(kind: str, size: int = 64) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if kind == "catholic":
        draw.ellipse([2, 2, size - 2, size - 2], fill="#8C2F39")
        thick = 14
        cx = size // 2
        top = 10
        bottom = size - 10
        draw.rectangle([cx - thick // 2, top, cx + thick // 2, bottom], fill="#F4EBD8")
        bar_top = top + (bottom - top) // 3
        draw.rectangle([10, bar_top, size - 10, bar_top + thick], fill="#F4EBD8")
    elif kind == "worship":
        draw.ellipse([2, 2, size - 2, size - 2], fill="#2F5D8C")
        draw.ellipse([size // 2 - 11, size // 2 - 11, size // 2 + 11, size // 2 + 11], fill="#F4EBD8")
    else:
        draw.polygon(
            [(size // 2, 4), (size - 5, size // 2), (size // 2, size - 4), (5, size // 2)],
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
