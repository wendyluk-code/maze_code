"""把 CH1-04 实际餐厅捕获帧编码为 GIF（不重画或加工角色）。"""
from pathlib import Path
import sys
from PIL import Image

source = Path(sys.argv[1])
target = Path(sys.argv[2])
frames = [Image.open(path).convert("RGB") for path in sorted(source.glob("motion_*.png"))]
assert frames, "缺少实际场景捕获帧"
frames.append(Image.open(source / "CH1-04-tieshan-dialog.png").convert("RGB"))
# 捕获包含 PNG 编码开销，预览以近似实速播放；末帧延长便于检查对白。
frames[0].save(target, save_all=True, append_images=frames[1:],
               duration=[240] * (len(frames) - 1) + [1000], loop=0)
print(target, "frames=", len(frames), "size=", frames[0].size)
