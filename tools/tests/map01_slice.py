from PIL import Image
from pathlib import Path
import numpy as np
from collections import deque
def label(mask):
 lab=np.zeros(mask.shape,dtype=np.int32);n=0
 h,w=mask.shape
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
import json

# 按整图alpha连通主体分格：允许生成器把鳍尾画过理论格线，不沿格线截断主体。
def extract(path,grid):
 src=Image.open(path).convert('RGBA');a=np.array(src)
 lab,n=label(a[:,:,3]>40);sizes=np.bincount(lab.ravel());sizes[0]=0
 groups={}
 for component in np.where(sizes>300)[0]:
  yy,xx=np.where(lab==component)
  cx,cy=float(xx.mean()),float(yy.mean())
  cell=(min(grid-1,int(cx/src.width*grid)),min(grid-1,int(cy/src.height*grid)))
  if cell in groups and groups[cell][0]>sizes[component]:continue
  box=(int(xx.min()),int(yy.min()),int(xx.max())+1,int(yy.max())+1)
  part=a[box[1]:box[3],box[0]:box[2]].copy()
  part[:,:,3][lab[box[1]:box[3],box[0]:box[2]]!=component]=0
  groups[cell]=(sizes[component],Image.fromarray(part),box,src.width/grid)
 assert len(groups)==grid*grid,(path,len(groups))
 return groups
report={}
for kind in ['silverfish','thunder_eel']:
 groups=extract(f'output/map01/{kind}_source.png',8)
 actions={}
 for name,(ox,oy) in {'idle':(0,0),'swim':(4,0),'attack':(0,4),'defeated':(4,4)}.items():
  actions[name]={(x,y):groups[(x+ox,y+oy)] for y in range(4) for x in range(4)}
 if kind=='thunder_eel':actions['attack']=extract('output/map01/thunder_eel_attack_clean_source.png',4)
 maximum=max(max(v[1].size)/v[3] for entries in actions.values() for v in entries.values())
 factor=112/maximum
 out=Path(f'assets/monsters/{kind}');out.mkdir(parents=True,exist_ok=True)
 report[kind]={'source_atlas_size':Image.open(f'output/map01/{kind}_source.png').size,'frame_size':[128,128],'uniform_normalized_scale':factor,'cells':[]}
 contact=Image.new('RGBA',(1024,1024))
 for name,entries in actions.items():
  sheet=Image.new('RGBA',(512,512))
  for (x,y),(_,part,box,base) in entries.items():
   w,h=[max(1,round(v/base*factor)) for v in part.size]
   part=part.resize((w,h),Image.Resampling.LANCZOS)
   sheet.paste(part,(x*128+(128-w)//2,y*128+(128-h)//2))
   report[kind]['cells'].append({'action':name,'direction_row':y,'frame':x,'source_alpha_bounds':box,'drawn_size':[w,h]})
  sheet.save(out/f'{name}.png')
  ox,oy={'idle':(0,0),'swim':(512,0),'attack':(0,512),'defeated':(512,512)}[name]
  contact.paste(sheet,(ox,oy))
 contact.save(f'output/map01/{kind}_contact.png')
Path('output/map01/slice_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
