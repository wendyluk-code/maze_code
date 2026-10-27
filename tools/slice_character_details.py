"""HOME-01：批准设计的确定性无字裁切；坐标为原图像素，右下边界不含。"""
from pathlib import Path
import argparse, json, hashlib
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from collections import deque

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = Path('C:/Users/KSG/.codex/generated_images/01a14365-dae8-72a0-8527-9795eb16ff01')
p = argparse.ArgumentParser()
p.add_argument('--attributes', type=Path, default=DEFAULT/'exec-34d06468-7900-4f40-b1da-eb19c0f5b3aa.png')
p.add_argument('--skills', type=Path, default=DEFAULT/'exec-b73c7303-fbdd-4837-8203-1856f3aeb032.png')
p.add_argument('--breakthrough', type=Path, default=DEFAULT/'exec-8bf352e5-abc5-43cb-8250-ffce931f2605.png')
a = p.parse_args()
sources = {'attributes': Image.open(a.attributes).convert('RGBA'), 'skills': Image.open(a.skills).convert('RGBA'), 'breakthrough': Image.open(a.breakthrough).convert('RGBA')}
out = ROOT/'assets/ui/character_details'; out.mkdir(parents=True, exist_ok=True)
proof = ROOT/'output/home_detail_assets'; proof.mkdir(parents=True, exist_ok=True)
records = []

def save(name, im, source, boxes, method, margins=None):
    if name in ('divider','leaf_decoration'):
        method += '；按红绿通道色差提取透明度，线条统一暖金色'
        # 按原图暖金线条与纸面的色差提取透明度，避免矩形纸色污染。
        for y in range(im.height):
            for x in range(im.width):
                r,g,b,_=im.getpixel((x,y))
                alpha=max(0,min(255,(r-g-14)*14))
                im.putpixel((x,y),(203,163,102,alpha))
    if name in ('attack','satiety','star_lit','star_dim'):
        method += '；外部连通浅纸色去除'
        # 仅移除与外部连通的浅色纸面，保留封闭轮廓内的高光。
        pix=im.load(); seen=set(); q=deque()
        for x in range(im.width): q.extend([(x,0),(x,im.height-1)])
        for y in range(im.height): q.extend([(0,y),(im.width-1,y)])
        while q:
            x,y=q.popleft()
            if (x,y) in seen or not (0<=x<im.width and 0<=y<im.height): continue
            seen.add((x,y)); r,g,b,alpha=pix[x,y]
            if alpha==0 or (r>218 and g>202 and b>164 and r-b<76):
                pix[x,y]=(r,g,b,0)
                q.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
    im.save(out/f'{name}.png')
    records.append(dict(name=name, size=list(im.size), source=source, boxes=boxes, method=method, nine_patch_margins=margins))
    return im

def crop(name, box, source='attributes', polygon=None, ellipse=False):
    im=sources[source].crop(box)
    if polygon or ellipse:
        mask=Image.new('L', (im.width*4,im.height*4)); d=ImageDraw.Draw(mask)
        if ellipse: d.ellipse((4,4,im.width*4-5,im.height*4-5), fill=255)
        else: d.polygon([((x-box[0])*4,(y-box[1])*4) for x,y in polygon],fill=255)
        im.putalpha(mask.resize(im.size,Image.Resampling.LANCZOS))
    return save(name,im,source,[box],'原图裁切；轮廓蒙版抗锯齿' if polygon or ellipse else '原图无字区域')

def horizontal(name, box, left, right, sample, source='attributes', radius=0):
    im=sources[source].crop(box); w,h=im.size
    clean=sources[source].crop((sample,box[1],sample+4,box[3])).resize((w-left-right,h))
    blend=Image.new('L',clean.size,255)
    if name.startswith('tab_'):
        for x in range(18):
            ImageDraw.Draw(blend).line((x,0,x,h),fill=int(255*x/18))
            ImageDraw.Draw(blend).line((clean.width-1-x,0,clean.width-1-x,h),fill=int(255*x/18))
    im.paste(clean,(left,0),blend)
    if radius:
        mask=Image.new('L',(w*4,h*4)); ImageDraw.Draw(mask).rounded_rectangle((4,4,w*4-5,h*4-5),radius=radius*4,fill=255)
        im.putalpha(mask.resize(im.size,Image.Resampling.LANCZOS))
    return save(name,im,source,[box,[sample,box[1],sample+4,box[3]]],f'保留左右 {left}/{right} 像素，无字竖条横向填充',[left,8,right,8])

