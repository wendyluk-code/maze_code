from pathlib import Path
from PIL import Image,ImageDraw
import json
exec(Path('tools/tests/map02_slice.py').read_text(encoding='utf-8').split("root=Path('output/map02')")[0])
root=Path('output/map03');manifest={}
for kind in ['mimic_crab','blind_scorpion']:
 g=extract(root/(f'{kind}_spaced_source.png' if kind=='mimic_crab' else f'{kind}_source.png'),8)
 r=extract(root/f'{kind}_rear_source.png',4,2 if kind=='mimic_crab' else 4)
 actions={name:{(x,y):g[(x+ox,y+oy)] for y in range(4) for x in range(4)} for name,(ox,oy) in {'idle':(0,0),'swim':(4,0),'attack':(0,4),'defeated':(4,4)}.items()}
 if kind=='blind_scorpion':
  for cell,part in extract(root/'blind_scorpion_front_source.png',4,2).items(): actions['attack'][cell]=part
 for y in range(2):
  for x in range(4):
   actions['attack'][(x,y+2)]=r[(x,y)]
   if kind=='blind_scorpion':actions['defeated'][(x,y+2)]=r[(x,y+2)]
 out=Path('assets/monsters')/kind;out.mkdir(parents=True,exist_ok=True)
 contact=Image.new('RGBA',(1024,1024));entries=[]
 for ai,(action,cells) in enumerate(actions.items()):
  sheet=Image.new('RGBA',(512,512))
  for (x,y),(_,part,box,base) in cells.items():
   scale=(108 if kind=='blind_scorpion' and action in ['attack','defeated'] and y>=2 else 94)/base
   w,h=[max(1,round(v*scale)) for v in part.size]
   assert w<=124 and h<=104,(kind,action,x,y,w,h)
   part=part.resize((w,h),Image.Resampling.LANCZOS)
   sheet.alpha_composite(part,(x*128+(128-w)//2,y*128+105-h))
   entries.append(dict(action=action,direction=y,frame=x,source_bounds=box,size=[w,h],anchor=[64,105]))
  sheet.save(out/(action+'.png'))
  contact.alpha_composite(sheet,((ai%2)*512,(ai//2)*512))
 contact.save(root/f'{kind}_contact.png');manifest[kind]=entries
 meat='mimic_crab_meat' if kind=='mimic_crab' else 'blind_scorpion_tail'
 Image.open(f'output/food_icons_20261015/icons/{meat}.png').save(out/'meat.png')
root.joinpath('slice_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
frames=[]
for i in range(8):
 im=Image.new('RGB',(1024,552),(90,126,115));d=ImageDraw.Draw(im)
 for k,kind in enumerate(manifest):
  for j,action in enumerate(['idle','swim','attack','defeated']):
   sheet=Image.open(f'assets/monsters/{kind}/{action}.png')
   d.text((k*512+j*128+3,10),kind+' '+action,fill='white')
   for direction in range(4):
    f=min(3,i) if action in ['attack','defeated'] else i%4
    part=sheet.crop((f*128,direction*128,(f+1)*128,(direction+1)*128))
    im.paste(part,(k*512+j*128,40+direction*128),part)
 frames.append(im)
frames[0].save(root/'animation_preview.gif',save_all=True,append_images=frames[1:],duration=180,loop=0,disposal=2)
frames[2].save(root/'animation_contact.png')
