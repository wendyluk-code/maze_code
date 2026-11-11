extends Node
## 只在独立入口内覆盖真实巨蛙显示，退出演示恢复原战斗，不写新玩法状态。
const Frames=preload("res://tools/previews/fenshui_frog_frames.gd")
const Frog=preload("res://data/maze/fenshui_boss.gd")
const Run=preload("res://scripts/maze/capture_run.gd")
var maze: Node2D
var frog: Node2D
var motion: RefCounted
var active:=false
var playing:=false
var pose:=0
var sequence_position:=0
var remaining:=0.0
var saved: Dictionary={}
var hint: Label
var play_button: Button
var pause_button: Button
var step_button: Button
var resume_button: Button
var tool_layer: CanvasLayer

func attach(target: Node2D) -> void:
 maze=target
 frog=maze.capture_flow.monsters[Frog.ID]
 motion=Frames.new()
 # 以现有巨蛙落地第0朝向的148像素主体宽为基准，整套统一比例。
 motion.load_frames(148.0/192.0*float(frog.config.width))
 var layer:=CanvasLayer.new()
 tool_layer=layer
 layer.layer=100
 add_child(layer)
 hint=preload("res://scripts/ui/components/feedback_toast.gd").new()
 hint.position=Vector2(24,76)
 hint.add_theme_font_size_override("font_size",15)
 layer.add_child(hint)
 hint.set_process(false)
 var buttons: Array=[]
 for text in ["F7 重播","F8 暂停／继续","F10 下一姿态","F9 原战斗"]:
  var button: Button=SproutButton.new().set_icon_visible(false).set_focus_visual(false)
  button.text=text
  button.position=Vector2(24+(buttons.size()%2)*188,167+(buttons.size()/2)*48)
  button.size=Vector2(180,42)
  button.custom_minimum_size=button.size
  button.add_theme_font_size_override("font_size",15)
  button.focus_mode=Control.FOCUS_NONE
  layer.add_child(button)
  buttons.append(button)
 play_button=buttons[0]
 pause_button=buttons[1]
 step_button=buttons[2]
 resume_button=buttons[3]
 play_button.pressed.connect(play)
 pause_button.pressed.connect(toggle_pause)
 step_button.pressed.connect(step)
 resume_button.pressed.connect(resume_combat)
 _refresh_hint()

func play() -> void:
 if maze.map_ui.expanded or maze.capture_flow.busy or maze._busy: return
 if Run.snapshot(SaveManager).monsters[Frog.ID].status!="alive": return
 if not active:
  var body: Sprite2D=frog.body
  saved={"flow":maze.capture_flow.is_processing(),"input":maze.capture_flow.is_processing_input(),"locked":maze.player.input_locked,"texture":body.texture,"region_enabled":body.region_enabled,"region_rect":body.region_rect,"offset":body.offset,"transform":body.transform,"centered":body.centered,"flip_h":body.flip_h,"flip_v":body.flip_v,"monsters":{}}
  for node in maze.capture_flow.monsters.values():
   saved.monsters[node]=node.is_processing()
   node.set_process(false)
  maze.capture_flow.set_process(false)
  maze.capture_flow.set_process_input(false)
  maze.player.input_locked=true
 active=true
 playing=true
 pose=0
 sequence_position=0
 remaining=motion.duration(pose)
 motion.draw_pose(frog.body,pose)
 _refresh_hint()

func toggle_pause() -> void:
 if not active: play()
 else: playing=not playing
 _refresh_hint()

func step() -> void:
 if not active: play()
 if not active: return
 playing=false
 pose=(pose+1)%18
 sequence_position=Frames.SEQUENCE.find(pose)
 remaining=motion.duration(pose)
 motion.draw_pose(frog.body,pose)
 _refresh_hint()

func resume_combat() -> void:
 if not active: return
 var body: Sprite2D=frog.body
 body.texture=saved.texture
 body.region_enabled=saved.region_enabled
 body.region_rect=saved.region_rect
 body.offset=saved.offset
 body.transform=saved.transform
 body.centered=saved.centered
 body.flip_h=saved.flip_h
 body.flip_v=saved.flip_v
 for node in saved.monsters: node.set_process(saved.monsters[node])
 maze.player.input_locked=saved.locked
 maze.capture_flow.set_process(saved.flow)
 maze.capture_flow.set_process_input(saved.input)
 if "--frog-motion-passive" in OS.get_cmdline_user_args():
  maze.get_window().unfocusable=false
 active=false
 playing=false
 saved={}
 _refresh_hint()

func _process(delta: float) -> void:
 tool_layer.visible=not maze.map_ui.expanded and not maze.capture_flow.busy and not maze._busy
 if not active or not playing or maze.map_ui.expanded: return
 if not maze.capture_flow.window_focused and "--frog-motion-passive" not in OS.get_cmdline_user_args(): return
 remaining-=delta
 while remaining<=0.0:
  sequence_position=(sequence_position+1)%Frames.SEQUENCE.size()
  pose=Frames.SEQUENCE[sequence_position]
  remaining+=motion.duration(pose)
 motion.draw_pose(frog.body,pose)
 _refresh_hint()

func _input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo or maze.map_ui.expanded or maze.capture_flow.busy or maze._busy: return
 match event.keycode:
  KEY_F7: play()
  KEY_F8: toggle_pause()
  KEY_F10: step()
  KEY_F9: resume_combat()
  _: return
 get_viewport().set_input_as_handled()

func _refresh_hint() -> void:
 hint.show()
 if active:
  hint.text="巨蛙第4版 · 仅右前单朝向 · 非正式反击玩法\n"+("循环演示" if playing else "暂停观察")+" · %d／18 · %s\n演示时战斗暂停；F9恢复原战斗。露腹不增伤。" % [pose+1,Frames.NAMES[pose]]
 else:
  hint.text="巨蛙第4版 · 仅右前单朝向\n当前为正式战斗：腾空命中可反击，露腹3秒伤害2倍。F7进入动作演示。"
