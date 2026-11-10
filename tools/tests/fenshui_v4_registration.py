"""只读配准诊断，不修改或生成地图像素；局部相关性不是自动验收门禁。"""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORLD = (1715, 917)
paths = {
    "运行合成底图": ROOT / "assets/maps/fenshui_fences.png",
    "干净原图": ROOT / "assets/maps/fenshui.png",
    "候选v4": ROOT / "output/fenshui-shore-review/map-candidate-v4.png",
}
images = {name: Image.open(path).convert("RGB") for name, path in paths.items()}
original_sizes = {name: list(image.size) for name, image in images.items()}
arrays = {name: np.asarray(image.resize(WORLD, Image.Resampling.BICUBIC), dtype=np.float32) for name, image in images.items()}

def edges(rgb):
    gray = rgb.mean(axis=2)
    return np.hypot(np.gradient(gray, axis=0), np.gradient(gray, axis=1))

target = edges(arrays["候选v4"])
regions = [
    ("枯水渠右上出口", (1610, 145, 1690, 205)),
    ("盐池北出口", (780, 4, 850, 75)),
    ("西北出口", (4, 4, 78, 70)),
    ("西侧出口", (4, 460, 80, 520)),
    ("西南出口", (285, 840, 365, 910)),
    ("南侧出口", (950, 840, 1030, 910)),
    ("东南出口", (1620, 680, 1705, 755)),
]
rows = []
for source in ["运行合成底图", "干净原图"]:
    base = edges(arrays[source])
    for name, box in regions:
        x0, y0, x1, y1 = box
        # 靠边窗口只使用各移位都具有输入的内部部分，避免补零主导结果。
        margin = 16
        x0, y0 = max(x0, margin), max(y0, margin)
        x1, y1 = min(x1, WORLD[0]-margin), min(y1, WORLD[1]-margin)
        patch = base[y0:y1, x0:x1]
        p = patch-patch.mean()
        norm = np.linalg.norm(p)
        scores = []
        for dy in range(-margin, margin+1):
            for dx in range(-margin, margin+1):
                q = target[y0+dy:y1+dy, x0+dx:x1+dx]
                q = q-q.mean()
                score = float(np.sum(p*q)/(norm*np.linalg.norm(q)+1e-9))
                scores.append((score, dx, dy))
        best = max(scores)
        zero = next(row[0] for row in scores if row[1:] == (0, 0))
        rows.append({"参照": source, "地标": name, "窗口": [x0, y0, x1, y1], "最佳偏移像素": list(best[1:]), "最佳相关性": round(best[0], 4), "零偏移相关性": round(zero, 4), "解释": "仅局部边缘匹配提示，须结合实图及既有坐标人工复核，不自动迁移坐标"})
print(json.dumps({"实际尺寸": original_sizes, "世界尺寸": list(WORLD), "局部检查": rows}, ensure_ascii=False, indent=2))
