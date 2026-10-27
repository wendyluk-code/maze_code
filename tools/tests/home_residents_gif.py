"""把30秒实际运行帧编码为场景GIF，统一调色板以避免静态背景闪烁。"""
from pathlib import Path
import sys
from PIL import Image

source = Path(sys.argv[1])
target = Path(sys.argv[2])
files = sorted(source.glob("*.png"))
assert files, "缺少实际运行帧"
frames = [Image.open(path).convert("RGB") for path in files]
samples = frames[::max(1, len(frames)//12)]
palette_sheet = Image.new("RGB", (frames[0].width, frames[0].height * len(samples)))
for index, frame in enumerate(samples):
    palette_sheet.paste(frame, (0, index * frame.height))
palette = palette_sheet.quantize(colors=256)
indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
# 截图频率受渲染性能影响，预览按30秒采集窗口均匀分配，精确状态时间见验收JSON。
durations = [(round((i+1)*3000/len(frames)) - round(i*3000/len(frames)))*10 for i in range(len(frames))]
indexed[0].save(target, save_all=True, append_images=indexed[1:], duration=durations, loop=0, disposal=1, optimize=True)
with Image.open(target) as result:
    print(f"{target}: {result.n_frames} frames, {result.size}, {target.stat().st_size} bytes")