crop('paper_tile',(930,370,1058,430))
im=sources['attributes'].crop((618,12,1035,113))
patch=sources['attributes'].crop((932,36,975,90)).resize((238,80)).filter(ImageFilter.GaussianBlur(1.4))
mask=Image.new('L',patch.size); ImageDraw.Draw(mask).rectangle((2,2,235,77),fill=255); mask=mask.filter(ImageFilter.GaussianBlur(2))
im.paste(patch,(94,13),mask)
outer=Image.new('L',im.size); ImageDraw.Draw(outer).rounded_rectangle((0,0,416,100),radius=30,fill=255); im.putalpha(outer)
save('tab_selected',im,'attributes',[[618,12,1035,113],[932,36,975,90]],'无字绿色纸纹二维扩展，羽化拼接',[82,8,65,8])
horizontal('tab_idle',(610,17,1035,112),82,65,685,source='skills',radius=30)
horizontal('skill_row_active',(627,151,1602,274),20,20,1490,source='skills',radius=27)
horizontal('skill_row_locked',(629,282,1602,395),20,20,1450,source='skills',radius=28)
horizontal('progress_track',(655,305,1587,363),12,36,1000,radius=28)
# 左端绿色弧面，末端从同一无字填充区域镜像组合。
fill=sources['attributes'].crop((665,313,885,354)); fill.paste(fill.crop((0,0,20,41)).transpose(Image.Transpose.FLIP_LEFT_RIGHT),(200,0))
mask=Image.new('L',fill.size); ImageDraw.Draw(mask).rounded_rectangle((0,0,219,40),radius=18,fill=255); fill.putalpha(mask)
save('progress_fill',fill,'attributes',[[665,313,885,354]],'原图绿色填充；左端镜像作为右端',[20,8,20,8])
def button(name,source):
    src=sources[source]
    # 右端无字弧边沿用原稿；中央用宽片无字色面，避免单竖条拖影。
    im=Image.new('RGBA',(424,103))
    center=src.crop((1300,185,1510,288)).resize((324,103))
    paper=src.crop((1300,198,1510,215)).resize((324,79)).filter(ImageFilter.GaussianBlur(2))
    m=Image.new('L',paper.size,255)
    for y in range(8):
        ImageDraw.Draw(m).line((0,y,323,y),fill=int(y*255/8))
        ImageDraw.Draw(m).line((0,78-y,323,78-y),fill=int(y*255/8))
    center.paste(paper,(0,12),m)
    cap=src.crop((1535,185,1585,288))
    # 原右端最左的文字尾部以中心纸纹覆盖，羽化至纯弧边。
    cap_patch=paper.resize((50,79)); cm=Image.new('L',(50,79))
    cd=ImageDraw.Draw(cm); cd.rectangle((0,8,19,70),fill=255)
    for x in range(20,31): cd.line((x,8,x,70),fill=int((31-x)*255/11))
    cm=cm.filter(ImageFilter.GaussianBlur(2)); cap.paste(cap_patch,(0,12),cm)
    im.paste(center,(50,0)); im.paste(cap,(374,0)); im.paste(cap.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(0,0))
    for seam in (50,374):
        region=im.crop((seam-16,9,seam+16,95))
        blurred=region.filter(ImageFilter.GaussianBlur(6))
        sm=Image.new('L',region.size)
        for x in range(32): ImageDraw.Draw(sm).line((x,0,x,85),fill=int(255*(1-abs(x-15.5)/16)))
        im.paste(blurred,(seam-16,9),sm)
    mask=Image.new('L',(1696,412)); ImageDraw.Draw(mask).rounded_rectangle((4,4,1691,407),radius=204,fill=255)
    im.putalpha(mask.resize(im.size,Image.Resampling.LANCZOS))
    save(name,im,source,[[1300,185,1510,288],[1300,198,1510,215],[1535,185,1585,288]],'无字宽片柔化拼接；右弧边镜像作左边；去除文字尾部',[50,12,50,12])
