#!/usr/bin/env python3
"""Frames raw App Store captures with a headline at Apple's required sizes.

Usage: python3 scripts/frame_screenshots.py <raw-dir> [out-dir=build/appstore/en-US]

Raw captures come from the Debug demo mode (`-hearvia.demo YES`, see docs/release.md):
  iphone-home.png, iphone-2-listening.png, iphone-3-captions.png (landscape), iphone-4-transcripts.png,
  iphone-5-translators.png at 1320x2868 (6.9"); ipad-home.png (after Float subtitles), ipad-1-listening.png, ipad-2-transcripts.png at
  2064x2752 (13"); mac-control.png, mac-overlay.png, mac-transcripts.png window captures (screencapture -o -l).
"""

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

GROUND = (14, 16, 32)
ACCENT = (139, 156, 255)
TEXT = (245, 246, 252)
MUTED = (166, 171, 200)
FONT = "/System/Library/Fonts/SFNS.ttf"

IPHONE = (1320, 2868)
IPAD = (2064, 2752)
MAC = (2880, 1800)


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def canvas(size):
    image = Image.new("RGB", size, GROUND)
    # A soft accent glow behind the headline, like the app's listen button.
    glow = Image.new("RGB", size, GROUND)
    ImageDraw.Draw(glow).ellipse(
        (-size[0] * 0.2, -size[1] * 0.35, size[0] * 1.2, size[1] * 0.3), fill=(40, 46, 96))
    return Image.blend(image, glow.filter(ImageFilter.GaussianBlur(size[0] // 6)), 0.9)


def headline(image, title, subtitle, top):
    draw = ImageDraw.Draw(image)
    width = image.width
    base = min(width, image.height)
    title_font = font(int(base * 0.068) if base < 1500 else 118, "Bold")
    sub_font = font(int(base * 0.034) if base < 1500 else 58, "Medium")
    y = top
    for text, f, color in ((title, title_font, TEXT), (subtitle, sub_font, MUTED)):
        for line in wrap(draw, text, f, width * 0.86):
            box = draw.textbbox((0, 0), line, font=f)
            draw.text(((width - (box[2] - box[0])) / 2, y), line, font=f, fill=color)
            y += (box[3] - box[1]) * 1.35
        y += f.size * 0.25
    return int(y)


def wrap(draw, text, f, limit):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=f) <= limit:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line]


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius, fill=255)
    out = image.convert("RGBA")
    out.putalpha(ImageChops.multiply(mask, out.getchannel("A")))
    return out


def place(image, shot, center_x, top, width, radius, border=True):
    scale = width / shot.width
    shot = shot.resize((int(width), int(shot.height * scale)), Image.LANCZOS)
    shot = rounded(shot, int(radius * scale) if radius else 0)
    x, y = int(center_x - shot.width / 2), int(top)
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x, y + 24, x + shot.width, y + shot.height + 24), int(radius * scale) + 8,
                                             fill=(0, 0, 0, 150))
    image.paste(Image.new("RGB", image.size, (0, 0, 0)), (0, 0), shadow.filter(ImageFilter.GaussianBlur(40)))
    if border:
        ImageDraw.Draw(image).rounded_rectangle((x - 6, y - 6, x + shot.width + 6, y + shot.height + 6),
                                                int(radius * scale) + 6, outline=(70, 76, 120), width=6)
    image.paste(shot, (x, y), shot)
    return y + shot.height


