"""仅规范生成图尺寸、清除极低Alpha噪点并制作深浅底复核图，不重画膜面。"""
from pathlib import Path
import json
from PIL import Image

root = Path(__file__).resolve().parents[2]
art = root / "output/fish-shore-20261030/art"
target = root / "assets/monsters/silverfish"
records = []
for action in ("idle", "attack"):
    source = art / f"{action}-shield-raw.png"
    image = Image.open(source).convert("RGBA")
    image = image.resize((512, 512), Image.Resampling.LANCZOS)
    image.putalpha(image.getchannel("A").point(lambda a: 0 if a <= 2 else round(a * .55)))
    image.save(target / f"shield_{action}.png")
    body = Image.open(target / f"{action}.png").convert("RGBA")
    board = Image.new("RGBA", (1024, 512))
    for i, color in enumerate(("#f2dfc1", "#173c3e")):
        back = Image.new("RGBA", (512, 512), color)
        back.alpha_composite(body)
        back.alpha_composite(image)
        board.paste(back, (512 * i, 0))
    board.save(art / f"{action}-review.png")
    records.append({"action": action, "source_size": Image.open(source).size, "size": image.size, "alpha_range": image.getchannel("A").getextrema()})
stranded = art / "stranded-raw.png"
if stranded.exists():
    image = Image.open(stranded).convert("RGBA").resize((512, 512), Image.Resampling.LANCZOS)
    image.putalpha(image.getchannel("A").point(lambda a: 0 if a <= 2 else a))
    image.save(target / "stranded.png")
    previews = []
    for frame in (2, 3):
        board = Image.new("RGBA", (1024, 128))
        for side, color in enumerate(("#f2dfc1", "#173c3e")):
            for direction in range(4):
                cell = image.crop((128*frame, 128*direction, 128*(frame+1), 128*(direction+1)))
                back = Image.new("RGBA", (128, 128), color)
                back.alpha_composite(cell)
                board.paste(back, (side*512+direction*128, 0))
        previews.append(board.convert("RGB"))
    previews[0].save(art / "stranded-review.gif", save_all=True, append_images=previews[1:], duration=180, loop=0)
    records.append({"action": "stranded", "size": image.size, "alpha_range": image.getchannel("A").getextrema()})
(art / "processed.json").write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(records, ensure_ascii=False))

