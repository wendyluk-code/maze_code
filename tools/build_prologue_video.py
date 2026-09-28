"""Build the illustrated prologue video and its procedural ambience track.

Run from the repository root. The script expects FFmpeg at the path passed with
--ffmpeg and writes both an MP4 review file and a Godot-friendly OGV file.
"""

from __future__ import annotations

import argparse
import math
import subprocess
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont


WIDTH = 1920
HEIGHT = 1080
FPS = 30
DURATION = 242.0
SAMPLE_RATE = 48_000


FRAME_OVERRIDES = {
    "01_ancient_kingdom.png": "01_ancient_kingdom_silhouette_v2.png",
    "02_kings_gallery.png": "01_kings_gallery_torch_npc_only_v2.png",
    "03_three_rumors.png": "03_three_rumors_silhouette_v2.png",
    "04_kingdom_falls.png": "04_kingdom_falls_castle_closeup_v3.png",
    "05_tomb_discovery.png": "02_tomb_discovery_silhouette.png",
    "07_sickness.png": "03_sickness_camp_silhouette.png",
    "08_monster_meat.png": "04_monster_meat_silhouette.png",
    "09_protagonist_cooks.png": "09_protagonist_cooks_silhouette_v2.png",
    "12_memory_shatter.png": "12_memory_shatter_silhouette_v2.png",
}


def make_vignette(strength: float) -> Image.Image:
    x = np.linspace(-1.0, 1.0, WIDTH, dtype=np.float32)
    y = np.linspace(-1.0, 1.0, HEIGHT, dtype=np.float32)
    xx, yy = np.meshgrid(x, y)
    mask = 1.0 - strength * np.clip((xx * xx + yy * yy - 0.15) / 1.6, 0.0, 1.0)
    return Image.fromarray(np.clip(mask * 255, 0, 255).astype(np.uint8), "L").convert("RGB")


VIGNETTES = {strength: make_vignette(strength) for strength in (0.26, 0.38)}
GRADE_CACHE: dict[tuple[str, tuple[float, float, float]], Image.Image] = {}


@dataclass(frozen=True)
class Shot:
    start: float
    end: float
    image: str
    zoom_start: float = 1.02
    zoom_end: float = 1.09
    pan_x_start: float = 0.50
    pan_x_end: float = 0.50
    pan_y_start: float = 0.50
    pan_y_end: float = 0.50
    fade: float = 1.1
    grade: tuple[float, float, float] = (1.0, 1.0, 1.0)
    pulse: float = 0.0
    transition: str = "dissolve"
    vignette: float = 0.26
    motion: str = "none"


@dataclass(frozen=True)
class Caption:
    start: float
    end: float
    text: str
    speaker: str = ""
    kind: str = "subtitle"


