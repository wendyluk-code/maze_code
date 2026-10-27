from PIL import Image
from pathlib import Path
root=Path("output/salia_side_cast_final")
frames=[]
for i in range(6):
    image=Image.open(root/f"cast_right_{i}_1280x720.png").convert("RGB")
    frames.append(image.crop((700,160,1140,400)).resize((880,480),Image.Resampling.LANCZOS))
frames[0].save(root/"salia_side_cast_preview.gif",save_all=True,append_images=frames[1:],duration=[400,80,80,80,80,500],loop=0,optimize=False)
