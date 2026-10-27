from pathlib import Path
from PIL import Image,ImageDraw
import json
exec(Path('tools/tests/map02_slice.py').read_text(encoding='utf-8').split("root=Path('output/map02')")[0])
root=Path('output/map04');out=Path('assets/monsters/rockmane');out.mkdir(parents=True,exist_ok=True)
g=extract(root/'rockmane_source.png',8); sp=extract(root/'rockmane_special_source.png',4,8)
actions={}
for ai,name in enumerate(['idle','swim','attack','defeated']):
 actions[name]={(x,y):g[(x+(y%2)*4,ai*2+y//2)] for y in range(4) for x in range(4)}
for ai,name in enumerate(['charge','rush']):
 actions[name]={(x,y):sp[(x,y+ai*4)] for y in range(4) for x in range(4)}
manifest=[];contact=Image.new('RGBA',(1536,2304))
for ai,(name,entries) in enumerate(actions.items()):
 sheet=Image.new('RGBA',(768,768))
 for (x,y),(_,part,box,base) in entries.items():
  factor=150/base
  w,h=[max(1,round(v*factor)) for v in part.size]
  assert w<192 and h<=158,(name,x,y,w,h)
  part=part.resize((w,h),Image.Resampling.LANCZOS)
  sheet.alpha_composite(part,(x*192+(192-w)//2,y*192+158-h))
  manifest.append(dict(action=name,direction=y,frame=x,bounds=box,size=[w,h],anchor=[96,158]))
 sheet.save(out/(name+'.png'));contact.alpha_composite(sheet,((ai%2)*768,(ai//2)*768))
contact.save(root/'contact.png');root.joinpath('slice_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
frames=[]
for i in range(8):
 im=Image.new('RGB',(1152,800),(100,125,115));d=ImageDraw.Draw(im)
 for j,name in enumerate(actions):
  sh=Image.open(out/(name+'.png'));d.text((j*192+5,4),name,fill='white')
  for y in range(4):
   f=min(3,i) if name in ['attack','defeated'] else i%4
   part=sh.crop((f*192,y*192,(f+1)*192,(y+1)*192));im.paste(part,(j*192,y*192+32),part)
 frames.append(im)
frames[0].save(root/'animation_preview.gif',save_all=True,append_images=frames[1:],duration=180,loop=0,disposal=2)
frames[2].save(root/'animation_contact.png')
