extends "res://tools/tests/fenshui_frog_depth.gd"
## 复用相同真实像素遮挡断言，只改候选方向与检查分辨率。

func depth_resolution() -> Vector2i:
 return Vector2i(1280,720) if _arg("--phase=")=="wide" else Vector2i(1152,648)

func prepare_frog(frog: Node2D) -> void:
 _check(frog.set_frog_motion_direction(1),"实际巨蛙节点启用完整左前素材")

func ground_bottom(frog: Node2D) -> float:
 var image: Image=frog.body.texture.get_image()
 if frog.body.region_enabled: image=image.get_region(Rect2i(frog.body.region_rect))
 for y in range(image.get_height()-1,-1,-1):
  for x in image.get_width():
   if image.get_pixel(x,y).a>=0.5:
    return frog.body.to_global(frog.body.get_rect().position+Vector2(x,y+1)).y
 return INF
