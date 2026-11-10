extends SceneTree
## 从正式脚底/干地规则烘焙显示遮罩，不读取原图颜色，不修改战斗地形。
const FS=preload("res://data/maze/fenshui_roads.gd")

func _initialize() -> void:
 var size:=Vector2i(858,459)
 var image:=Image.create(size.x,size.y,false,Image.FORMAT_RGB8)
 for y in size.y:
  for x in size.x:
   var point: Vector2=(Vector2(x,y)+Vector2.ONE*0.5)*FS.SIZE/Vector2(size)
   var wet: bool=FS.is_walkable(point,0.0) and FS.terrain_multiplier(point)==FS.WATER_SPEED
   image.set_pixel(x,y,Color.WHITE if wet else Color.BLACK)
 var result:=image.save_png("res://assets/maps/fenshui_v4/water-mask.png")
 print("正式地形水面显示遮罩：",size,"，保存结果",result)
 quit(0 if result==OK else 1)
