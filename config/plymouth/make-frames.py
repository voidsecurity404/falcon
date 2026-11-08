#!/usr/bin/env python3
"""Draws the Falcon boot animation frames for Plymouth's two-step module.

throbber-NN.png loops while the system boots and shuts down: the falcon
beats its wings slowly. It starts and ends at rest, because two-step lets
the loop finish before the end animation starts. animation-NN.png plays once
when boot finishes: one strong beat and a glow, ending at rest.

Needs rsvg-convert and the Unbounded font. Run it after changing the logo:
    config/plymouth/make-frames.py
"""
import math
import pathlib
import subprocess
import sys

OUT = pathlib.Path(__file__).resolve().parent / "falcon"
SIZE = (300, 360)
THROBBER = 48
END = 30

BODY = ("M100 60 Q108 62 109 74 L114 90 L118 116 L116 128 L130 160 L100 150 "
        "L70 160 L84 128 L82 116 L86 90 L91 74 Q92 62 100 60 Z")
WING = ("M108 84 C140 74 168 60 194 38 C182 64 162 86 140 98 L154 100 L132 108 "
        "L144 110 L120 116 L110 116 Z")
EYE = "M96 70 L100 66 L104 70 Z"
SHOULDER = (110, 92)


def svg(angle, lift, glow):
    """angle: wing rotation in degrees, up is positive. lift: body offset up.
    glow: 0 to 1, a soft light behind the bird."""
    sx, sy = SHOULDER
    halo = ""
    if glow > 0:
        halo = (f'<circle cx="100" cy="100" r="{70 + 30 * glow:.1f}" fill="url(#g)" '
                f'opacity="{glow:.3f}"/>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE[0]}" height="{SIZE[1]}" viewBox="-50 -45 300 360">
<defs><radialGradient id="g"><stop offset="0" stop-color="#fff" stop-opacity=".35"/>
<stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient></defs>
{halo}
<g transform="translate(0 {-lift:.2f})" fill="#fff">
<path d="{WING}" transform="rotate({-angle:.2f} {sx} {sy})"/>
<g transform="translate(200 0) scale(-1 1)"><path d="{WING}" transform="rotate({-angle:.2f} {sx} {sy})"/></g>
<path d="{BODY}"/><path d="{EYE}" fill="#000"/>
</g>
<text x="100" y="236" text-anchor="middle" font-family="Unbounded" font-weight="500"
 font-size="30" letter-spacing="9" fill="#e8e8e8">FALCON</text>
</svg>'''


def render(name, text):
    subprocess.run(["rsvg-convert", "-o", str(OUT / name)], input=text.encode(), check=True)


def ease(t):
    return 0.5 - 0.5 * math.cos(math.pi * t)


def main():
    OUT.mkdir(exist_ok=True)
    for old in OUT.glob("*-*.png"):
        if old.name.startswith(("throbber-", "animation-")):
            old.unlink()
    for i in range(THROBBER):
        phase = math.sin(2 * math.pi * i / THROBBER)
        render(f"throbber-{i:02d}.png", svg(9 * phase, 2.5 * phase, 0))
    for i in range(END):
        t = i / (END - 1)
        beat = math.sin(math.pi * ease(min(1, t * 1.6)))
        glow = math.sin(math.pi * t) ** 2
        render(f"animation-{i:02d}.png", svg(16 * beat, 4 * beat, glow))
    print(f"{THROBBER} throbber and {END} animation frames in {OUT}")


if __name__ == "__main__":
    sys.exit(main())