def subtitle_box(listening):
    """The live subtitle frame: the black rounded box near the top of the listening screen."""
    rgb = listening.convert("RGB")
    w, h = rgb.size
    rows = [y for y in range(int(h * 0.05), int(h * 0.5)) if rgb.getpixel((w // 2, y)) == (0, 0, 0)]
    cols = [x for x in range(w) if rgb.getpixel((x, rows[len(rows) // 2])) == (0, 0, 0)]
    return listening.crop((cols[0], rows[0], cols[-1] + 1, rows[-1] + 1))


def floating(home, listening, width_ratio, top_ratio):
    """The subtitle window floating over the home screen, as Picture in Picture shows it."""
    shot = home.convert("RGB").copy()
    box = subtitle_box(listening)
    width = int(shot.width * width_ratio)
    box = rounded(box.resize((width, int(box.height * width / box.width)), Image.LANCZOS), int(width * 0.06))
    x, y = (shot.width - width) // 2, int(shot.height * top_ratio)
    shadow = Image.new("RGBA", shot.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x, y + 20, x + box.width, y + box.height + 20), int(width * 0.06),
                                             fill=(0, 0, 0, 170))
    shot.paste(Image.new("RGB", shot.size, (0, 0, 0)), (0, 0), shadow.filter(ImageFilter.GaussianBlur(30)))
    shot.paste(box, (x, y), box)
    return shot


def phone_frame(raw, name, title, subtitle, out, size, radius):
    shot = raw if isinstance(raw, Image.Image) else Image.open(raw)
    if shot.width > shot.height:  # A landscape capture gets a landscape canvas, which App Store Connect also takes.
        size = (size[1], size[0])
    image = canvas(size)
    top = headline(image, title, subtitle, int(size[1] * 0.06))
    height = size[1] - top - size[1] * 0.06
    width = min(size[0] * 0.8, height * shot.width / shot.height)
    place(image, shot, size[0] / 2, top + size[1] * 0.02, width, radius)
    image.save(out / name)


def mac_frame(name, title, subtitle, out, layers):
    image = canvas(MAC)
    top = headline(image, title, subtitle, 120)
    for shot, center_x, y, width in layers:
        place(image, shot, center_x, top + y, width, 24, border=False)
    image.save(out / name)


def scene_background(size):
    """A dim, video-like backdrop for the Mac overlay (no third-party footage)."""
    image = Image.new("RGB", size, (24, 30, 46))
    draw = ImageDraw.Draw(image)
    for i, color in enumerate([(44, 62, 96), (70, 96, 120), (120, 104, 90), (32, 40, 60)]):
        draw.ellipse((size[0] * (0.1 + i * 0.22) - 500, size[1] * (0.25 + (i % 2) * 0.3) - 400,
                      size[0] * (0.1 + i * 0.22) + 500, size[1] * (0.25 + (i % 2) * 0.3) + 400), fill=color)
    return image.filter(ImageFilter.GaussianBlur(160))


def main():
    raw = Path(sys.argv[1])
    out = Path(sys.argv[2] if len(sys.argv) > 2 else "build/appstore/en-US")
    out.mkdir(parents=True, exist_ok=True)
    r = lambda name: Image.open(raw / name)  # noqa: E731

    over = floating(r("iphone-home.png"), r("iphone-2-listening.png"), 0.92, 0.36)
    phone_frame(over, "iphone-1.png", "Subtitles for all you hear",
                "They float over videos, podcasts and calls", out, IPHONE, 160)
    phone_frame(raw / "iphone-2-listening.png", "iphone-2.png", "Translated as they speak",
                "The original above, the translation below", out, IPHONE, 160)
    phone_frame(raw / "iphone-3-captions.png", "iphone-3.png", "Big captions for the room",
                "Turn your iPhone sideways", out, IPHONE, 160)
    phone_frame(raw / "iphone-4-transcripts.png", "iphone-4.png", "Every session, saved",
                "Read or export any transcript later", out, IPHONE, 160)
    phone_frame(raw / "iphone-5-translators.png", "iphone-5.png", "Free on device, or your own AI",
                "On-device, OpenAI, Gemini or a local model", out, IPHONE, 160)

    # The iPad Simulator has Picture in Picture: its home capture already shows the real floating window.
    phone_frame(raw / "ipad-home.png", "ipad-1.png", "Subtitles for all you hear",
                "They float over videos, podcasts and calls", out, IPAD, 60)
    phone_frame(raw / "ipad-1-listening.png", "ipad-2.png", "Translated as they speak",
                "The original above, the translation below", out, IPAD, 60)
    phone_frame(raw / "ipad-2-transcripts.png", "ipad-3.png", "Every session, saved",
                "Read or export any transcript later", out, IPAD, 60)

    scene = scene_background((2400, 1350))
    mac_frame("mac-1.png", "Subtitles over any app", "All system audio, or just one app", out,
              [(scene, MAC[0] / 2, 40, 2400), (r("mac-overlay.png"), MAC[0] / 2, 1000, 1900)])
    mac_frame("mac-2.png", "Translated as they speak", "Start and stop from the menu bar or the Dock", out,
              [(r("mac-control.png"), MAC[0] / 2, 80, 1700)])
    mac_frame("mac-3.png", "Every session, saved", "Read, copy or export any transcript", out,
              [(r("mac-transcripts.png"), MAC[0] / 2, 60, 1900)])


if __name__ == "__main__":
    main()
