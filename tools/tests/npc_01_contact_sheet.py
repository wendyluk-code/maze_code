"""将真实场景的逐帧截图汇总为复核页，不替代原始截图。"""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2] / 'output/npc_01'
for resolution in ('1280x720', '1152x648'):
    width, height = map(int, resolution.split('x'))
    sheet = Image.new('RGB', (1200, 720), '#eee4d2')
    draw = ImageDraw.Draw(sheet)
    for row in range(4):
        for col in range(4):
            source = Image.open(root / f'calibration_{row}_{col}_{resolution}.png')
            # 餐厅相机保留世界比例，小分辨率裁掉视野边缘，不按窗口比例缩放世界。
            box = (220, 100, 790, 260) if width == 1280 else (120, 28, 690, 188)
            crop = source.crop(box)
            crop.thumbnail((294, 150))
            sheet.paste(crop, (col * 300, row * 180 + 20))
            draw.text((col * 300 + 4, row * 180 + 4), f'row {row} / frame {col}', fill='#292115')
    sheet.save(root / f'calibration_contact_{resolution}.png')
