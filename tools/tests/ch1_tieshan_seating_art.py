"""Prepare the Tieshan frames and review images for CH1-TS-02.

The generated sheet is a 3 x 2 image copied to output/ch1_tieshan_seating.
This script never changes the restaurant background image.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/ch1_tieshan_seating"
ASSETS = ROOT / "assets/characters/tieshan"
SHEET = OUT / "tieshan_generated_sheet.png"
MAP = ROOT / "assets/maps/restaurant_map.png"

NAMES = ["walk_00", "walk_01", "walk_pause"]
SEATED = {"seat_turn": 410, "seat_descend": 365, "seat_wait": 330}


def make_frames() -> None:
    sheet = Image.open(SHEET).convert("RGBA")
    assert sheet.size == (1536, 1024), sheet.size
    for i, name in enumerate(NAMES):
        x, y = (i % 3) * 512, (i // 3) * 512
        frame = sheet.crop((x, y, x + 512, y + 512))
        frame.resize((480, 480), Image.Resampling.LANCZOS).save(ASSETS / f"{name}.png")
    for name, height in SEATED.items():
        source = Image.open(OUT / f"{name}_edit.png").convert("RGBA")
        trimmed = source.crop(source.getchannel("A").getbbox())
        width = round(trimmed.width * height / trimmed.height)
        trimmed = trimmed.resize((width, height), Image.Resampling.LANCZOS)
        frame = Image.new("RGBA", (480, 480), (0, 0, 0, 0))
        frame.alpha_composite(trimmed, ((480 - width) // 2, 445 - height))
        frame.save(ASSETS / f"{name}.png")


def make_occlusion() -> Image.Image:
    # Both counters' back edges slope upward to the right.  This alpha mask is
    # sampled only by Tieshan's sprite shader, never drawn over the player.
    mask = Image.new("L", (1448, 1086), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon([(152, 322), (761, 239), (766, 435), (150, 524)], fill=255)
    draw.polygon([(782, 228), (818, 214), (925, 197), (1087, 181), (1105, 207), (1103, 307), (780, 335)], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(0.7))
    rgba = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    rgba.putalpha(mask)
    rgba.save(ASSETS / "bar_guest_occlusion.png")
    return mask


def make_shadow() -> None:
    alpha = Image.new("L", (100, 36), 0)
    ImageDraw.Draw(alpha).ellipse((8, 13, 92, 25), fill=125)
    alpha = alpha.filter(ImageFilter.GaussianBlur(5))
    image = Image.new("RGBA", alpha.size, (28, 25, 20, 0))
    image.putalpha(alpha)
    image.save(ASSETS / "ground_shadow.png")


def make_review(mask: Image.Image) -> None:
    original = Image.open(MAP).convert("RGBA")
    annotated = original.copy()
    draw = ImageDraw.Draw(annotated)
    route = [(910, 198), (910, 160), (790, 165), (700, 195), (620, 215), (575, 235), (505, 235), (471, 271)]
    draw.line(route, fill=(238, 62, 31, 255), width=7, joint="curve")
    for i, (x, y) in enumerate(route):
        draw.ellipse((x-8, y-8, x+8, y+8), fill=(255, 245, 190, 255), outline=(131, 30, 17, 255), width=2)
        draw.text((x+12, y-20), str(i), fill=(70, 10, 5, 255))
    for x, y in [(321, 281), (396, 265), (471, 251)]:
        draw.ellipse((x-15, y-15, x+15, y+15), outline=(22, 190, 75, 255), width=4)
    draw.text((485, 235), "target stool (471,251)", fill=(17, 90, 34, 255))
    annotated.save(OUT / "map_route_annotated.png")

    guest = Image.open(ASSETS / "seat_wait.png").convert("RGBA")
    guest = guest.resize((182, 182), Image.Resampling.LANCZOS)
    gx, gy = 471 - 96, 271 - 150
    guest_layer = Image.new("RGBA", original.size, (0, 0, 0, 0))
    guest_layer.alpha_composite(guest, (gx, gy))
    alpha = guest_layer.getchannel("A")
    alpha = Image.composite(Image.new("L", mask.size, 0), alpha, mask)
    guest_layer.putalpha(alpha)
    preview = Image.alpha_composite(original, guest_layer)
    preview.crop((200, 90, 800, 510)).resize((1200, 840)).save(OUT / "seat_composite_preview.png")

    walking = Image.open(ASSETS / "walk_00.png").convert("RGBA")
    walking = walking.resize((152, 152), Image.Resampling.LANCZOS)
    walk_layer = Image.new("RGBA", original.size, (0, 0, 0, 0))
    walk_layer.alpha_composite(walking, (900 - 79, 160 - 142))
    walk_alpha = walk_layer.getchannel("A")
    walk_alpha = Image.composite(Image.new("L", mask.size, 0), walk_alpha, mask)
    walk_layer.putalpha(walk_alpha)
    Image.alpha_composite(original, walk_layer).crop((730, 80, 1130, 380)).resize((1200, 900)).save(OUT / "register_walk_preview.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)
    make_frames()
    make_shadow()
    make_review(make_occlusion())
