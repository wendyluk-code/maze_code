"""将图像生成的角色动作帧封装为 Godot 动画图集与 GIF 预览。"""
from pathlib import Path
import json
import statistics
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"C:\Users\KSG\.codex\generated_images\01a125db-f52d-74a1-8ddc-074d58ba8962")
SPECS = {
    "yaya": ("exec-337dab4d-541a-4595-b0f7-62de37e1843c.png", [0, 390, 748, 1086]),
    "tieshan": ("exec-3e1f1f84-498a-47b1-accb-1cc161200abf.png", [0, 374, 733, 1086]),
}
OUT = ROOT / "assets/characters/home"
PREVIEW = ROOT / "output/home_character_animations"
SOFT = "--outline-free" in sys.argv
SUFFIX = "_soft" if SOFT else ""
if SOFT:
    PREVIEW = PREVIEW / "outline_free_3x"
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)
CELL = 384

for character, (filename, rows) in SPECS.items():
    source_path = OUT / f"{character}{SUFFIX}_source.png"
    image = Image.open(source_path if source_path.exists() else SOURCE / filename).convert("RGBA")
    image.save(source_path)
    if SOFT:
        rows = [round(image.height * row / 3) for row in range(4)]
    pieces = []
    for row in range(3):
        for col in range(4):
            piece = image.crop((round(col * image.width / 4), rows[row], round((col + 1) * image.width / 4), rows[row + 1]))
            bounds = piece.getchannel("A").point(lambda a: 255 if a > 80 else 0).getbbox()
            assert bounds is not None
            bounds = (max(0, bounds[0]-2), max(0, bounds[1]-2), min(piece.width, bounds[2]+2), min(piece.height, bounds[3]+2))
            pieces.append(piece.crop(bounds))
    # 整个角色统一比例，坐姿保留自然高度；脚底统一锚点，避免换动作跳位。
    scale = min(312 / statistics.median(p.height for p in pieces[:8]), 344 / max(p.width for p in pieces))
    atlas = Image.new("RGBA", (CELL * 4, CELL * 3))
    frames = []
    for i, piece in enumerate(pieces):
        piece = piece.resize((round(piece.width * scale), round(piece.height * scale)), Image.Resampling.LANCZOS)
        frame = Image.new("RGBA", (CELL, CELL))
        frame.alpha_composite(piece, ((CELL - piece.width)//2, 352-piece.height))
        frames.append(frame)
        atlas.alpha_composite(frame, ((i % 4) * CELL, (i // 4) * CELL))
    atlas.save(OUT / f"{character}_home{SUFFIX}_atlas.png")
    resource = ['[gd_resource type="SpriteFrames" load_steps=14 format=3]', '',
        f'[ext_resource type="Texture2D" path="res://assets/characters/home/{character}_home{SUFFIX}_atlas.png" id="1"]', '']
    for i in range(12):
        resource += [f'[sub_resource type="AtlasTexture" id="Frame_{i}"]', 'atlas = ExtResource("1")',
            f'region = Rect2({i%4*CELL}, {i//4*CELL}, {CELL}, {CELL})', 'filter_clip = true', '']
    animations = []
    for row, (name, durations, speed) in enumerate([
        ("walk", [1, 1, 1, 1], 7.0),
        ("idle", [5, 2, 0.5, 2], 3.0),
        ("rest", [5, 2, 0.8, 2], 2.0),
    ]):
        entries = ', '.join(f'{{"duration": {duration}, "texture": SubResource("Frame_{row*4+i}")}}' for i, duration in enumerate(durations))
        animations.append(f'{{"frames": [{entries}], "loop": true, "name": &"{name}", "speed": {speed}}}')
    resource += ['[resource]', 'animations = [' + ',\n'.join(animations) + ']', '']
    (OUT / f"{character}_home{SUFFIX}.tres").write_text('\n'.join(resource), encoding="utf-8")
    # GIF仅作动作预览；游戏使用保留半透明边缘的PNG逐帧动画。
    gif_frames = []
    for tick in range(180):
        t = tick / 10.0
        alpha = min(1.0, max(0.0, (t - 1.0) / 0.8), max(0.0, (15.8 - t) / 0.8))
        if t < 6:
            index = int(t * 7) % 4
        elif t < 10:
            index = 4 + [0, 0, 1, 1, 2, 3, 0, 0][int(t * 4) % 8]
        else:
            index = 8 + [0, 0, 1, 1, 2, 3, 0, 0][int(t * 3) % 8]
        frame = frames[index].copy()
        frame.putalpha(frame.getchannel("A").point(lambda a: round(a * alpha)))
        canvas = Image.new("RGBA", (384, 384), (255, 244, 220, 255))
        canvas.alpha_composite(frame)
        gif_frames.append(canvas.convert("RGB"))
    gif_frames[0].save(PREVIEW / f"{character}_actions.gif", save_all=True, append_images=gif_frames[1:], duration=100, loop=0, disposal=2)
    print(character, "12 frames, atlas", atlas.size, "scale", round(scale, 4))

(PREVIEW / "build.json").write_text(json.dumps({"characters": list(SPECS), "cell": CELL, "foot": [192,352], "format": "PNG SpriteFrames + GIF preview"}, ensure_ascii=False, indent=2), encoding="utf-8")
