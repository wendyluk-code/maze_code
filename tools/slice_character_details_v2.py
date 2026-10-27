"""角色详情修复稿：只裁切透明页签，不擦字、不拉伸细条、不修改原稿。"""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'output/home_detail_assets/tabs_source_v2.png'
image = Image.open(source).convert('RGBA')
out = ROOT / 'assets/ui/character_details'
records = []
for name, y0, y1 in [('tab_selected_v2', 0, image.height // 2),
                     ('tab_idle_v2', image.height // 2, image.height)]:
    part = image.crop((0, y0, image.width, y1))
    bounds = part.getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
    # 留四像素透明安全边，保留原生抗锯齿。
    x0, top, x1, bottom = bounds
    box = (max(0, x0-4), max(0, top-4), min(image.width, x1+4), min(part.height, bottom+4))
    part.crop(box).save(out / (name + '.png'))
    records.append({'name': name, 'source_box': [box[0], box[1]+y0, box[2], box[3]+y0]})
(out / 'slices_v2.json').write_text(json.dumps({'source': str(source.relative_to(ROOT)), 'assets': records}, ensure_ascii=False, indent=2), encoding='utf-8')
print(records)
