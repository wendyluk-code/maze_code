from pathlib import Path
from PIL import Image
root=Path('assets/monsters/wind_frog')
sheets=[Image.open(root/(name+'.png')).convert('RGBA') for name in ['idle','swim','attack','defeated']]
frames=[]
for index in range(16):
 frame=Image.new('RGBA',(768,768),(76,113,112,255))
 for column,sheet in enumerate(sheets):
  i=index%4 if column<2 else min(3,index%8)
  for row in range(4):
   part=sheet.crop((i*192,row*192,(i+1)*192,(row+1)*192))
   frame.alpha_composite(part,(column*192,row*192))
 frames.append(frame.convert('RGB'))
frames[0].save('output/map02/animation_preview.gif',save_all=True,append_images=frames[1:],duration=180,loop=0)
