"""生成批准稿/实机同尺寸对照与差异统计；不修改游戏素材。"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/summon_ui/revision_07"
OUT.mkdir(parents=True, exist_ok=True)
reference = Image.open(ROOT / "output/summon_ui/approved_reference.png").convert("RGB")
font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 22)
resolutions = [(1152,648),(1280,720),(1600,900),(1920,1080),(1280,800)]
results = []
for width,height in resolutions:
    suffix = f"{width}x{height}"
    actual_path = ROOT / f"output/summon_ui/summon_9000_{suffix}.png"
    actual = Image.open(actual_path).convert("RGB")
    assert actual.size == (width,height), (actual_path,actual.size)
    fit = min(width/1280,height/720)
    extent = (round(1280*fit),round(720*fit))
    offset = ((width-extent[0])//2,(height-extent[1])//2)
    expected = Image.new("RGB",(width,height),(61,41,23))
    expected.paste(reference.resize(extent,Image.Resampling.BILINEAR),offset)
    expected.save(OUT/f"reference_{suffix}.png")
    actual.save(OUT/f"actual_{suffix}.png")
    comparison = Image.new("RGB",(width*2,height+44),(39,32,25))
    comparison.paste(expected,(0,44)); comparison.paste(actual,(width,44))
    draw = ImageDraw.Draw(comparison)
    draw.text((18,7),f"批准稿 · {suffix}",font=font,fill="white")
    draw.text((width+18,7),f"实机 · {suffix}",font=font,fill="white")
    comparison.save(OUT/f"compare_{suffix}.png")
    diff = np.abs(np.asarray(expected).astype(float)-np.asarray(actual).astype(float))
    metrics = {}
    for name,box in {"三人主视觉（头侧无花纹圆弧底板竖排姓名另按最新要求验收）":(700,200,1220,590)}.items():
        x0,y0,x1,y1=box
        rect=(round(offset[0]+x0*extent[0]/1672),round(offset[1]+y0*extent[1]/941),round(offset[0]+x1*extent[0]/1672),round(offset[1]+y1*extent[1]/941))
        delta=diff[rect[1]:rect[3],rect[0]:rect[2]]
        metrics[name]={"mean_absolute_rgb_error_0_255":round(float(delta.mean()),3),"rect":rect}
    baseline = np.asarray(Image.open(ROOT / f"output/summon_ui/home_page_{suffix}.png").convert("RGB")).astype(int)
    fence = Image.open(ROOT / "assets/ui/home_collection/fence_foreground.png").getchannel("A").resize(extent,Image.Resampling.BILINEAR)
    mask = Image.new("L",(width,height)); mask.paste(fence,offset)
    # 避开2像素重采样边缘：半透明边缘会混入两个页签不同的玻璃底色。
    opaque = np.asarray(mask.filter(ImageFilter.MinFilter(5))) == 255
    fence_error = np.abs(np.asarray(actual).astype(int)-baseline)[opaque]
    assert int(fence_error.max()) == 0, f"栅栏发生变化 {suffix}"
    results.append({"resolution":suffix,"regions":metrics,"fence_interior_max_rgb_difference":int(fence_error.max())})
(OUT/"visual-report.json").write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding="utf-8")
options="".join(f'<option>{w}x{h}</option>' for w,h in resolutions)
html='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>召唤界面逐分辨率对照</title>
<style>body{margin:24px;background:#241f1a;color:#f8e5c8;font:16px system-ui}header{display:flex;gap:24px;align-items:center;margin-bottom:18px}select,input{accent-color:#e7b64f}#stage{position:relative;width:100%;max-width:1600px}img{width:100%;display:block}#expected{position:absolute;inset:0;clip-path:inset(0 50% 0 0)}#divider{position:absolute;inset:0 auto 0 50%;width:2px;background:#ffe49b}p{color:#cfbaa0}a{color:#ffe49b}</style>
<header><strong>召唤界面：批准稿 / 实机</strong><select id="resolution">OPTIONS</select><label>分界 <input id="split" type="range" min="0" max="100" value="50"></label><a id="pair">并排查看</a></header>
<p>左侧原批准稿，右侧最新实机。按用户最新要求，姓名改为头侧无花纹圆弧底板竖排姓名、按钮和价格使用游戏字体，暖灰禁用态，操作区保持栅栏上方；人物主视觉维持原稿比例。原位栅栏不透明内部与角色簿逐像素对照不变，1280×800按16:9居中。</p>
<div id="stage"><img id="actual"><img id="expected"><div id="divider"></div></div>
<script>const res=document.querySelector('#resolution'),split=document.querySelector('#split');function show(){document.querySelector('#actual').src='actual_'+res.value+'.png';document.querySelector('#expected').src='reference_'+res.value+'.png';document.querySelector('#pair').href='compare_'+res.value+'.png'}res.onchange=show;split.oninput=()=>{document.querySelector('#expected').style.clipPath='inset(0 '+(100-split.value)+'% 0 0)';document.querySelector('#divider').style.left=split.value+'%'};res.value='1280x720';show();</script></html>'''
(OUT/"compare.html").write_text(html.replace("OPTIONS",options),encoding="utf-8")
print(json.dumps(results,ensure_ascii=False))
