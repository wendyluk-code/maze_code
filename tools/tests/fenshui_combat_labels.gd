extends "res://tools/tests/fenshui_frog_depth.gd"
## 正式场景原组件的实际可见矩形，不以修改过的常量代替显示验收。
func capture(label: String) -> Image:
 viewport.size=Vector2i(1280,720) if _arg("--phase=")=="wide" else Vector2i(1152,648)
 var result: Image=await super.capture(label)
 if label.ends_with("_actual"):
  var hero: Control=maze.capture_flow.power_label
  var frog: Control=maze.capture_flow.monsters[Boss.ID].label
  var visible: bool=hero.is_visible_in_tree() and frog.is_visible_in_tree()
  _check(visible,"本次双方血条实际可见："+label)
  var hero_rect:=screen_rect(hero)
  var frog_rect:=screen_rect(frog)
  _check(visible and not hero_rect.grow(2.0).intersects(frog_rect.grow(2.0)),"主角与目标的血条文字不重叠："+label,{"hero":str(hero_rect),"frog":str(frog_rect)})
 return result

func walk_in_battle(frog: Node2D) -> void:
 await super.walk_in_battle(frog)
 await tap_map()
 _check(maze.map_ui.expanded,"血条检查通过原地图输入暂停")
 var paused: Vector2=frog.label.position
 await get_tree().create_timer(0.12).timeout
 _check(frog.label.position==paused,"暂停时标签不漂移")
 for pressed in [true,false]:
  var key:=InputEventKey.new()
  key.keycode=KEY_ESCAPE
  key.physical_keycode=KEY_ESCAPE
  key.pressed=pressed
  viewport.push_input(key)
  await get_tree().process_frame
 _check(not maze.map_ui.expanded and not maze.player.input_locked,"关闭地图后血条检查恢复原输入")
 maze.process_mode=Node.PROCESS_MODE_DISABLED
 var run:=fresh_frog()
 frog.position=Boss.HOME
 maze.player.position=Boss.HOME+Vector2(120,80)
 frog.label.show()
 frog.sync_action(run.combat.actors[Boss.ID],run.combat)
 await capture("separated_before")
 var initial: Vector2=frog.label.position
 var scale: Vector2=frog.body.scale
 maze.player.position=Boss.HOME+Vector2(0,12)
 frog.sync_action(run.combat.actors[Boss.ID],run.combat)
 await capture("near_again_actual")
 maze.player.position=Boss.HOME+Vector2(120,80)
 frog.sync_action(run.combat.actors[Boss.ID],run.combat)
 await capture("separated_after")
 _check(frog.label.position==initial,"远离后回到原头顶位置，不积累避让偏移")
 _check(frog.body.scale==scale and frog.label.position.x==initial.x,"避让不改变身体体型或标签横向居中")

func tap_map() -> void:
 var point: Vector2=maze.map_ui.mini_button.get_global_rect().get_center()
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.position=point
  event.pressed=pressed
  viewport.push_input(event)
  await get_tree().process_frame

func screen_rect(control: Control) -> Rect2:
 var transform:=control.get_global_transform_with_canvas()
 var result:=Rect2(transform*Vector2.ZERO,Vector2.ZERO)
 for point in [Vector2(control.size.x,0),control.size,Vector2(0,control.size.y)]: result=result.expand(transform*point)
 return result
