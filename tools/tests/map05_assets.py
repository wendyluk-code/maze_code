"""裁切已批准透明植物，复用已有纯闪光帧，不重绘图像。"""
from pathlib import Path
from PIL import Image,ImageSequence
import json
root=Path(__file__).resolve().parents[2]
out=root/'assets/props/region_resources'
source=root/'output/map05/generated'
source.mkdir(parents=True,exist_ok=True)
mapping={'cool_whisker_herb':'exec-5a8388fe-9983-4f13-b89c-e3f3f30f8675.png','canal_lotus_root':'exec-bc3844b7-f054-4c82-9f51-6bc6b7180722.png','lantern_fruit':'exec-8a805aea-2e4c-4e04-b2f8-b7a764deebae.png'}
manifest={}
for name,filename in mapping.items():
 src=source/(name+'.png')
 if not src.exists():
  import shutil
  shutil.copy(Path('C:/Users/KSG/.codex/generated_images/01a177be-6375-7900-9fb1-2dcdbbdcf8b9')/filename,src)
 im=Image.open(src).convert('RGBA'); box=im.getchannel('A').getbbox()
 cut=im.crop(box); cut.thumbnail((240,240),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',(256,256)); canvas.alpha_composite(cut,((256-cut.width)//2,248-cut.height)); canvas.save(out/(name+'.png'))
 manifest[name]={'source':str(src),'source_size':im.size,'alpha_bbox':box,'output':[256,256],'anchor':[128,248]}
gif=Image.open(root/'generated_assets/white_stars_dots_twinkle_256.gif')
frames=[f.convert('RGBA') for f in ImageSequence.Iterator(gif)]
atlas=Image.new('RGBA',(256*8,256*((len(frames)+7)//8)))
text=['[gd_resource type="SpriteFrames" load_steps=%d format=3]'%(len(frames)+2),'[ext_resource type="Texture2D" path="res://assets/props/region_resources/sparkles.png" id="1"]']
for i,frame in enumerate(frames):
 atlas.alpha_composite(frame,(i%8*256,i//8*256))
 text.extend([f'[sub_resource type="AtlasTexture" id="Frame_{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%8*256}, {i//8*256}, 256, 256)'])
atlas.save(out/'sparkles.png')
text.extend(['[resource]','animations = [{"frames": ['+','.join('{"duration":1.0,"texture":SubResource("Frame_%d")}'%i for i in range(len(frames)))+'],"loop":true,"name":&"sparkle","speed":12.0}]'])
(out/'sparkles.tres').write_text('\n'.join(text),encoding='utf-8')
manifest['sparkles']={'source':'generated_assets/white_stars_dots_twinkle_256.gif','frames':len(frames),'alpha_extrema':frames[0].getchannel('A').getextrema()}
(root/'output/map05/asset_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