SHOTS = [
    # A slow reveal establishes distance and calm before the historical mystery.
    Shot(0, 14, "01_ancient_kingdom.png", 1.01, 1.09, 0.38, 0.60, 0.49, 0.46, motion="sun_cycle"),
    # The gallery is scanned in three connected moves, echoing a torch passing portrait to portrait.
    Shot(14, 21, "02_kings_gallery.png", 1.08, 1.14, 0.10, 0.30, 0.48, 0.48, pulse=0.045, motion="torch_sweep"),
    Shot(21, 28, "02_kings_gallery.png", 1.14, 1.16, 0.30, 0.56, 0.48, 0.49, fade=0.55, pulse=0.050, motion="torch_sweep"),
    Shot(28, 34, "02_kings_gallery.png", 1.16, 1.13, 0.56, 0.88, 0.49, 0.49, fade=0.55, pulse=0.045, motion="torch_sweep"),
    # Each rumour receives its own visual beat: bloodline, hidden identity, eternal method.
    Shot(34, 40.5, "03_three_rumors.png", 1.08, 1.14, 0.05, 0.18, 0.47, 0.49, motion="glyph_flow"),
    Shot(40.5, 47.5, "03_three_rumors.png", 1.13, 1.17, 0.36, 0.52, 0.48, 0.50, fade=0.65, motion="glyph_flow"),
    Shot(47.5, 54, "03_three_rumors.png", 1.12, 1.17, 0.72, 0.92, 0.48, 0.50, fade=0.65, motion="glyph_flow"),
    # A low-angle architectural close-up makes the collapse distinct from the opening panorama.
    Shot(54, 66, "04_kingdom_falls.png", 1.01, 1.13, 0.42, 0.66, 0.38, 0.57,
         fade=0.75, grade=(0.88, 0.93, 1.02), pulse=0.025, transition="dip_black", vignette=0.38, motion="collapse"),
    Shot(66, 82, "05_tomb_discovery.png", 1.02, 1.10, 0.28, 0.55, 0.42, 0.54,
         fade=1.15, grade=(0.94, 0.98, 1.05), transition="dip_black", motion="dust_fall"),
    Shot(82, 96, "05_tomb_discovery.png", 1.10, 1.19, 0.64, 0.82, 0.60, 0.53,
         fade=0.8, grade=(0.90, 0.96, 1.08), motion="dust_fall"),
    Shot(96, 110, "06_stele.png", 1.01, 1.10, 0.50, 0.50, 0.53, 0.41,
         fade=0.75, grade=(0.88, 0.95, 1.08), transition="dip_black", vignette=0.38, motion="rune_glow"),
    Shot(110, 124, "05_tomb_discovery.png", 1.03, 1.12, 0.25, 0.48, 0.38, 0.47,
         grade=(0.88, 0.96, 1.10), motion="water_motes"),
    Shot(124, 142, "07_sickness.png", 1.02, 1.12, 0.75, 0.28, 0.52, 0.49,
         grade=(0.86, 0.98, 0.96), motion="sickness"),
    Shot(142, 157, "08_monster_meat.png", 1.03, 1.14, 0.30, 0.72, 0.51, 0.47,
         fade=0.22, grade=(1.04, 0.98, 0.92), pulse=0.025, transition="cut", motion="recovery"),
    Shot(157, 176, "09_protagonist_cooks.png", 1.02, 1.11, 0.62, 0.45, 0.51, 0.47,
         grade=(1.06, 0.99, 0.90), pulse=0.035, motion="fire_cook"),
    Shot(176, 194, "10_bowl_for_yaya.png", 1.01, 1.11, 0.46, 0.56, 0.51, 0.46,
         grade=(1.06, 1.00, 0.92), pulse=0.025, motion="steam_bowl"),
    Shot(194, 200, "10_bowl_for_yaya.png", 1.10, 1.16, 0.55, 0.49, 0.48, 0.52,
         fade=1.4, grade=(0.66, 0.72, 0.80), transition="dip_black", vignette=0.38, motion="heartbeat"),
    Shot(200, 217, "11_deep_anomaly.png", 1.01, 1.11, 0.36, 0.64, 0.47, 0.54,
         fade=0.9, grade=(0.82, 1.04, 1.02), pulse=0.04, transition="dip_black", vignette=0.38, motion="water_pulse"),
    Shot(217, 235, "12_memory_shatter.png", 1.02, 1.16, 0.48, 0.55, 0.54, 0.45,
         fade=0.55, grade=(0.90, 1.02, 1.10), pulse=0.10, transition="flash", vignette=0.38, motion="shatter"),
    Shot(238.5, 242, "13_restaurant.png", 1.08, 1.02, 0.50, 0.50, 0.50, 0.50,
         fade=1.8, grade=(0.92, 1.00, 0.94), motion="restaurant_leaves"),
]


