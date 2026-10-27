"""按已确认设计稿切片；仅对动态文字/立绘占位进行纸纹补片，不重绘装饰。"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'output/home_reference_slices/approved_reference.png'
OUT = ROOT / 'assets/ui/home_collection'
OUT.mkdir(parents=True, exist_ok=True)
ref = Image.open(SOURCE).convert('RGB')
records = {}

def save(name, im, box=None, note='原稿直接裁切'):
    im.save(OUT / (name + '.png'))
    records[name] = dict(rect=box, note=note, size=im.size)

def rounded(im, radius):
    mask = Image.new('L', im.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width-1, im.height-1), radius, fill=255)
    im = im.convert('RGBA'); im.putalpha(mask)
    return im

def patch(im, box, sample):
    texture = im.crop(sample).resize((box[2]-box[0], box[3]-box[1]), Image.Resampling.BICUBIC)
    layer = im.copy(); layer.paste(texture, box)
    mask = Image.new('L', im.size)
    ImageDraw.Draw(mask).rectangle(box, fill=255)
    return Image.composite(layer, im, mask.filter(ImageFilter.GaussianBlur(2)))

# 卡框、纸纹、四角和未收录叶枝保持原像素。动态内容用同卡空白纸纹覆盖。
card_box = (937, 233, 1220, 495)
card = ref.crop(card_box)
save('card_missing', rounded(card, 17), card_box)
blank = patch(card, (102, 74, 178, 154), (67, 154, 181, 187))
blank = patch(blank, (100, 207, 183, 245), (68, 170, 182, 202))
blank = patch(blank, (25, 198, 260, 243), (68, 170, 182, 202))
save('card_blank', rounded(blank, 17), card_box, '移除问号和文字，原纸纹补片；保留原四角，姓名带另叠原稿芽叶或山纹')
for name, box, label_box, sample in [
    ('name_yaya', (316, 451, 584, 487), (98, 1, 175, 35), (84, 1, 96, 35)),
    ('name_tieshan', (634, 451, 896, 487), (99, 1, 174, 35), (83, 1, 97, 35)),
]:
    save(name, patch(ref.crop(box), label_box, sample), box, '保留原芽叶/山纹姓名纸带，移除文字以动态显示姓名')

# 以局部背景的低阶曲面解混出透明墨色，保留原叶片轮廓、色阶和抗锯齿。
def ink(name, box, color):
    rgb = np.asarray(ref.crop(box)).astype(float)
    h,w,_ = rgb.shape; y,x = np.mgrid[:h,:w]; x=x/max(w-1,1); y=y/max(h-1,1)
    X=np.stack([np.ones_like(x),x,y,x*y,x*x,y*y],axis=-1).reshape(-1,6)
    pixels=rgb.reshape(-1,3); keep=np.ones(len(pixels),dtype=bool)
    for _ in range(5):
        coeff=np.linalg.lstsq(X[keep],pixels[keep],rcond=None)[0]
        bg=X@coeff
        darkness=(bg-pixels).mean(axis=1)
        keep=darkness < 5
    color=np.array(color,float)
    v=bg-color
    a=np.clip(np.sum((bg-pixels)*v,axis=1)/np.maximum(np.sum(v*v,axis=1),1),0,1)
    a[a<0.035]=0
    rgba=np.zeros((h,w,4),dtype=np.uint8); rgba[:,:,:3]=color; rgba[:,:,3]=(a.reshape(h,w)*255).astype(np.uint8)
    save(name,Image.fromarray(rgba),box,'由原稿像素解混透明底，不用几何图形重画')

ink('header_leaf',(237,160,283,219),(155,113,63))
ink('header_rule',(792,166,1563,219),(155,113,63))

# 完整页签保留左侧点线与右叶片；仅移除中间动态标题。
for name, box, label_box, points in [
    ('tab_selected',(45,225,254,321),(54,20,152,69),
     [(0,18),(2,10),(7,4),(13,1),(179,1),(187,4),(193,12),(207,42),(208,50),(205,59),(193,85),(187,91),(179,94),(13,94),(5,90),(1,83)]),
    ('tab_idle',(46,333,230,426),(52,19,120,69),
     [(0,18),(2,10),(8,4),(15,1),(152,1),(164,5),(171,16),(180,40),(183,49),(181,61),(171,80),(163,88),(152,92),(15,92),(6,87),(1,79)])
]:
    im=ref.crop(box)
    im=patch(im,label_box,(label_box[0],8,label_box[2],18))
    w,h=im.size
    mask=Image.new('L',(w*4,h*4))
    d=ImageDraw.Draw(mask)
    d.polygon([(x*4,y*4) for x,y in points],fill=255)
    rgba=im.convert('RGBA'); rgba.putalpha(mask.resize(im.size,Image.Resampling.LANCZOS))
    save(name,rgba,box,'保留原圆点、竖线、完整叶片、边框；仅文字以原底纹补片')

# 原背景栅栏真实上缘：含柱头、柱间横梁；不带整条地板矩形。
bg=Image.open(ROOT/'assets/maps/adventurer_home_collection.png').convert('RGBA')
# 在栅栏所在的限定带内追踪连续深色外轮廓；避免手描折线切掉柱肩。
rgb = np.asarray(bg.convert('RGB')).astype(float)
outline = rgb[700:840].mean(axis=2) < 139
edge = 700 + np.argmax(outline, axis=0)
assert outline.any(axis=0).all(), '每列都必须找到栅栏外轮廓'
# 包含边界的抗锯齿像素，背景与前景同图同适配，不会出现矩形地板覆盖。
alpha = np.clip((np.arange(bg.height)[:, None] - edge[None, :] + 1.5) * 255, 0, 255).astype('uint8')
bg.putalpha(Image.fromarray(alpha))
save('fence_foreground',bg,None,'原背景像素；按原背景深色外轮廓逐列提取柱头及横梁，透明抗锯齿边界，无地板矩形')

records['source']=str(SOURCE)
(OUT/'slices.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
# 放大联系表用于逐片检查。
sheet=Image.new('RGB',(1040,700),'#ad9980')
for name,at in [('header_leaf',(20,20)),('header_rule',(150,20)),('tab_selected',(20,150)),('tab_idle',(250,150)),('card_missing',(20,300)),('card_blank',(330,300)),('name_yaya',(650,300)),('name_tieshan',(650,370))]:
    im=Image.open(OUT/(name+'.png')); sheet.paste(im,at,im if im.mode=='RGBA' else None)
sheet.save(ROOT/'output/home_reference_slices/contact_sheet.png')
print('已输出',len(records)-1,'张可追溯切片至',OUT)
