extends "res://tools/previews/fenshui_frog_motion_controls.gd"
## 复用原动作核对控件，静态选择四关键姿态，绝不自动拉长为连续动画。
var direction:=1
var key_index:=0
var available:=false
var original_membrane_transform: Transform2D
var original_membrane_visible:=false
var original_label_position: Vector2

func attach(target: Node2D) -> void:
 super.attach(target)
 play_button.text="F7 下一朝向"
 pause_button.text="F8 下一关键姿态"
 step_button.text="F10 回到蹲姿"
 resume_button.text="F9 原单向战斗"

func play() -> void:
 if not active:
  original_membrane_transform=frog.membrane.transform
  original_membrane_visible=frog.membrane.visible
  original_label_position=frog.label.position
  super.play()
  if not active: return
  var run: Dictionary=Run.snapshot(SaveManager)
  frog.sync_action(run.combat.actors[Frog.ID],run.combat)
  direction=1
 else: direction=(direction+1)%4
 playing=false
 key_index=0
 _draw_key()

func toggle_pause() -> void:
 if not active:
  play()
  return
 key_index=(key_index+1)%4
 _draw_key()

func step() -> void:
 if not active: play()
 if not active: return
 key_index=0
 _draw_key()

func _draw_key() -> void:
 pose=Frames.KEY_FRAMES[key_index]
 available=frog.preview_frog_direction_key(direction,pose)
 _refresh_hint()

func resume_combat() -> void:
 if not active: return
 super.resume_combat()
 frog.membrane.transform=original_membrane_transform
 frog.membrane.visible=original_membrane_visible
 frog.label.position=original_label_position

func _refresh_hint() -> void:
 if hint==null: return
 hint.show()
 if active:
  hint.text="巨蛙 · 关键姿态核对 · 非完整连续动画\n%s · %s · %s\n三向仍缺过渡；F9返回原右前单向战斗。" % [["右前","左前","右后","左后"][direction],Frames.NAMES[Frames.KEY_FRAMES[key_index]],"已提供" if available else "未提供"]
 else:
  hint.text="当前为原右前单向正式战斗，新三向连续动画尚缺帧。\nF7进入关键姿态核对；仅查看已交付图，不推进战斗。"
