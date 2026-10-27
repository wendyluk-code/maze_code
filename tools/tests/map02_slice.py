from pathlib import Path
from PIL import Image
import json, numpy as np
from collections import deque
def label(mask):
 lab=np.zeros(mask.shape,dtype=np.int32);n=0;h,w=mask.shape
 for y,x in zip(*np.where(mask)):
  if lab[y,x]:continue
  n+=1;lab[y,x]=n;q=deque([(y,x)])
  while q:
   yy,xx=q.popleft()
   for dy,dx in [(0,1),(0,-1),(1,0),(-1,0)]:
    ny,nx=yy+dy,xx+dx
    if 0<=ny<h and 0<=nx<w and mask[ny,nx] and not lab[ny,nx]:
     lab[ny,nx]=n;q.append((ny,nx))
 return lab,n

def extract(path,n,rows=None):

 rows=rows or n
 im=Image.open(path).convert('RGBA');a=np.array(im);labs,total=label(a[:,:,3]>40)
 sizes=np.bincount(labs.ravel());sizes[0]=0;groups={}
 for k in np.where(sizes>300)[0]:
  y,x=np.where(labs==k);cell=(min(n-1,int(x.mean()/im.width*n)),min(rows-1,int(y.mean()/im.height*rows)))
  if cell in groups and groups[cell][0]>sizes[k]:continue
  box=(int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1));part=a[box[1]:box[3],box[0]:box[2]].copy()
  part[:,:,3][labs[box[1]:box[3],box[0]:box[2]]!=k]=0
  groups[cell]=(int(sizes[k]),Image.fromarray(part),box,im.width/n)
 assert len(groups)==n*rows,(path,len(groups),list(groups))
 return groups
root=Path('output/map02');out=Path('assets/monsters/wind_frog');out.mkdir(parents=True,exist_ok=True)
g=extract(root/'wind_frog_source.png',8);r=extract(root/'wind_frog_rear_source.png',4);sp=extract(root/'wind_frog_special_source.png',4)
actions={name:{(x,y):g[(x+ox,y+oy)] for y in range(4) for x in range(4)} for name,(ox,oy) in {'idle':(0,0),'swim':(4,0),'attack':(0,4),'defeated':(4,4)}.items()}
for y in range(2):
 for x in range(4):
  actions['attack'][(x,y+2)]=r[(x,y)]
  actions['defeated'][(x,y+2)]=r[(x,y+2)]
actions['special']=sp
front=extract(root/'wind_frog_front_source.png',4,2)
for cell,entry in front.items(): actions['defeated'][cell]=entry
manifest=[];contact=Image.new('RGBA',(1536,1536))
for ai,(name,entries) in enumerate(actions.items()):
 sheet=Image.new('RGBA',(768,768))
 for (x,y),(_,part,box,base) in entries.items():
  # 使用各来源画布的统一比例，不对每帧独立拉伸；固定脚底锚点。
  factor=150/base
  w,h=(max(1,round(v*factor)) for v in part.size)
  part=part.resize((w,h),Image.Resampling.LANCZOS)
  assert w<=192 and h<=166,(name,x,y,w,h)
  sheet.alpha_composite(part,(x*192+(192-w)//2,y*192+158-h))
  manifest.append(dict(action=name,row=y,frame=x,bounds=box,size=[w,h]))
 sheet.save(out/(name+'.png'))
 if ai<4: contact.alpha_composite(sheet,((ai%2)*768,(ai//2)*768))
contact.save(root/'contact.png')
orb=Image.open(root/'water_source.png').convert('RGBA');orb=orb.crop(orb.getbbox());orb.thumbnail((128,128));orb.save(out/'water.png')
(root/'slice_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
