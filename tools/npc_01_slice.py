"""NPC-01 已授权的确定性裁切：保留最大连通人物，去掉图外杂点与纸底。"""
from collections import deque
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/customers/adventurers'

def largest(mask):
    h, w = mask.shape
    seen = np.zeros_like(mask)
    best = []
    for y, x in zip(*np.where(mask)):
        if seen[y, x]:
            continue
        q = deque([(int(y), int(x))]); seen[y, x] = True; component = []
        while q:
            a, b = q.popleft(); component.append((a, b))
            for c, d in ((a-1,b),(a+1,b),(a,b-1),(a,b+1)):
                if 0 <= c < h and 0 <= d < w and mask[c,d] and not seen[c,d]:
                    seen[c,d] = True; q.append((c,d))
        if len(component) > len(best): best = component
    result = np.zeros_like(mask)
    for y, x in best: result[y,x] = True
    return result

def clean(im, paper=False):
    a = np.array(im.convert('RGBA'))
    if paper:
        # 纸底明亮、低饱和；只移除连通外部，保留被人物包围的浅色衣服。
        rgb = a[:,:,:3].astype(int)
        candidate = (rgb.min(2) > 202) & ((rgb.max(2)-rgb.min(2)) < 55)
        h,w = candidate.shape
        q=deque((y,x) for y in range(h) for x in (0,w-1))
        q.extend((y,x) for x in range(w) for y in (0,h-1))
        visited=np.zeros_like(candidate)
        while q:
            y,x=q.popleft()
            if y<0 or y>=h or x<0 or x>=w or visited[y,x] or not candidate[y,x]: continue
            visited[y,x]=True
            q.extend(((y-1,x),(y+1,x),(y,x-1),(y,x+1)))
        a[visited,3]=0
    mask=largest(a[:,:,3] >= 100)
    a[~mask,3]=0
    return Image.fromarray(a)

bands={'male_01':[0,354,669,960,1254], 'female_05':[0,348,666,967,1254], 'male_08':[0,357,676,979,1254]}
manifest={}
for name, ys in bands.items():
    src=Image.open(OUT/'source'/f'{name}.png').convert('RGBA')
    sheet=Image.new('RGBA',(1536,1536))
    bounds=[]
    for row in range(4):
        for col in range(4):
            # 生成稿的发梢可略过行界；扩展取样后保留完整连通人物，排除邻行鞋底碎片。
            crop=clean(src.crop((int(col*src.width/4),max(0,ys[row]-14),int((col+1)*src.width/4),min(src.height,ys[row+1]+14))))
            bbox=crop.getbbox(); crop=crop.crop(bbox)
            sheet.alpha_composite(crop,(col*384+(384-crop.width)//2,row*384+380-crop.height))
            bounds.append(list(bbox))
    sheet.save(OUT/f'{name}_actions.png')
    manifest[name]={'cell_size':384,'source_bounds':bounds}

# 从用户确认的原九宫格直接截取头像，避免动作生图改变肖像。
specs=[('male_01','male',(260,8,477,318),165),('female_05','female',(660,340,870,638),170),('male_08','male',(665,680,870,988),165)]
for name,gender,box,head in specs:
    src=Image.open(ROOT/f'output/imagegen/npc_color_variants/{gender}-nine-colors-20261019-v2.png')
    body=clean(src.crop(box),True)
    body.save(OUT/f'{name}_standing.png')
    face=body.crop((0,0,body.width,head))
    face=face.crop(face.getbbox())
    # 头像使用框内宽度等比放大，胸肩贴底；预留头顶，避免透明居中留白。
    scale=min(256/face.width,248/face.height)
    face=face.resize((round(face.width*scale),round(face.height*scale)),Image.Resampling.LANCZOS)
    portrait=Image.new('RGBA',(256,256))
    portrait.alpha_composite(face,((256-face.width)//2,256-face.height))
    portrait.save(OUT/f'{name}_portrait.png')
(OUT/'slice_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('三套16帧、三张原图立绘及透明头像已生成')