CAPTIONS = [
    Caption(2, 8, "很久以前，曾有一个神秘的古老王国。"),
    Caption(9, 14, "它富饶、宁静，也藏着一个无人知晓的秘密。"),
    Caption(15, 22, "火光依次照亮历代国王的画像。"),
    Caption(22, 28, "服饰和时代不同，面容却几乎一样。"),
    Caption(28, 34, "关于他们长寿的原因，一直流传着各种传说。"),
    Caption(35, 40, "有人说，王室拥有特殊的血脉。"),
    Caption(40.5, 47, "有人说，历代国王根本就是同一个人，\n只是用某种秘术隐藏了身份。"),
    Caption(47.5, 53.5, "也有人说，他们掌握着一种能够延长生命的古老方法。"),
    Caption(55, 60, "但究竟哪一种说法是真的，没有人知道。"),
    Caption(60, 66, "直到某一天，王国消失了。"),
    Caption(67, 73, "随着王国覆灭，这些传言也成为了历史中的谜团。"),
    Caption(74, 82, "数百年后，一场地震让沉睡的迷宫重新出现。"),
    Caption(83, 89, "冒险者进入迷宫后，发现了古代王陵。"),
    Caption(89, 96, "然而，王陵中的棺椁里——空无一物。"),
    Caption(96.2, 100, "没有尸体。没有骨骸。"),
    Caption(100, 103.5, "只有一块刻着古老文字的石碑。"),
    Caption(103.5, 107, "“生命不会消失。”", kind="stele"),
    Caption(107, 110, "“它只是去了别的地方。”", kind="stele"),
    Caption(110.5, 117, "于是，一个流传已久的传说重新被人们相信："),
    Caption(117, 124, "迷宫深处，或许存在能让人摆脱死亡的“永生之泉”。"),
    Caption(124.5, 130, "大量冒险者开始深入迷宫。"),
    Caption(130, 136.5, "但进入得越深，他们就越容易患上一种奇怪的疾病——"),
    Caption(136.5, 142, "迷宫综合症。"),
    Caption(142.5, 148, "身体越来越虚弱，普通食物和药物也逐渐失去效果。"),
    Caption(148, 153.5, "直到有一天，一名濒死的冒险者误食了魔物肉。"),
    Caption(153.5, 157, "奇怪的是，他的身体竟然开始恢复。"),
    Caption(157.5, 163, "这件事，引起了一个人的注意。"),
    Caption(164, 170, "她开始尝试料理魔物。"),
    Caption(170, 176, "原来……这样做就可以。", speaker="？？？"),
    Caption(176.5, 180.5, "芽芽，你看。", speaker="？？？"),
    Caption(181, 185, "这个也能吃吗？", speaker="芽芽"),
    Caption(185.5, 190, "处理对了，就能吃。", speaker="？？？"),
    Caption(190, 194, "……"),
    Caption(200.5, 205, "越过旧地图标记的终点，他们来到迷宫深层。"),
    Caption(205, 209.5, "水下的脉动，与四周发光的根须并不协调。"),
    Caption(210, 213, "不要过去！", speaker="芽芽"),
    Caption(213.2, 217, "再晚就来不及了。", speaker="？？？"),
    Caption(217.5, 222, "她触碰了那个未知之物。"),
    Caption(222, 227, "身体变得透明，记忆随之碎裂。"),
    Caption(227, 230, "醒醒……", speaker="芽芽"),
    Caption(230, 232.5, "你答应过的。", speaker="芽芽"),
    Caption(232.5, 235, "我们要回家。", speaker="芽芽"),
    Caption(235, 238.5, "序章　消失的王国", kind="title"),
]


def clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, value))


def smoothstep(value: float) -> float:
    value = clamp(value)
    return value * value * (3.0 - 2.0 * value)


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    font_dir = Path("C:/Windows/Fonts")
    candidates = ["msyhbd.ttc", "simhei.ttf"] if bold else ["msyh.ttc", "simhei.ttf"]
    for name in candidates:
        path = font_dir / name
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default(size=size)


def cover_image(image: Image.Image, zoom: float, pan_x: float, pan_y: float) -> Image.Image:
    source_ratio = image.width / image.height
    target_ratio = WIDTH / HEIGHT
    if source_ratio >= target_ratio:
        base_h = image.height
        base_w = int(base_h * target_ratio)
    else:
        base_w = image.width
        base_h = int(base_w / target_ratio)
    crop_w = max(1, int(base_w / zoom))
    crop_h = max(1, int(base_h / zoom))
    max_x = image.width - crop_w
    max_y = image.height - crop_h
    left = int(clamp(pan_x) * max_x)
    top = int(clamp(pan_y) * max_y)
    return image.crop((left, top, left + crop_w, top + crop_h)).resize(
        (WIDTH, HEIGHT), Image.Resampling.LANCZOS
    )


def grade_frame(frame: Image.Image, grade: tuple[float, float, float], brightness: float) -> Image.Image:
    arr = np.asarray(frame, dtype=np.float32)
    arr[..., 0] *= grade[0] * brightness
    arr[..., 1] *= grade[1] * brightness
    arr[..., 2] *= grade[2] * brightness
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def add_vignette(frame: Image.Image, strength: float = 0.30) -> Image.Image:
    return ImageChops.multiply(frame, VIGNETTES[strength])


