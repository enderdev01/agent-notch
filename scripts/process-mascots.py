#!/usr/bin/env python3
"""Turns raw APIMart mascot art into app sprites.

Reads  Sources/AgentNotch/Resources/mascots-raw/<agent>.png and <agent>-{sleep,work,alert,done}.png
Writes Sources/AgentNotch/Resources/Mascots/<same names> (128px, trimmed, bottom-aligned).

All variants of an agent are cropped with the same box so the mascot keeps its size and
position when it switches between moods.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / "Sources/AgentNotch/Resources"
RAW, OUT = ROOT / "mascots-raw", ROOT / "Mascots"
AGENTS = ["claude", "codex", "gentle"]
VARIANTS = ["sleep", "work", "alert", "done", "blink", "drowsy", "error"]
SIZE = 128


def clean(path: Path) -> Image.Image:
    """Drop the soft glow halo so only the sprite stays opaque."""
    im = Image.open(path).convert("RGBA")
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v < 60 else min(255, int((v - 60) * 255 / 195)))
    return Image.merge("RGBA", (r, g, b, a))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for agent in AGENTS:
        names = [agent] + [f"{agent}-{v}" for v in VARIANTS]
        variants = {n: clean(RAW / f"{n}.png") for n in names if (RAW / f"{n}.png").exists()}
        if not variants:
            continue
        boxes = [im.getchannel("A").getbbox() for im in variants.values()]
        box = (min(b[0] for b in boxes), min(b[1] for b in boxes),
               max(b[2] for b in boxes), max(b[3] for b in boxes))
        side = max(box[2] - box[0], box[3] - box[1])
        for name, im in variants.items():
            cropped = im.crop(box)
            square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            square.paste(cropped, ((side - cropped.width) // 2, side - cropped.height))
            square.resize((SIZE, SIZE), Image.BOX).save(OUT / f"{name}.png", optimize=True)
            print(f"{name}: box={box} -> {SIZE}px")


if __name__ == "__main__":
    main()
