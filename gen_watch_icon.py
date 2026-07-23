#!/usr/bin/env python3
"""Generate the ThreadMapper *Watch* app icon.

A simplified, bolder version of the iOS mesh icon (gen_icon.py): a central
border router with six routers in a hexagonal ring, spokes + ring links. Fewer,
larger elements read clearly at ~30 mm on the wrist, where the 12-node iOS icon
turns to mush. Full-bleed navy (watchOS applies its own circular mask) and no
alpha channel (a watch AppIcon with alpha is rejected).

Run with a Python that has Pillow, e.g. Xcode's:
    /Applications/Xcode.app/Contents/Developer/usr/bin/python3 gen_watch_icon.py
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1024
OUT = "Sources/ThreadMapperWatch/Assets.xcassets/AppIcon.appiconset/Icon-1024.png"

# Node types: 0 = border router (center), 1 = router (ring)
NODE_COLORS = {
    0: ((0, 220, 255), (0, 160, 220)),   # bright cyan
    1: ((80, 140, 255), (40, 90, 200)),  # blue
}
NODE_RADII = {0: 0.115, 1: 0.058}

def px(nx, ny):
    return (nx * S, ny * S)

def build():
    img = Image.new("RGBA", (S, S), (10, 18, 40, 255))
    # Radial navy glow toward the centre.
    bg = ImageDraw.Draw(img)
    for r in range(S // 2, 0, -max(1, S // 60)):
        t = r / (S / 2)
        c = int(10 + (1 - t) * 32)
        bg.ellipse([S // 2 - r, S // 2 - r, S // 2 + r, S // 2 + r],
                   fill=(c, int(c * 1.4), int(c * 2.8), 255))
    draw = ImageDraw.Draw(img)

    # Centre + six ring nodes (hexagon), kept well inside the circular crop.
    ring_r = 0.29
    center = (0.5, 0.5)
    ring = []
    for k in range(6):
        ang = math.radians(-90 + k * 60)
        ring.append((0.5 + ring_r * math.cos(ang), 0.5 + ring_r * math.sin(ang)))
    nodes = [(center[0], center[1], 0)] + [(x, y, 1) for x, y in ring]

    lw = max(1, int(S * 0.014))

    def link(p1, p2, bright):
        glow = (80, 180, 255, 55)
        core = (130, 215, 255, 200) if bright else (100, 170, 235, 120)
        draw.line([p1, p2], fill=glow, width=lw * 3)
        draw.line([p1, p2], fill=core, width=lw if bright else max(1, lw // 2))

    # Hex ring (dimmer) then spokes from the centre (bright).
    for k in range(6):
        link(px(*ring[k]), px(*ring[(k + 1) % 6]), bright=False)
    for x, y in ring:
        link(px(*center), px(x, y), bright=True)

    # Nodes with glow halo + specular dot.
    for nx, ny, nt in nodes:
        cx, cy = px(nx, ny)
        nr = int(S * NODE_RADII[nt])
        outer_c, inner_c = NODE_COLORS[nt]

        glow_r = int(nr * 2.0)
        halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse(
            [cx - glow_r, cy - glow_r, cx + glow_r, cy + glow_r], fill=(*outer_c, 60))
        img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(glow_r // 2)))
        draw = ImageDraw.Draw(img)

        draw.ellipse([cx - nr, cy - nr, cx + nr, cy + nr], fill=(*outer_c, 255))
        ir = int(nr * 0.62)
        draw.ellipse([cx - ir, cy - ir, cx + ir, cy + ir], fill=(*inner_c, 255))
        sr = max(1, int(nr * 0.24))
        so = int(nr * 0.24)
        draw.ellipse([cx - so - sr, cy - so - sr, cx - so + sr, cy - so + sr],
                     fill=(255, 255, 255, 170))

    # Flatten to RGB (no alpha) on the navy base.
    flat = Image.new("RGB", (S, S), (10, 18, 40))
    flat.paste(img.convert("RGB"), (0, 0))
    return flat

os.makedirs(os.path.dirname(OUT), exist_ok=True)
build().save(OUT, "PNG")
print(f"Wrote {OUT}")
