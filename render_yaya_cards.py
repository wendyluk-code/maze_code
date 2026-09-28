from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

OUT = Path(r"C:\Users\KSG\.codex\visualizations\2026\09\23\01a0cd00-793f-7170-adb8-643b27d2d9f0\yaya-spell-cards-v3")
OUT.mkdir(parents=True, exist_ok=True)
ILL = [
r"C:\Users\KSG\.codex\generated_images\01a0cd00-793f-7170-adb8-643b27d2d9f0\exec-da1b5621-b218-45fa-8315-479aeb6af93d.png",
r"C:\Users\KSG\.codex\generated_images\01a0cd00-793f-7170-adb8-643b27d2d9f0\exec-648a1b17-8c83-48b9-be07-20de10792527.png",
r"C:\Users\KSG\.codex\generated_images\01a0cd00-793f-7170-adb8-643b27d2d9f0\exec-b1b18ebc-1d90-4d34-938c-8d4656eae707.png",
r"C:\Users\KSG\.codex\generated_images\01a0cd00-793f-7170-adb8-643b27d2d9f0\exec-3689313c-6207-4c17-bfb2-48d87d34e6d4.png",
r"C:\Users\KSG\.codex\generated_images\01a0cd00-793f-7170-adb8-643b27d2d9f0\exec-d37a68d7-3a91-4e5e-9554-63ca1f076756.png",
r"C:\Users\KSG\.codex\generated_images\01a0cd00-793f-7170-adb8-643b27d2d9f0\exec-a0363e70-96ab-49d1-88ab-9cef3f408506.png",
r"C:\Users\KSG\.codex\generated_images\01a0cd00-793f-7170-adb8-643b27d2d9f0\exec-ba987318-196a-4630-87a0-76c1ffd8c9b7.png",
r"C:\Users\KSG\.codex\generated_images\01a0cd00-793f-7170-adb8-643b27d2d9f0\exec-35c171f4-48fa-44f4-8a75-c0afefaff0d1.png",
]
CARDS = [
("先吃一口","1","R","为一个友方目标恢复 3 点生命。"),
("大家都有","2","R","为全体友方恢复 2 点生命。"),
("芽芽找找","1","R","抽 2 张牌，然后选择 1 张手牌放回牌库底。"),
("这张有用！","2","R","抽 2 张牌。"),
("别睡过去！","1","R","为一个未气绝的友方角色恢复 2 点生命。若其治疗前生命不高于 2 点，再抽 1 张牌。"),
("慢慢养好","1","R","为一个未气绝的友方角色恢复 1 点生命；下个己方回合开始时，再为其恢复 2 点生命。后续治疗不可叠加，目标气绝时移除。"),
("趁热吃呀","1","R","为一个友方目标恢复 2 点生命。若己方本回合已经使用过料理，再抽 1 张牌。"),
("都回来吃饭！","2","SR","为全体友方恢复 3 点生命，然后抽 1 张牌。"),
]
FONT = r"C:\Windows\Fonts\NotoSansSC-VF.ttf"
def font(n): return ImageFont.truetype(FONT, n)
def center(d, text, y, size, fill=(83,62,50), bold=False, cx=512):
    f = font(size)
    box = d.textbbox((0,0), text, font=f)
    d.text((cx-(box[2]-box[0])/2, y), text, font=f, fill=fill)
def wrap(s, n): return [s[i:i+n] for i in range(0,len(s),n)]
def clean(src):
    # Generated transparent assets are used directly. For checkerboard previews,
    # make near-gray connected background pixels transparent.
    im = Image.open(src).convert("RGBA")
    px = im.load(); w,h=im.size
    from collections import deque
    q=deque([(x,0) for x in range(w)]+[(x,h-1) for x in range(w)]+[(0,y) for y in range(h)]+[(w-1,y) for y in range(h)])
    seen=set()
    while q:
        x,y=q.popleft()
        if not(0<=x<w and 0<=y<h) or (x,y) in seen: continue
        seen.add((x,y)); r,g,b,a=px[x,y]
        if a==0 or (max(r,g,b)-min(r,g,b)<=2 and 100<=r<=255):
            px[x,y]=(0,0,0,0)
            q.extend(((x+1,y),(x-1,y),(x,y+1),(x,y-1)))
    return im
for i,(name,cost,rarity,effect) in enumerate(CARDS):
    # Rebuild a clean, deterministic frame instead of painting over a generated
    # card. This guarantees identical geometry on all eight cards.
    im=Image.new("RGBA",(1024,1536),(0,0,0,0)); d=ImageDraw.Draw(im)
    d.rounded_rectangle((32,26,992,1510),radius=46,fill=(105,125,83,255),outline=(244,231,190,255),width=5)
    d.rounded_rectangle((48,42,976,1494),radius=36,fill=(248,244,224,255),outline=(224,212,169,255),width=3)
    d.rectangle((92,95,932,1000),fill=(244,238,215,255))
    art=clean(ILL[i]); scale=min(780/art.width,770/art.height); art=art.resize((int(art.width*scale),int(art.height*scale)),Image.Resampling.LANCZOS)
    im.alpha_composite(art,(int((1024-art.width)/2),int(150+(770-art.height)/2)))
    d=ImageDraw.Draw(im)
    d.rectangle((92,1050,932,1440),fill=(255,251,240,255))
    d.ellipse((68,112,248,292),fill=(112,137,86,255),outline=(255,255,255,255),width=8); center(d,cost,132,110,(255,255,255),True,158)
    d.ellipse((829,1320,934,1425),fill=(197,145,59,255),outline=(255,255,255,255),width=3); center(d,rarity,1338,38 if rarity=="SR" else 48,(255,255,255),True,881)
    center(d,name,1070,50,(83,62,50),True,512); center(d,"芽芽 · 法术",1140,26,(83,62,50),False,512)
    size=29 if len(effect)>28 else 37; n=17 if len(effect)>38 else (19 if len(effect)>25 else 16)
    for j,line in enumerate(wrap(effect,n)): center(d,line,1200+j*(size+13),size,(83,62,50),False,512)
    im.save(OUT/f"{i+1:02d}-{name}.png")
print(*[f"{p.name} {Image.open(p).size}" for p in sorted(OUT.glob("*.png"))], sep="\n")