def draw_caption(frame: Image.Image, caption: Caption, t: float) -> None:
    draw = ImageDraw.Draw(frame, "RGBA")
    local_fade = min(smoothstep((t - caption.start) / 0.4), smoothstep((caption.end - t) / 0.4))
    alpha = int(255 * local_fade)
    if alpha <= 0:
        return
    if caption.kind == "title":
        font = load_font(66, bold=True)
        bbox = draw.textbbox((0, 0), caption.text, font=font)
        x = (WIDTH - (bbox[2] - bbox[0])) // 2
        y = (HEIGHT - (bbox[3] - bbox[1])) // 2
        draw.text((x + 3, y + 5), caption.text, font=font, fill=(0, 0, 0, int(alpha * 0.75)))
        draw.text((x, y), caption.text, font=font, fill=(244, 232, 198, alpha))
        return
    font = load_font(42, bold=True)
    speaker_font = load_font(30, bold=True)
    lines = caption.text.split("\n")
    line_boxes = [draw.textbbox((0, 0), line, font=font) for line in lines]
    line_widths = [b[2] - b[0] for b in line_boxes]
    line_height = 58
    content_w = max(line_widths)
    content_h = line_height * len(lines)
    if caption.speaker:
        content_h += 42
    pad_x = 34
    pad_y = 22
    box_w = min(WIDTH - 160, content_w + pad_x * 2)
    box_h = content_h + pad_y * 2
    x0 = (WIDTH - box_w) // 2
    y0 = HEIGHT - box_h - 62
    box_alpha = int((178 if caption.kind == "stele" else 165) * local_fade)
    draw.rounded_rectangle((x0, y0, x0 + box_w, y0 + box_h), radius=12,
                           fill=(12, 15, 20, box_alpha), outline=(236, 218, 174, int(alpha * 0.35)), width=2)
    y = y0 + pad_y
    if caption.speaker:
        draw.text((x0 + pad_x, y), caption.speaker, font=speaker_font,
                  fill=(246, 201, 104, alpha))
        y += 42
    for line, line_width in zip(lines, line_widths):
        x = (WIDTH - line_width) // 2
        draw.text((x + 2, y + 3), line, font=font, fill=(0, 0, 0, int(alpha * 0.8)))
        draw.text((x, y), line, font=font,
                  fill=((249, 231, 184, alpha) if caption.kind == "stele" else (248, 246, 238, alpha)))
        y += line_height


def shot_frame(shot: Shot, images: dict[str, Image.Image], t: float) -> Image.Image:
    progress_raw = clamp((t - shot.start) / max(shot.end - shot.start, 0.001))
    progress = smoothstep(progress_raw)
    zoom = shot.zoom_start + (shot.zoom_end - shot.zoom_start) * progress
    pan_x = shot.pan_x_start + (shot.pan_x_end - shot.pan_x_start) * progress
    pan_y = shot.pan_y_start + (shot.pan_y_end - shot.pan_y_start) * progress
    grade_key = (shot.image, shot.grade)
    if grade_key not in GRADE_CACHE:
        GRADE_CACHE[grade_key] = grade_frame(images[shot.image], shot.grade, 1.0)
    frame = cover_image(GRADE_CACHE[grade_key], zoom, pan_x, pan_y)
    pulse = 1.0 + shot.pulse * math.sin(t * math.tau * (0.75 if t < 200 else 1.15))
    if abs(pulse - 1.0) > 0.001:
        frame = ImageEnhance.Brightness(frame).enhance(pulse)
    frame = add_in_frame_motion(frame, shot.motion, progress_raw, t)
    frame = add_vignette(frame, shot.vignette)
    return frame


