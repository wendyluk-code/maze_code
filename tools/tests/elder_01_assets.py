"""只读检查批准帧的哈希、尺寸和透明通道，禁止切图或改稿。"""
from pathlib import Path
import hashlib
import json
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path('F:/maze_code/output/elder_sitting_preview_v1/frames')
rows=[]
for i in range(8):
    name=f'elder_sitting_{i:02d}.png'
    source=SOURCE/name
    target=ROOT/'assets/characters/white_tiger_elder'/name
    digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    with Image.open(target) as image:
        rows.append({'frame':name,'same_approved_sha256':digest(source)==digest(target),'sha256':digest(target),'size':list(image.size),'mode':image.mode,'alpha_range':list(image.getchannel('A').getextrema())})
passed=all(r['same_approved_sha256'] and r['size']==[512,512] and r['mode']=='RGBA' and r['alpha_range'][0]==0 for r in rows) and len({r['sha256'] for r in rows})>1
output=ROOT/'output/elder_01_repair/approved_assets.json'
output.write_text(json.dumps({'passed':passed,'frames':rows},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'passed':passed,'report':str(output)},ensure_ascii=False))
raise SystemExit(0 if passed else 1)
