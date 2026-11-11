"""裁切已批准的18人动作素材；保留原三套，输出新15套及表情锚点。"""
from pathlib import Path
from collections import deque
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/characters/customers/adventurers'
EXISTING = {'male_01','male_08','female_05'}
IDS = [f'{sex}_{i:02}' for i in range(1,10) for sex in ['male','female']]

def components(mask):
    seen=np.zeros_like(mask); result=[]; h,w=mask.shape
    for y,x in zip(*np.where(mask)):
        if seen[y,x]: continue
        q=deque([(int(y),int(x))]); seen[y,x]=True; pixels=[]
        while q:
            a,b=q.popleft(); pixels.append((a,b))
            for c,d in ((a-1,b),(a+1,b),(a,b-1),(a,b+1)):
                if 0<=c<h and 0<=d<w and mask[c,d] and not seen[c,d]:
                    seen[c,d]=True; q.append((c,d))
        result.append(pixels)
    return result

def clean(im):
    a=np.array(im.convert('RGBA'))
    parts=components(a[:,:,3]>=100)
    main=max(parts,key=len)
    keep=np.zeros(a.shape[:2],dtype=bool)
    for y,x in main: keep[y,x]=True
    # 保留主轮廓一像素抗锯齿边缘，去掉生成图的散点。
    expanded=keep.copy()
    expanded[1:] |= keep[:-1]; expanded[:-1] |= keep[1:]
    expanded[:,1:] |= keep[:,:-1]; expanded[:,:-1] |= keep[:,1:]
    a[~expanded,3]=0
    image=Image.fromarray(a)
    return image.crop(image.getbbox())

def face_points(im,row):
    a=np.array(im); rgb=a[:,:,:3].astype(int)
    mask=(rgb.max(2)<100)&(a[:,:,3]>180)
    yy,xx=np.indices(mask.shape)
    mask &= (xx>115)&(xx<270)&(yy>100)&(yy<245)
    candidates=[]
    for part in components(mask):
        p=np.array(part); lo=p.min(0); hi=p.max(0); h,w=hi-lo+1
        if 5<=w<=22 and 9<=h<=32 and 0.25<w/h<1.1 and len(part)>=30:
            candidates.append(((lo+hi)/2)[::-1])
    pairs=[(a,b) for a in candidates for b in candidates if 35<b[0]-a[0]<90 and abs(a[1]-b[1])<12]
    if not pairs: raise ValueError('无法定位双眼')
    left,right=min(pairs,key=lambda p:abs((p[0][0]+p[1][0])/2-192)+abs(p[0][1]-p[1][1])+abs(p[1][0]-p[0][0]-55)+abs((p[0][1]+p[1][1])/2-(165 if row==0 else 193)))
    center=(left+right)/2
    # 嘴巴以脸部中央红色轮廓定位。
    red=(rgb[:,:,0]>rgb[:,:,1]*1.5)&(rgb[:,:,0]>rgb[:,:,2]*1.5)&(rgb[:,:,0]>135)&(a[:,:,3]>180)
    red &= (abs(xx-center[0])<12)&(yy>center[1]+16)&(yy<center[1]+30)
    points=np.argwhere(red)
    lip=points.mean(0)[::-1] if len(points) else center+np.array([0,25])
    return [left.round(2).tolist(),right.round(2).tolist(),lip.round(2).tolist()]

manifest={}; preview=Image.new('RGB',(1440,720),'#f0dfbb'); draw=ImageDraw.Draw(preview)
for n,name in enumerate(IDS):
    path=OUT/f'{name}_actions.png'
    if name not in EXISTING:
        source=Image.open(OUT/'source'/f'{name}.png').convert('RGBA')
        sheet=Image.new('RGBA',(1536,1536))
        for row in range(4):
            for col in range(4):
                crop=clean(source.crop((round(col*source.width/4),round(row*source.height/4),round((col+1)*source.width/4),round((row+1)*source.height/4))))
                height=338 if row==0 or (row==3 and col>=2) else 308
                ratio=min(height/crop.height,300/crop.width)
                crop=crop.resize((round(crop.width*ratio),round(crop.height*ratio)),Image.Resampling.LANCZOS)
                sheet.alpha_composite(crop,(col*384+(384-crop.width)//2,row*384+380-crop.height))
        sheet.save(path)
        portrait=sheet.crop((80,40,304,230)); portrait.thumbnail((256,256),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(256,256)); canvas.alpha_composite(portrait,((256-portrait.width)//2,256-portrait.height)); canvas.save(OUT/f'{name}_portrait.png')
    sheet=Image.open(path).convert('RGBA')
    anchors=[]
    for row in [0,1]:
        im=sheet.crop((0,row*384,384,(row+1)*384))
        anchors.append(face_points(im,row))
    manifest[name]={'face':anchors,'cell_size':384}
    im=sheet.crop((0,384,384,768)); im.thumbnail((180,180),Image.Resampling.LANCZOS)
    x=(n%9)*160; y=(n//9)*350
    preview.paste(im,(x,y+30),im); draw.text((x+40,y+220),name,fill='#4e3528')
    im=sheet.crop((0,0,384,384)); im.thumbnail((120,120),Image.Resampling.LANCZOS)
    preview.paste(im,(x+25,y+235),im)
    print(name,anchors,flush=True)
(OUT/'rotation_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
(ROOT/'output/npc18').mkdir(parents=True,exist_ok=True)
preview.save(ROOT/'output/npc18/roster.png')
