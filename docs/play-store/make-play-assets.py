#!/usr/bin/env python3
"""Generates the Google Play listing graphics + screenshot set.

Play's format rules differ from Apple's in ways that matter:
  * store icon  : 512x512, 32-bit PNG *with* alpha
  * feature gfx : 1024x500, 24-bit PNG, no alpha
  * screenshots : 24-bit PNG, no alpha, longest side <= 2x shortest

The magnifier geometry is the same one in
apps/android/app/src/main/res/drawable/ic_launcher_foreground.xml, mapped
from that file's 108dp viewport so the store icon matches the launcher
icon on the device. Only the 72dp the launcher mask actually shows is
rendered, otherwise the store icon would look more padded than the real one.
"""
import os
from PIL import Image, ImageDraw, ImageFont

REPO = "/Users/pekka/Coding/search-assistant"
OUT = os.path.join(REPO, "docs/play-store")
SCRATCH = os.path.dirname(os.path.abspath(__file__))

BG = (16, 150, 92)           # #10965C, the adaptive-icon background colour
GRAD = [(34, 197, 94), (16, 150, 92), (6, 95, 70)]
SS = 4                       # supersampling factor for antialiasing

os.makedirs(os.path.join(OUT, "phone"), exist_ok=True)


def magnifier(draw, cx, cy, scale, colour=(255, 255, 255, 255)):
    """Draws the launcher glyph. `scale` maps ic_launcher_foreground dp -> px,
    (cx, cy) is where dp (54, 54) — the viewport centre — lands."""
    def p(x, y):
        return (cx + (x - 54) * scale, cy + (y - 54) * scale)

    stroke = 6 * scale
    lens = p(50.25, 50.25)
    r = 16.5 * scale
    draw.ellipse([lens[0] - r - stroke / 2, lens[1] - r - stroke / 2,
                  lens[0] + r + stroke / 2, lens[1] + r + stroke / 2], fill=colour)
    draw.ellipse([lens[0] - r + stroke / 2, lens[1] - r + stroke / 2,
                  lens[0] + r - stroke / 2, lens[1] + r - stroke / 2], fill=(0, 0, 0, 0))

    a, b = p(62.25, 62.25), p(74.25, 74.25)
    draw.line([a, b], fill=colour, width=int(round(stroke)))
    # PIL has no round line caps; discs at both ends stand in for them.
    for (hx, hy) in (a, b):
        draw.ellipse([hx - stroke / 2, hy - stroke / 2,
                      hx + stroke / 2, hy + stroke / 2], fill=colour)

    dot = 3 * scale
    draw.ellipse([lens[0] - dot, lens[1] - dot, lens[0] + dot, lens[1] + dot], fill=colour)


# ---------------------------------------------------------------- icon 512
size = 512
img = Image.new("RGBA", (size * SS, size * SS), BG + (255,))
lens_layer = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
magnifier(ImageDraw.Draw(lens_layer), size * SS / 2, size * SS / 2,
          (size / 72.0) * SS)
img = Image.alpha_composite(img, lens_layer)
img = img.resize((size, size), Image.LANCZOS)
img.save(os.path.join(OUT, "icon-512.png"))
print("icon-512.png", img.size, img.mode)

# ------------------------------------------------------- feature graphic
W, H = 1024, 500
grad = Image.new("RGB", (W, H))
px = grad.load()
for y in range(H):
    for x in range(W):
        t = (x / W * 0.65 + y / H * 0.35)
        if t < 0.55:
            u = t / 0.55
            c0, c1 = GRAD[0], GRAD[1]
        else:
            u = (t - 0.55) / 0.45
            c0, c1 = GRAD[1], GRAD[2]
        px[x, y] = tuple(int(c0[i] + (c1[i] - c0[i]) * u) for i in range(3))

feat = grad.convert("RGBA")
glyph = Image.new("RGBA", (W * 2, H * 2), (0, 0, 0, 0))
magnifier(ImageDraw.Draw(glyph), 195 * 2, 250 * 2, (270 / 72.0) * 2)
feat = Image.alpha_composite(feat, glyph.resize((W, H), Image.LANCZOS))

# Play crops the feature graphic's edges in some placements, so the text
# block is kept well inside the frame rather than run out to the margin.
d = ImageDraw.Draw(feat)
bold = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 62)
reg = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 31)
d.text((370, 205), "Search Assistant", font=bold, fill=(255, 255, 255, 255))
d.text((373, 288), "Shared map for group searches", font=reg,
       fill=(255, 255, 255, 225))
feat.convert("RGB").save(os.path.join(OUT, "feature-graphic.png"))
print("feature-graphic.png", (W, H), "RGB")

# ------------------------------------------------------------ screenshots
shots = ["play-1-landing", "play-2-map", "play-3-participants",
         "play-4-share", "play-5-recording"]
for name in shots:
    src = Image.open(os.path.join(SCRATCH, name + ".png"))
    w, h = src.size
    assert max(w, h) <= 2 * min(w, h), f"{name}: {w}x{h} exceeds Play's 2:1 cap"
    dst = os.path.join(OUT, "phone", name.replace("play-", "") + ".png")
    src.convert("RGB").save(dst)          # 24-bit, no alpha
    print(os.path.basename(dst), src.size, "-> RGB")