def add_in_frame_motion(frame: Image.Image, motion: str, progress: float, t: float) -> Image.Image:
    """Add restrained 2D animation on top of a still keyframe.

    These are intentionally graphic rather than photoreal effects: the source art remains
    the focal point while light, dust, steam, water, and camera impulse give each shot a
    readable event of its own.
    """
    if motion == "none":
        return frame
    rgba = frame.convert("RGBA")
    overlay = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")
    w, h = frame.size

    def point(nx: float, ny: float) -> tuple[int, int]:
        return int(nx * w), int(ny * h)

    if motion == "sun_cycle":
        # The source painting contains a fixed sunset disk. Soften it into the surrounding
        # cloud colour first, then add one animated sun to avoid a distracting double sun.
        patch_box = (int(0.205 * w), int(0.275 * h), int(0.335 * w), int(0.455 * h))
        sky_patch = rgba.crop(patch_box).filter(ImageFilter.GaussianBlur(32))
        patch_mask = Image.new("L", sky_patch.size, 0)
        patch_draw = ImageDraw.Draw(patch_mask)
        patch_draw.ellipse((5, 5, sky_patch.width - 5, sky_patch.height - 5), fill=245)
        patch_mask = patch_mask.filter(ImageFilter.GaussianBlur(24))
        rgba.paste(sky_patch, patch_box[:2], patch_mask)
        # Sunrise at left, high noon in the middle, sunset at right.
        x = 0.19 + 0.56 * progress
        y = 0.40 - 0.22 * math.sin(progress * math.pi)
        cx, cy = point(x, y)
        for radius, alpha in ((118, 10), (88, 18), (62, 36)):
            draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(255, 199, 104, alpha))
        disk_alpha = int(230 * (0.82 + 0.18 * math.sin(progress * math.pi)))
        draw.ellipse((cx - 39, cy - 39, cx + 39, cy + 39), fill=(255, 218, 128, disk_alpha))
        # A cool-to-warm wash makes the passage of time legible without replacing the art.
        wash_alpha = int(26 * math.sin(progress * math.pi))
        draw.rectangle((0, 0, w, h), fill=(255, 154, 82, wash_alpha))
    elif motion == "torch_sweep":
        x = 0.16 + 0.68 * progress
        cx, cy = point(x, 0.43 + 0.04 * math.sin(t * 1.7))
        for radius, alpha in ((155, 8), (100, 15), (56, 32)):
            draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(255, 180, 72, alpha))
        draw.ellipse((cx - 15, cy - 15, cx + 15, cy + 15), fill=(255, 224, 145, 42))
    elif motion == "glyph_flow":
        # Small motes travel along the glowing red/gold paths in the mural.
        for i in range(7):
            q = (progress * 1.35 + i / 7.0) % 1.0
            x = 0.16 + 0.68 * q
            y = 0.33 + 0.15 * math.sin(q * math.tau + 0.6)
            cx, cy = point(x, y)
            radius = 4 + (i % 3)
            draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(255, 222, 113, 100))
    elif motion == "collapse":
        # A short structural impulse sells the collapse while retaining readable architecture.
        dx = int(5.5 * math.sin(t * math.tau * 4.6) * (0.25 + progress))
        dy = int(3.0 * math.sin(t * math.tau * 3.1 + 1.0) * (0.25 + progress))
        rgba = rgba.transform((w, h), Image.Transform.AFFINE, (1, 0, dx, 0, 1, dy), fillcolor=(26, 29, 39, 255))
        overlay = Image.new("RGBA", frame.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(overlay, "RGBA")
        for i in range(24):
            q = (progress * 1.8 + i / 24.0) % 1.0
            x = 0.08 + ((i * 0.19) % 0.84)
            y = (q * 0.92) - 0.08
            cx, cy = point(x, y)
            r = 3 + (i % 5)
            draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(225, 214, 198, 80))
    elif motion == "dust_fall":
        for i in range(22):
            q = (progress * 1.4 + i / 22.0) % 1.0
            x = 0.08 + ((i * 0.37) % 0.84)
            y = (q * 0.85) + 0.05
            cx, cy = point(x, y)
            r = 2 + (i % 4)
            draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(218, 224, 225, 38 + (i % 4) * 8))
    elif motion == "rune_glow":
        alpha = int(42 + 34 * (0.5 + 0.5 * math.sin(t * math.tau * 0.8)))
        cx, cy = point(0.50, 0.47)
        for radius in (170, 120, 72):
            draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=(188, 224, 255, alpha // 4), width=5)
        draw.ellipse((cx - 24, cy - 24, cx + 24, cy + 24), fill=(185, 227, 255, alpha))
    elif motion == "water_motes":
        for i in range(16):
            q = (progress + i / 16.0) % 1.0
            x = 0.20 + 0.62 * ((i * 0.41 + q * 0.12) % 1.0)
            y = 0.18 + 0.68 * ((q + i * 0.07) % 1.0)
            cx, cy = point(x, y)
            draw.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=(145, 224, 255, 64))
    elif motion == "sickness":
        alpha = int(18 + 15 * (0.5 + 0.5 * math.sin(t * math.tau * 0.55)))
        draw.rectangle((0, 0, w, h), fill=(93, 157, 155, alpha))
        for i in range(10):
            x = 0.1 + 0.8 * ((i * 0.17 + progress * 0.12) % 1.0)
            y = 0.12 + 0.64 * ((i * 0.29 + progress * 0.08) % 1.0)
            cx, cy = point(x, y)
            draw.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=(204, 235, 207, 42))
    elif motion == "recovery":
        cx, cy = point(0.58 + 0.08 * progress, 0.50)
        alpha = int(24 + 50 * progress)
        for radius in (150, 105, 62):
            draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=(255, 193, 94, alpha // 4), width=6)
        draw.ellipse((cx - 22, cy - 22, cx + 22, cy + 22), fill=(255, 207, 111, alpha))
    elif motion == "fire_cook":
        cx, cy = point(0.58, 0.60)
        alpha = int(25 + 24 * (0.5 + 0.5 * math.sin(t * math.tau * 1.25)))
        draw.ellipse((cx - 210, cy - 150, cx + 210, cy + 150), fill=(255, 142, 48, alpha))
        for i in range(7):
            q = (progress * 1.6 + i / 7.0) % 1.0
            sx = cx + int((i - 3) * 48 + 12 * math.sin(t * 2.1 + i))
            sy = cy - int(q * 230)
            draw.ellipse((sx - 5, sy - 8, sx + 5, sy + 8), fill=(255, 226, 154, 50))
    elif motion == "steam_bowl":
        cx, cy = point(0.52, 0.52)
        for i in range(6):
            q = (progress * 1.2 + i / 6.0) % 1.0
            sx = cx + int((i - 2.5) * 46 + 9 * math.sin(t * 1.6 + i))
            sy = cy - int(q * 200)
            draw.ellipse((sx - 7, sy - 24, sx + 7, sy + 24), fill=(255, 244, 220, 26))
    elif motion == "heartbeat":
        beat = math.exp(-((t * 1.7) % 1.0) * 10.0)
        draw.rectangle((0, 0, w, h), fill=(86, 41, 57, int(18 * beat)))
    elif motion == "water_pulse":
        cx, cy = point(0.63, 0.60)
        for i in range(3):
            radius = int(80 + ((progress * 310 + i * 100) % 360))
            alpha = max(8, 42 - radius // 12)
            draw.ellipse((cx - radius, cy - radius // 2, cx + radius, cy + radius // 2), outline=(121, 238, 240, alpha), width=5)
    elif motion == "shatter":
        dx = int(3.5 * math.sin(t * math.tau * 8.0))
        dy = int(2.5 * math.cos(t * math.tau * 6.0))
        rgba = rgba.transform((w, h), Image.Transform.AFFINE, (1, 0, dx, 0, 1, dy), fillcolor=(7, 13, 24, 255))
        draw.rectangle((0, 0, w, h), fill=(205, 239, 255, int(32 * (0.5 + 0.5 * math.sin(t * math.tau * 5.0)))))
    elif motion == "restaurant_leaves":
        for i in range(12):
            q = (progress * 0.8 + i / 12.0) % 1.0
            x = 0.10 + 0.82 * ((i * 0.31 + q * 0.18) % 1.0)
            y = 0.08 + 0.55 * ((i * 0.17 + q * 0.25) % 1.0)
            cx, cy = point(x, y)
            draw.ellipse((cx - 5, cy - 3, cx + 5, cy + 3), fill=(144, 195, 117, 58))

    return Image.alpha_composite(rgba, overlay).convert("RGB")


def transition_frame(previous: Image.Image, current: Image.Image, progress: float, kind: str) -> Image.Image:
    progress = smoothstep(progress)
    if kind == "cut":
        return current
    if kind in {"dip_black", "flash"}:
        bridge_color = (255, 248, 226) if kind == "flash" else (3, 5, 9)
        bridge = Image.new("RGB", (WIDTH, HEIGHT), bridge_color)
        if progress < 0.5:
            return Image.blend(previous, bridge, progress * 2.0)
        return Image.blend(bridge, current, (progress - 0.5) * 2.0)
    return Image.blend(previous, current, progress)


def render_frame(images: dict[str, Image.Image], t: float) -> Image.Image:
    active = [shot for shot in SHOTS if shot.start <= t < shot.end]
    if active:
        shot = active[-1]
        frame = shot_frame(shot, images, t)
        shot_index = SHOTS.index(shot)
        fade_in = smoothstep((t - shot.start) / shot.fade)
        previous = SHOTS[shot_index - 1] if shot_index > 0 else None
        if previous and abs(previous.end - shot.start) < 0.01 and fade_in < 1.0:
            previous_t = previous.end - shot.fade + (t - shot.start)
            frame = transition_frame(shot_frame(previous, images, previous_t), frame, fade_in, shot.transition)
        elif fade_in < 1.0:
            frame = ImageEnhance.Brightness(frame).enhance(fade_in)
        following = SHOTS[shot_index + 1] if shot_index + 1 < len(SHOTS) else None
        if (not following or abs(following.start - shot.end) >= 0.01) and shot.end - t < shot.fade:
            frame = ImageEnhance.Brightness(frame).enhance(smoothstep((shot.end - t) / shot.fade))
    else:
        frame = Image.new("RGB", (WIDTH, HEIGHT), (3, 5, 9))
    # Subtle deterministic dust/grain avoids a sterile slideshow feel.
    seed = int(t * FPS) + 1701
    rng = np.random.default_rng(seed)
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay, "RGBA")
    for _ in range(26):
        x = int(rng.uniform(0, WIDTH))
        y = int(rng.uniform(0, HEIGHT * 0.88))
        r = int(rng.uniform(1, 4))
        a = int(rng.uniform(5, 18))
        odraw.ellipse((x - r, y - r, x + r, y + r), fill=(244, 228, 181, a))
    frame = Image.alpha_composite(frame.convert("RGBA"), overlay).convert("RGB")
    for caption in CAPTIONS:
        if caption.start <= t < caption.end:
            draw_caption(frame, caption, t)
    return frame


def envelope(t: np.ndarray, start: float, end: float, attack: float = 1.0, release: float = 1.0) -> np.ndarray:
    return np.clip((t - start) / attack, 0, 1) * np.clip((end - t) / release, 0, 1)


def build_audio(path: Path) -> None:
    count = int(DURATION * SAMPLE_RATE)
    block = SAMPLE_RATE
    rng = np.random.default_rng(413)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        for offset in range(0, count, block):
            n = min(block, count - offset)
            t = (offset + np.arange(n)) / SAMPLE_RATE
            left = np.zeros(n, dtype=np.float64)
            right = np.zeros(n, dtype=np.float64)
            # A restrained tonal bed, shifting from history to cave to heartbeat.
            hist = envelope(t, 0, 124, 3, 5)
            cave = envelope(t, 108, 235, 4, 3)
            left += hist * (0.045 * np.sin(math.tau * 55 * t) + 0.025 * np.sin(math.tau * 82.4 * t + 0.5))
            right += hist * (0.044 * np.sin(math.tau * 55 * t + 0.3) + 0.024 * np.sin(math.tau * 73.4 * t))
            left += cave * (0.035 * np.sin(math.tau * 43.6 * t) + 0.018 * np.sin(math.tau * 65.4 * t + 0.7))
            right += cave * (0.034 * np.sin(math.tau * 43.6 * t + 0.4) + 0.018 * np.sin(math.tau * 61.7 * t))
            noise = rng.normal(0, 1, n)
            wind = envelope(t, 0, 176, 2, 3) * 0.008 * noise
            left += wind
            right += np.roll(wind, 37)
            # Collapse and earthquake rumbles.
            for start, end, amp in ((54, 66, 0.09), (66, 82, 0.075), (217, 224, 0.12)):
                env = envelope(t, start, end, 1.2, 1.3)
                rumble = amp * env * (np.sin(math.tau * 31 * t) + 0.4 * np.sin(math.tau * 23 * t + 0.8))
                left += rumble
                right += rumble * 0.96
            # Fire and bubbling near the cooking sequence.
            cook = envelope(t, 157, 200, 1, 1)
            crackle = cook * np.maximum(noise - 1.75, 0) * 0.055
            bubble = cook * 0.018 * np.sin(math.tau * (115 + 7 * np.sin(t * 1.7)) * t)
            left += crackle + bubble
            right += np.roll(crackle, 109) + bubble * 0.85
            # Low double heartbeat in the deep chamber.
            beat_env = envelope(t, 194, 239, 1, 2)
            phase = np.mod(t - 194, 1.18)
            beat = np.exp(-phase * 15) + 0.55 * np.exp(-np.maximum(phase - 0.17, 0) * 24) * (phase >= 0.17)
            beat *= beat_env * (0.10 + 0.07 * np.clip((t - 210) / 20, 0, 1))
            left += beat * np.sin(math.tau * 48 * t)
            right += beat * np.sin(math.tau * 48 * t + 0.08)
            # Leaf rustle carries the final cut into the restaurant.
            leaves = envelope(t, 238, 242, 0.5, 0.2) * 0.028 * noise * (0.5 + 0.5 * np.sin(math.tau * 3.2 * t))
            left += leaves
            right += np.roll(leaves, 211)
            stereo = np.stack((left, right), axis=1)
            stereo = np.tanh(stereo * 1.35)
            wav.writeframes((stereo * 32767).astype("<i2").tobytes())


def build_contact_sheet(images: dict[str, Image.Image], path: Path) -> None:
    sample_times = [7, 17.5, 24.5, 31, 37, 44, 51, 60, 74, 89, 103, 132, 150, 166, 185, 209, 226, 240]
    thumb_w, thumb_h = 480, 270
    columns = 3
    rows = math.ceil(len(sample_times) / columns)
    sheet = Image.new("RGB", (thumb_w * columns, thumb_h * rows), (10, 12, 16))
    for index, sample_t in enumerate(sample_times):
        frame = render_frame(images, sample_t).resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        sheet.paste(frame, ((index % columns) * thumb_w, (index // columns) * thumb_h))
    sheet.save(path)


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg", required=True, type=Path)
    parser.add_argument("--assets", default=Path("assets/video/prologue/frames"), type=Path)
    parser.add_argument("--overrides", default=Path("output/video/npc_silhouette_keyframes"), type=Path)
    parser.add_argument("--output", default=Path("output/video"), type=Path)
    parser.add_argument("--preview", action="store_true", help="Render 24 seconds at 720p-equivalent timing for a quick check")
    parser.add_argument("--contact-sheet-only", action="store_true")
    parser.add_argument("--video-codec", default="libx264")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    images = {path.name: Image.open(path).convert("RGB") for path in args.assets.glob("*.png")}
    for frame_name, override_name in FRAME_OVERRIDES.items():
        override_path = args.overrides / override_name
        if not override_path.exists():
            raise FileNotFoundError(f"Missing approved frame override: {override_path}")
        images[frame_name] = Image.open(override_path).convert("RGB")
    missing = sorted({s.image for s in SHOTS} - images.keys())
    if missing:
        raise FileNotFoundError(f"Missing prologue frames: {missing}")
    contact_path = args.output / "prologue_animatic_v3_contact.jpg"
    if args.contact_sheet_only:
        build_contact_sheet(images, contact_path)
        print(contact_path.resolve())
        return
    duration = 24.0 if args.preview else DURATION
    scale = DURATION / duration if args.preview else 1.0
    mp4_path = args.output / ("prologue_animatic_v3_preview.mp4" if args.preview else "prologue_animatic_v3.mp4")
    audio_path = args.output / "prologue_animatic_v3_ambience.wav"
    if not args.preview:
        build_audio(audio_path)
    if args.preview:
        audio_input = ["-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo"]
    else:
        audio_input = ["-i", str(audio_path)]
    video_cmd = [
        str(args.ffmpeg), "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{WIDTH}x{HEIGHT}",
        "-r", str(FPS), "-i", "-", *audio_input,
    ]
    if args.video_codec == "h264_nvenc":
        video_options = ["-c:v", "h264_nvenc", "-preset", "p5", "-cq", "20", "-b:v", "0"]
    else:
        video_options = ["-c:v", args.video_codec, "-preset", "medium", "-crf", "18"]
    video_cmd += [
        "-t", str(duration), *video_options, "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
        "-movflags", "+faststart", str(mp4_path),
    ]
    process = subprocess.Popen(video_cmd, stdin=subprocess.PIPE)
    assert process.stdin is not None
    try:
        for frame_index in range(int(duration * FPS)):
            timeline_t = frame_index / FPS * scale
            frame = render_frame(images, timeline_t)
            process.stdin.write(np.asarray(frame, dtype=np.uint8).tobytes())
    finally:
        process.stdin.close()
    if process.wait() != 0:
        raise RuntimeError("FFmpeg MP4 encoding failed")
    if not args.preview:
        build_contact_sheet(images, contact_path)
    print(mp4_path.resolve())


if __name__ == "__main__":
    main()
