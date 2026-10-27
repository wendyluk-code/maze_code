"""保真转换用户宝箱 GIF；只复制 PNG，使用纹理区域消除透明留白。"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("--source", type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
assets = root / "assets/props/treasure_chest"
icons = root / "assets/ui/chests"
assets.mkdir(parents=True, exist_ok=True)
icons.mkdir(parents=True, exist_ok=True)
source = args.source / "treasure_chest_sparkle.gif"
gif = Image.open(source)
frames, durations = [], []
for index in range(gif.n_frames):
    gif.seek(index)
    frames.append(gif.convert("RGBA").copy())
    durations.append(gif.info["duration"])
atlas = Image.new("RGBA", (gif.width * len(frames), gif.height))
for index, frame in enumerate(frames):
    atlas.paste(frame, (index * gif.width, 0))
atlas.save(assets / "sparkle_atlas.png")
decoded = Image.open(assets / "sparkle_atlas.png")
assert all(decoded.crop((i * gif.width, 0, (i + 1) * gif.width, gif.height)).tobytes() == f.tobytes() for i, f in enumerate(frames))
shutil.copyfile(source, assets / source.name)
for name in ["chest_interact_e.png", "gold_coin.png"]:
    shutil.copyfile(args.source / name, icons / name)
    assert (icons / name).read_bytes() == (args.source / name).read_bytes()
text = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(frames) + 2),
        '[ext_resource type="Texture2D" path="res://assets/props/treasure_chest/sparkle_atlas.png" id="1"]']
for i in range(len(frames)):
    text += ['[sub_resource type="AtlasTexture" id="Frame_%d"]' % i,
             'atlas = ExtResource("1")', 'region = Rect2(%d, 49, 164, 128)' % (i * gif.width + 47)]
text += ['[resource]', 'animations = [{"frames": [']
text += [('{"duration": %.8f, "texture": SubResource("Frame_%d")}' % (d / 1000, i)) + (',' if i < len(frames) - 1 else '') for i, d in enumerate(durations)]
text += ['], "loop": true, "name": &"sparkle", "speed": 1.0}]']
(assets / "sparkle_frames.tres").write_text('\n'.join(text) + '\n', encoding='utf-8')
report = {"gif_sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "size": gif.size,
          "frame_count": len(frames), "durations_ms": durations, "rgba_roundtrip_exact": True,
          "frame_sha256": [hashlib.sha256(f.tobytes()).hexdigest() for f in frames]}
(assets / "conversion.json").write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report))
