"""将生成的2×2招呼动作图切帧并统一脚底；不重绘角色。"""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
folder = root / 'assets/characters/home'
source = Image.open(folder / 'greeting_source.png').convert('RGBA')
for row, name in enumerate(('yaya', 'tieshan')):
    pieces = []
    for col in range(2):
        part = source.crop((col*source.width//2, row*source.height//2,
                            (col+1)*source.width//2, (row+1)*source.height//2))
        bounds = part.getchannel('A').point(lambda a: 255 if a > 80 else 0).getbbox()
        pieces.append(part.crop(bounds))
    factor = min(312/max(p.height for p in pieces), 348/max(p.width for p in pieces))
    atlas = Image.new('RGBA', (768,384))
    for col, part in enumerate(pieces):
        part = part.resize((round(part.width*factor),round(part.height*factor)),Image.Resampling.LANCZOS)
        atlas.alpha_composite(part,(col*384+(384-part.width)//2,352-part.height))
    atlas.save(folder / f'{name}_greeting.png')
    print(name, atlas.size)
