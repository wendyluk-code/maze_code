"""将用户闪光GIF无损解码为Godot动画；原始文件保持不变。"""
from pathlib import Path
import hashlib
import json
from PIL import Image

root = Path(__file__).resolve().parents[2]
source = root / "generated_assets/tree_stump_4_white_sparkles_256.gif"
target = root / "assets/props/dig_site"
target.mkdir(parents=True, exist_ok=True)
gif = Image.open(source)
assert gif.info.get("loop") == 0, "挖掘点素材必须无限循环"
frames, durations = [], []
for i in range(gif.n_frames):
    gif.seek(i)
    frames.append(gif.convert("RGBA").copy())
    durations.append(gif.info["duration"])
cols = 8
atlas = Image.new("RGBA", (gif.width * cols, gif.height * ((len(frames) + cols - 1) // cols)))
for i, frame in enumerate(frames):
    atlas.paste(frame, ((i % cols) * gif.width, (i // cols) * gif.height))
atlas.save(target / "twinkle_atlas.png")
decoded = Image.open(target / "twinkle_atlas.png")
for i, frame in enumerate(frames):
    x, y = (i % cols) * gif.width, (i // cols) * gif.height
    assert decoded.crop((x, y, x + gif.width, y + gif.height)).tobytes() == frame.tobytes()
lines = [f'[gd_resource type="SpriteFrames" load_steps={len(frames)+2} format=3]',
         '[ext_resource type="Texture2D" path="res://assets/props/dig_site/twinkle_atlas.png" id="1"]']
for i in range(len(frames)):
    lines += [f'[sub_resource type="AtlasTexture" id="Frame_{i}"]', 'atlas = ExtResource("1")',
              f'region = Rect2({i % cols * gif.width}, {i // cols * gif.height}, {gif.width}, {gif.height})']
lines += ['[resource]', 'animations = [{"frames": [']
lines += [f'{{"duration": {d/1000:.8f}, "texture": SubResource("Frame_{i}")}}' + (',' if i < len(frames)-1 else '') for i, d in enumerate(durations)]
lines += ['], "loop": true, "name": &"sparkle", "speed": 1.0}]']
(target / "twinkle_frames.tres").write_text('\n'.join(lines)+'\n', encoding='utf-8')
report = {"source": str(source.relative_to(root)), "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
          "size": gif.size, "frame_count": len(frames), "durations_ms": durations, "loop": True, "rgba_roundtrip_exact": True}
(target / "conversion.json").write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report))
