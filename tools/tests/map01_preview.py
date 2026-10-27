from PIL import Image,ImageDraw
images=[]
actions=['idle','swim','attack','defeated']
for i in range(8):
 preview=Image.new('RGB',(1024,552),(90,126,115));draw=ImageDraw.Draw(preview)
 for k,kind in enumerate(['silverfish','thunder_eel']):
  for j,action in enumerate(actions):
   sheet=Image.open(f'assets/monsters/{kind}/{action}.png')
   draw.text((k*512+j*128+6,7),kind+' '+action,fill='white')
   for direction in range(4):
    frame=min(3,i) if action in ['attack','defeated'] else i%4
    part=sheet.crop((frame*128,direction*128,(frame+1)*128,(direction+1)*128))
    preview.paste(part,(k*512+j*128,40+direction*128),part)
 images.append(preview)
images[0].save('output/map01/animation_preview.gif',save_all=True,append_images=images[1:],duration=180,loop=0,disposal=2)
images[2].save('output/map01/animation_contact_labeled.png')
