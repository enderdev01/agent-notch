#!/usr/bin/env python3
"""Builds packaging/AppIcon.icns: the three mascots under a notch on a dark rounded square.

Usage: scripts/make-icon.py   (needs Pillow and macOS `iconutil`)
"""
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "Sources/AgentNotch/Resources/Mascots"
OUT = ROOT / "packaging/AppIcon.icns"
AGENT_COLORS = {"claude": (217, 119, 87), "codex": (124, 92, 255), "gentle": (236, 74, 131)}

S = 1024
BODY = 824  # macOS icon grid: the artwork sits inside a 100 px margin
MARGIN = (S - BODY) // 2


def gradient(size, top, bottom):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        row = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(size):
            px[x, y] = row
    return img


def build():
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    body = gradient(BODY, (44, 44, 52), (14, 14, 18)).convert("RGBA")
    mask = Image.new("L", (BODY, BODY), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, BODY - 1, BODY - 1), radius=int(BODY * 0.2237), fill=255)
    body.putalpha(mask)

    d = ImageDraw.Draw(body)
    # Notch: black tab hanging from the top edge, with the accent line along its bottom.
    nw, nh = 380, 120
    nx = (BODY - nw) // 2
    d.rounded_rectangle((nx, -40, nx + nw, nh), radius=46, fill=(0, 0, 0, 255))
    colors = list(AGENT_COLORS.values())
    for x in range(nx + 40, nx + nw - 40):
        t = (x - nx - 40) / (nw - 80) * (len(colors) - 1)
        i = min(int(t), len(colors) - 2)
        f = t - i
        c = tuple(int(colors[i][k] + (colors[i + 1][k] - colors[i][k]) * f) for k in range(3))
        d.line((x, nh - 14, x, nh - 8), fill=c + (255,))

    size, gap = 250, 12
    total = size * 3 + gap * 2
    x0 = (BODY - total) // 2
    y0 = 320
    for i, agent in enumerate(AGENT_COLORS):
        sprite = Image.open(SPRITES / f"{agent}.png").convert("RGBA").resize((size, size), Image.LANCZOS)
        body.alpha_composite(sprite, (x0 + i * (size + gap), y0))

    canvas.alpha_composite(body, (MARGIN, MARGIN))
    return canvas


def main():
    icon = build()
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        for base in (16, 32, 128, 256, 512):
            icon.resize((base, base), Image.LANCZOS).save(iconset / f"icon_{base}x{base}.png")
            icon.resize((base * 2, base * 2), Image.LANCZOS).save(iconset / f"icon_{base}x{base}@2x.png")
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(OUT)], check=True)
        icon.save(Path(tmp) / "preview.png")
        (ROOT / "build").mkdir(exist_ok=True)
        icon.save(ROOT / "build/AppIcon-preview.png")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
