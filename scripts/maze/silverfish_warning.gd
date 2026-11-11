extends Node2D
## 正式鱼的短水纹蓄势；仅提示锁定朝向，不表达完整攻击范围。
const Fish=preload("res://scripts/maze/silverfish_combat.gd")
const Rush=preload("res://scripts/maze/fenshui_borrow_lightning.gd")
var flow: Node
var warnings: Dictionary={}

func _ready() -> void:
 var texture: Texture2D=load("res://assets/effects/fenshui/silverfish_warning_v4.png")
 for id in flow.monsters:
  if not id.begins_with("fenshui_silverfish_"): continue
  var sprite:=Sprite2D.new()
  sprite.name=id
  sprite.texture=texture
  sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
  sprite.scale=Vector2.ONE*float(flow.monsters[id].config.width)*1.4/texture.get_width()
  sprite.hide()
  add_child(sprite)
  warnings[id]=sprite

func _process(_delta: float) -> void:
 for sprite in warnings.values(): sprite.hide()
 var run: Dictionary=flow.display_run()
 if run.is_empty() or not run.get("active",false): return
 var c: Dictionary=run.combat
 for id in c.actors:
  if not warnings.has(id) or not Fish.enabled(c,id) or run.monsters[id].status!="alive": continue
  var a: Dictionary=c.actors[id]
  if a.hp<=0 or a.get("fish_phase","")!="warning": continue
  var sprite: Sprite2D=warnings[id]
  var aim:=Fish.vec(a.fish_aim)
  var duration:=preload("res://scripts/maze/silverfish_editor.gd").seconds("windup")
  var elapsed:=clampf(duration-float(a.fish_left),0.0,duration)
  var wave:=elapsed*TAU*2.0
  var drift:=1.0-cos(wave)
  var width: float=flow.monsters[id].config.width
  sprite.position=Fish.vec(a.position)+Vector2(0,-width*0.15)+aim*(width*0.5+drift)
  sprite.rotation=aim.angle()
  # 仅按已提交阶段时间做轻微平移和明暗；暂停冻结，冲刺首帧即隐藏。
  sprite.modulate.a=clampf(elapsed/0.1,0.0,1.0)*(0.85+0.05*sin(wave))
  sprite.show()

