extends Node2D
## 用户已认可五栏：原挂点、统一缩放；不拥有封路判定。
const Gates=preload("res://data/maze/fenshui_gates.gd")
const ANCHORS=[
 [Vector2(182,461),Vector2(347,304)],
 [Vector2(106,327),Vector2(403,414)],
 [Vector2(144,267),Vector2(343,455)],
 [Vector2(97,347),Vector2(426,347)],
 [Vector2(330,1060),Vector2(917,715)],
]

func _ready() -> void:
 for i in Gates.GATES.size():
  var gate: Dictionary=Gates.GATES[i]
  var left: Vector2=ANCHORS[i][0]
  var right: Vector2=ANCHORS[i][1]
  var sprite:=Sprite2D.new()
  sprite.name="Fence"+str(i+1)
  sprite.texture=load("res://assets/maps/fenshui_v4/fence-"+str(i+1)+".png")
  sprite.centered=false
  sprite.offset=-(left+right)*0.5
  sprite.scale=Vector2.ONE*gate.a.distance_to(gate.b)/left.distance_to(right)
  sprite.position=Gates.center(gate)
  sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
  add_child(sprite)
