#!/usr/bin/env python3
"""Builds docs/images/mascots.png: every agent's mascot in six states, for the README.

Usage: scripts/make-mascot-sheet.py   (needs Pillow and the macOS Avenir Next font)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "Sources/AgentNotch/Resources/Mascots"
OUT = ROOT / "docs/images/mascots.png"
FONT = "/System/Library/Fonts/Avenir Next.ttc"  # index 2 demi bold, 5 medium

STATES = [("", "idle"), ("-work", "working"), ("-alert", "needs you"), ("-done", "done"), ("-error", "error"), ("-sleep", "asleep")]
# (sprite prefix, label, accent color). The label is the product name, not the folder spelling.
AGENTS = [("claude", "Claude Code", (217, 119, 87)), ("codex", "Codex", (139, 108, 255)), ("gentle", "Gentle Shell", (236, 74, 131))]
CELL, LABEL_W, TOP = 150, 190, 64


def font(size, index):
    return ImageFont.truetype(FONT, size, index=index)


def vgrad(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        d.line((0, y, w, y), fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img


def main():
    w, h = LABEL_W + CELL * len(STATES) + 24, TOP + CELL * len(AGENTS) + 16
    sheet = vgrad(w, h, (30, 30, 40), (16, 16, 22)).convert("RGBA")
    d = ImageDraw.Draw(sheet)
    for j, (_, label) in enumerate(STATES):
        tw = d.textlength(label, font=font(20, 5))
        d.text((LABEL_W + j * CELL + (CELL - tw) / 2, 22), label, font=font(20, 5), fill=(170, 170, 185))
    for i, (prefix, name, color) in enumerate(AGENTS):
        y = TOP + i * CELL
        d.text((24, y + CELL / 2 - 14), name, font=font(24, 2), fill=color)
        for j, (suffix, _) in enumerate(STATES):
            sprite = Image.open(SPRITES / f"{prefix}{suffix}.png").convert("RGBA").resize((128, 128), Image.LANCZOS)
            sheet.alpha_composite(sprite, (LABEL_W + j * CELL + 11, y + 11))
    mask = Image.new("L", sheet.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=28, fill=255)
    out = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    out.paste(sheet, (0, 0), mask)
    out.save(OUT, optimize=True)
    print(f"wrote {OUT} {out.size}")


if __name__ == "__main__":
    main()
