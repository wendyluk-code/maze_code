extends "res://tools/tests/ch2_entry_state.gd"
## 仅准备隔离体验档，随后交给正常地图；不安装动作演示或修改魔物列表。
const Run=preload("res://scripts/maze/capture_run.gd")
const Confirmation=preload("res://scripts/ui/components/destination_confirmation.gd")
var maze: Node2D
var gate: Control

func _ready() -> void:
 # 沿用启动时不可聚焦配置，不重复设窗体标记导致Windows隐藏窗口。
 if ProjectSettings.get_setting_with_override("display/window/size/no_focus"):
  get_viewport().notify_mouse_entered()
 call_deferred("_run")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 if not _verify_isolation():
  push_error("正式分水庭体验必须使用隔离存档启动器")
  get_tree().quit(1)
  return
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"隔离体验建立真实探索")
 _check(Run.change_region(sm,"fenshui",Vector2(880,490)).success,"隔离体验直接进入正常分水庭")
 if failures:
  get_tree().quit(1)
  return
 maze=load("res://scenes/maze_fenshui.tscn").instantiate()
 get_parent().add_child(maze)
 if get_parent()==get_tree().root: get_tree().current_scene=maze
 for i in 240:
  if maze._entry_ready: break
  await get_tree().process_frame
 if not _prepare_frog():
  push_error("指定巨蛙完整动作未就绪，不能用缺帧方向进入候选战斗")
  get_tree().quit(1)
  return
 maze.player.input_locked=true
 var layer:=CanvasLayer.new()
 layer.layer=100
 maze.add_child(layer)
 gate=Confirmation.new()
 layer.add_child(gate)
 gate.open_confirmation(_play_message(), "开始体验", "关闭体验")
 gate.confirmed.connect(_start_play)
 gate.cancelled.connect(func(): get_tree().quit())
 get_window().title=_play_title()
 await get_tree().create_timer(0.4).timeout
 var report_path:=_arg("--frog-window-report=")
 if not report_path.is_empty():
  FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"ready":maze._entry_ready,"monsters":maze.capture_flow.monsters.size(),"formal_combat":true,"single_direction":maze.capture_flow.monsters["fenshui_wind_frog_1"].frog_motion_direction>=0,"motion_direction":maze.capture_flow.monsters["fenshui_wind_frog_1"].frog_motion_direction,"unfocusable":get_window().unfocusable,"user_dir":OS.get_user_data_dir(),"title":get_window().title},"  "))
  RenderingServer.force_draw(false)
  get_viewport().get_texture().get_image().save_png(report_path+".png")

func _prepare_frog() -> bool:
 return true

func _play_message() -> String:
 return "分水庭四向整合候选 · 独立体验档\n腾空时命中巨蛙，打断后露腹3秒、伤害2倍。\n四向起落、反击、吐水及同向捕获已接线；鱼鳗正常活动。\n待机、吐水和击败暂复用原图，新旧接缝待审。"

func _play_title() -> String:
 return "料理迷宫 · 分水庭四向整合候选（起落·反击·吐水·捕获）"

func _start_play() -> void:
 gate.hide()
 maze.player.input_locked=false
 # 自动验收始终不可聚焦；只有真人点击本入口后允许其手动聚焦。
 if "--fs01-check" not in OS.get_cmdline_user_args():
  var window:=get_window()
  window.unfocusable=false
  # 主窗口禁止隐藏；用户主动开始后只确保显示，不改变焦点。
  window.show()
