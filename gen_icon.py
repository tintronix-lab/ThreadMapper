#!/usr/bin/env python3
"""Generate ThreadMapper app icon - mesh network theme."""
import math, os
from PIL import Image, ImageDraw, ImageFilter

BASE = 1024

def make_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size

    # Background: deep navy gradient via layered circles
    bg = Image.new("RGBA", (s, s), (10, 18, 40, 255))
    bg_draw = ImageDraw.Draw(bg)
    # Radial glow center
    for r in range(s // 2, 0, -max(1, s // 60)):
        t = r / (s / 2)
        c = int(10 + (1 - t) * 30)
        bg_draw.ellipse([s//2 - r, s//2 - r, s//2 + r, s//2 + r],
                        fill=(c, int(c * 1.4), int(c * 2.8), 255))
    img.paste(bg, (0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded rect clip mask
    mask = Image.new("L", (s, s), 0)
    mask_draw = ImageDraw.Draw(mask)
    r_corner = int(s * 0.225)
    mask_draw.rounded_rectangle([0, 0, s - 1, s - 1], radius=r_corner, fill=255)
    img.putalpha(mask)
    draw = ImageDraw.Draw(img)

    # Node positions (normalized 0-1), (x, y, type)
    # type: 0=border_router, 1=router, 2=end_device
    nodes_def = [
        (0.50, 0.46, 0),   # center - border router
        (0.28, 0.30, 1),   # top-left router
        (0.72, 0.30, 1),   # top-right router
        (0.20, 0.62, 1),   # left router
        (0.80, 0.62, 1),   # right router
        (0.50, 0.78, 1),   # bottom router
        (0.14, 0.44, 2),   # far-left end
        (0.38, 0.18, 2),   # top-left end
        (0.62, 0.18, 2),   # top-right end
        (0.86, 0.44, 2),   # far-right end
        (0.35, 0.88, 2),   # bottom-left end
        (0.65, 0.88, 2),   # bottom-right end
    ]

    # Link pairs (index into nodes_def)
    links = [
        (0, 1), (0, 2), (0, 3), (0, 4), (0, 5),
        (1, 6), (1, 7), (2, 8), (2, 9),
        (3, 6), (3, 5), (4, 9), (4, 5),
        (5, 10), (5, 11),
        (7, 8), (10, 11),
    ]

    def px(nx, ny):
        margin = s * 0.08
        return (margin + nx * (s - 2 * margin), margin + ny * (s - 2 * margin))

    # Draw links
    for a, b in links:
        ax, ay, at = nodes_def[a]
        bx, by, bt = nodes_def[b]
        p1 = px(ax, ay)
        p2 = px(bx, by)
        # Line width scales with size
        lw = max(1, int(s * 0.012))
        # Glow effect: draw wide semi-transparent then narrow opaque
        draw.line([p1, p2], fill=(80, 180, 255, 60), width=lw * 3)
        draw.line([p1, p2], fill=(120, 210, 255, 130), width=lw)

    # Draw nodes
    node_colors = {
        0: ((0, 220, 255), (0, 160, 220)),    # border router: bright cyan
        1: ((80, 140, 255), (40, 90, 200)),    # router: blue
        2: ((160, 100, 255), (100, 60, 180)),  # end device: purple
    }
    node_radii = {
        0: 0.095,  # border router larger
        1: 0.055,
        2: 0.038,
    }

    for nx, ny, nt in nodes_def:
        cx, cy = px(nx, ny)
        nr = int(s * node_radii[nt])
        outer_c, inner_c = node_colors[nt]

        # Glow halo
        glow_r = int(nr * 1.9)
        glow_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow_layer)
        gd.ellipse([cx - glow_r, cy - glow_r, cx + glow_r, cy + glow_r],
                   fill=(*outer_c, 50))
        glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(glow_r // 2))
        img = Image.alpha_composite(img, glow_layer)
        draw = ImageDraw.Draw(img)

        # Node body gradient (outer ring then inner fill)
        draw.ellipse([cx - nr, cy - nr, cx + nr, cy + nr], fill=(*outer_c, 255))
        inner_r = int(nr * 0.62)
        draw.ellipse([cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r],
                     fill=(*inner_c, 255))
        # Specular dot
        spec_r = max(1, int(nr * 0.22))
        spec_off = int(nr * 0.22)
        draw.ellipse([cx - spec_off - spec_r, cy - spec_off - spec_r,
                      cx - spec_off + spec_r, cy - spec_off + spec_r],
                     fill=(255, 255, 255, 160))

    # Re-apply rounded rect mask to clip glow bleed
    img.putalpha(mask)

    return img

# Sizes required for iOS app icon
sizes = [
    (20, "Icon-20.png"),
    (40, "Icon-20@2x.png"),
    (60, "Icon-20@3x.png"),
    (29, "Icon-29.png"),
    (58, "Icon-29@2x.png"),
    (87, "Icon-29@3x.png"),
    (40, "Icon-40.png"),
    (80, "Icon-40@2x.png"),
    (120, "Icon-40@3x.png"),
    (120, "Icon-60@2x.png"),
    (180, "Icon-60@3x.png"),
    (1024, "Icon-1024.png"),
]

out_dir = "Sources/ThreadMapper/Assets.xcassets/AppIcon.appiconset"
os.makedirs(out_dir, exist_ok=True)

# Generate master at 1024 then downscale
master = make_icon(1024)

for size, name in sizes:
    if size == 1024:
        icon = master.copy()
    else:
        icon = master.resize((size, size), Image.LANCZOS)
    # Convert to RGB PNG (no alpha for App Store 1024)
    if size == 1024:
        final = Image.new("RGB", (size, size), (10, 18, 40))
        final.paste(icon.convert("RGB"), (0, 0))
        final.save(os.path.join(out_dir, name), "PNG")
    else:
        icon.save(os.path.join(out_dir, name), "PNG")
    print(f"  {name} ({size}x{size})")

print("Done.")