button('breakthrough_base','attributes')
button('breakthrough_active','breakthrough')
crop('star_lit',(91,685,171,765),polygon=[(130,687),(139,704),(143,708),(165,713),(168,721),(150,735),(150,755),(143,761),(129,752),(111,760),(103,757),(106,735),(94,723),(94,716),(117,708),(124,692)])
crop('star_dim',(179,693,244,760),polygon=[(211,695),(222,712),(238,715),(242,721),(228,735),(229,750),(224,756),(210,749),(194,756),(189,752),(191,734),(181,722),(182,716),(201,712)])
crop('attack',(687,470,767,548),polygon=[(745,473),(762,472),(764,485),(759,504),(737,521),(741,530),(737,536),(728,537),(714,546),(704,548),(694,544),(690,536),(696,527),(705,519),(699,513),(700,506),(706,503),(713,508),(728,485)])
crop('satiety',(684,569,765,651),polygon=[(705,570),(741,570),(753,580),(749,597),(759,604),(764,615),(762,634),(752,644),(729,650),(704,645),(691,634),(687,618),(686,607),(697,601),(699,584)])
crop('recovery',(684,682,764,753),polygon=[(687,697),(696,687),(707,684),(720,690),(728,692),(740,685),(751,687),(760,696),(762,709),(756,724),(738,744),(725,751),(710,742),(694,727),(687,713)])
crop('lock',(655,289,751,385),'skills',ellipse=True)
crop('skill_gift',(654,162,759,267),'skills',ellipse=True)
crop('divider',(658,430,1591,459))
crop('leaf_decoration',(1518,303,1579,386),'skills')
# 纸面九宫格来自无角色、无文字的右面板上沿及左右边框。
im=Image.new('RGBA',(256,256)); tile=sources['attributes'].crop((930,370,1058,430)).resize((256,256)); im.paste(tile)
im.paste(sources['attributes'].crop((620,126,748,159)).resize((128,33)),(0,0))
im.paste(sources['attributes'].crop((620,126,748,159)).transpose(Image.Transpose.FLIP_LEFT_RIGHT),(128,0))
im.paste(sources['attributes'].crop((610,370,635,430)).resize((25,198)),(0,33))
im.paste(sources['attributes'].crop((1612,370,1637,430)).resize((25,198)),(231,33))
im.paste(sources['attributes'].crop((900,875,1156,900)),(0,231))
save('paper_panel',im,'attributes',[[930,370,1058,430],[620,126,748,159],[610,370,635,430],[1612,370,1637,430],[900,875,1156,900]],'无字纸面和边缘组合九宫格；右上角镜像左上角',[25,33,25,25])
gold=Image.open(ROOT/'assets/ui/hud_currency/gold.png').convert('RGBA')
save('gold',gold,'assets/ui/hud_currency/gold.png',[],'复用已有金币，像素不变')
manifest={'source_size':{k:list(v.size) for k,v in sources.items()},'source_sha256':{k:hashlib.sha256(v.read_bytes()).hexdigest() for k,v in [('attributes',a.attributes),('skills',a.skills),('breakthrough',a.breakthrough)]},'assets':records,'six_stars':'重复 star_lit/star_dim 共六次；不包含固定数量状态'}
(out/'slices.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
font=ImageFont.truetype(str(ROOT/'assets/ui/zcool_kuail.ttf'),18)
sheet=Image.new('RGB',(1000,((len(records)+2)//3)*220),(238,232,218)); d=ImageDraw.Draw(sheet)
for i,r in enumerate(records):
    x=(i%3)*333; y=(i//3)*220
    for yy in range(y+30,y+210,12):
        for xx in range(x+5,x+325,12): d.rectangle((xx,yy,xx+11,yy+11),fill=(205,205,205) if ((xx-x-5)//12+(yy-y-30)//12)%2 else (250,250,250))
    im=Image.open(out/(r['name']+'.png')); im.thumbnail((310,165))
    sheet.paste(im,(x+10+(310-im.width)//2,y+40+(165-im.height)//2),im)
    d.text((x+9,y+5),r['name'],font=font,fill=(65,45,30))
sheet.save(proof/'contact_sheet.png')
demo=Image.new('RGBA',(1200,760),(70,55,42,255))
panel=Image.open(out/'paper_panel.png')
# 组合示意使用九宫格，边角保持源像素大小。
sx=[0,25,231,256]; sy=[0,33,231,256]; dx=[20,45,1155,1180]; dy=[20,53,715,740]
for yi in range(3):
    for xi in range(3):
        part=panel.crop((sx[xi],sy[yi],sx[xi+1],sy[yi+1])).resize((dx[xi+1]-dx[xi],dy[yi+1]-dy[yi]))
        demo.alpha_composite(part,(dx[xi],dy[yi]))
def place(name,xy,size=None):
    im=Image.open(out/(name+'.png'))
    if size: im=im.resize(size,Image.Resampling.LANCZOS)
    demo.alpha_composite(im,xy)
place('tab_selected',(440,35),(330,80)); place('tab_idle',(775,35),(330,80))
for i in range(6): place('star_lit' if i<2 else 'star_dim',(60+i*55,510),(48,48))
place('progress_track',(450,155),(650,40)); place('progress_fill',(457,161),(200,28))
for i,n in enumerate(['attack','satiety','recovery']): place(n,(460,245+i*115),(64,64))
for i in range(3): place('divider',(450,330+i*115),(650,20))
place('breakthrough_active',(740,640),(340,80)); place('gold',(755,648),(64,64))
demo.save(proof/'assembly_no_text.png')
checks=[]
for r in records:
    im=Image.open(out/(r['name']+'.png'))
    checks.append({'name':r['name'],'mode':im.mode,'size':list(im.size),'alpha_extrema':im.getchannel('A').getextrema(),'sha256':hashlib.sha256((out/(r['name']+'.png')).read_bytes()).hexdigest()})
(proof/'checks.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'生成 {len(records)} 张素材及联系表')
