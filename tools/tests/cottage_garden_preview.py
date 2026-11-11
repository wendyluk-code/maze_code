"""把真实场景逐帧截图组装为审阅动图；不合成或补造植物运动。"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageChops

parser = argparse.ArgumentParser()
parser.add_argument("frames", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
paths = sorted(args.frames.glob("frame_*.png"))
if len(paths) != 48:
    raise SystemExit("需要完整的48帧实际渲染截图")
frames = [Image.open(path).convert("RGB").crop((280, 80, 1000, 520)) for path in paths]
changed = sum(ImageChops.difference(frames[0], frame).getbbox() is not None for frame in frames[1:])
if changed == 0:
    raise SystemExit("所有截图均相同，不能作为动画证据")
palette = frames[0].quantize(colors=224)
indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
args.output.parent.mkdir(parents=True, exist_ok=True)
indexed[0].save(args.output, save_all=True, append_images=indexed[1:], duration=42, loop=0, optimize=True, disposal=2)
print(json.dumps({"frames":len(frames),"changed_frames":changed,"size":frames[0].size,"output":str(args.output)}, ensure_ascii=False))
