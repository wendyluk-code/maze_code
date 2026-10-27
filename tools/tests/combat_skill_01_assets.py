"""从用户选定帧表分离动作与离体特效，原稿不改。"""
from pathlib import Path
from PIL import Image
import numpy as np
def label(mask):
    # 512px帧表的四邻域连通块，无额外依赖。
    result=np.zeros(mask.shape,dtype=np.int32)
    count=0
    h,w=mask.shape
    for y,x in zip(*np.where(mask)):
        if result[y,x]: continue
        count+=1; result[y,x]=count; stack=[(int(y),int(x))]
        while stack:
            cy,cx=stack.pop()
            for ny,nx in ((cy-1,cx),(cy+1,cx),(cy,cx-1),(cy,cx+1)):
                if 0<=ny<h and 0<=nx<w and mask[ny,nx] and result[ny,nx]==0:
                    result[ny,nx]=count; stack.append((ny,nx))
    return result,count

def binary_dilation(mask,iterations=1):
    from PIL import ImageFilter
    return np.array(Image.fromarray(mask).filter(ImageFilter.MaxFilter(iterations*2+1))).astype(bool)
import json
root=Path(__file__).resolve().parents[2]
src=root/'output/combat_skill_preview/selected'
out=root/'assets/combat/team_skills'
out.mkdir(parents=True,exist_ok=True)
records={}
for name in ['throw','light','axe','raise','slime','impact_sheet']:
    sheet=Image.open(src/(name+'.png')).convert('RGBA').resize((2048,1024),Image.Resampling.LANCZOS)
    frames=[]
    for i in range(8):
        part=sheet.crop(((i%4)*512,(i//4)*512,(i%4+1)*512,(i//4+1)*512))
        arr=np.array(part)
        if name=='impact_sheet':
            frames.append(part); continue
        # 连通块只保留角色主体，离手锅铲、光点及吐出的黏液另取纹理。
        labels,count=label(arr[:,:,3]>32)
        sizes=np.bincount(labels.ravel()); sizes[0]=0
        biggest=int(sizes.argmax())
        mask=binary_dilation(labels==biggest,iterations=2)
        if name=='light':
            # 发光区域与手连接，按颜色剥离金色高亮粒子（仅手前范围）。
            yy,xx=np.indices((512,512))
            mask &= ~((xx>320)&(yy<310))
        if name=='slime' and i==3:
            # 嘴前与本体连着的拉丝在发射点切开，弹丸单独飞行。
            mask[:,280:]=False
        clean=arr.copy();clean[:,:,3]=np.where(mask,arr[:,:,3],0)
        part=Image.fromarray(clean)
        opaque=clean[:,:,3]>100
        ys,xs=np.where(opaque)
        floor=int(ys.max())+1
        bottom=opaque[max(0,floor-20):floor]
        bx=np.where(bottom)[1]
        anchor=float(np.median(bx)) if len(bx) else 256
        # 统一身体高度，武器不参与比例计算；一张序列始终同倍率。
        scale=0.75 if name in ['axe','raise'] else 0.80
        if name=='slime': scale=1.0
        part=part.resize((round(512*scale),round(512*scale)),Image.Resampling.LANCZOS)
        canvas=Image.new('RGBA',(512,512))
        canvas.alpha_composite(part,(round(256-anchor*scale),round(440-floor*scale)))
        frames.append(canvas)
    atlas=Image.new('RGBA',(2048,1024))
    for i,frame in enumerate(frames): atlas.alpha_composite(frame,((i%4)*512,(i//4)*512))
    atlas.save(out/(name+'.png'))
    records[name]={'frames':8,'cell':[512,512],'foot':[256,440]}

# 用选定图中的独立飞行物制作纹理，不重画。
sheet=Image.open(src/'light.png').convert('RGBA').resize((2048,1024))
orb=sheet.crop((3*512+350,130,4*512,270));orb=orb.crop(orb.getbbox());orb.save(out/'light_orb.png')
sheet=Image.open(src/'slime.png').convert('RGBA').resize((2048,1024))
orb=sheet.crop((300,512+200,512,512+340));orb=orb.crop(orb.getbbox());orb.save(out/'slime_orb.png')
(out/'conversion.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
print('converted',len(records),'atlases and 2 projectiles')
