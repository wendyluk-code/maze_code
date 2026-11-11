extends "res://tools/tests/ch2_entry_state.gd"
## 显式隔离存档中的真实分水庭，不改正常启动入口或正式玩家进度。
const Run=preload("res://scripts/maze/capture_run.gd")
var maze: Node2D
var controls: Node

func _ready() -> void:
 # 启动配置已设不可聚焦；重复设置会触发当前Windows引擎重建样式并隐藏窗口。
 # 仅覆盖试玩初始化，保留共享测试基类及Godot内部输入准备。
 if ProjectSettings.get_setting_with_override("display/window/size/no_focus"):
  get_viewport().notify_mouse_entered()
 call_deferred("_run")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 if not _verify_isolation():
  push_error("巨蛙动作演示必须由独立存档运行器启动")
  get_tree().quit(1)
  return
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 Run.begin(sm,Roads.SPAWN)
 var run: Dictionary=Run.snapshot(sm)
 Run.ensure_region(run,"fenshui")
 run.combat.fs01_trial=false
 run.combat.cooldown=0.0
 run.combat.selected=0
 run.combat.hero=[880.0,490.0]
 for id in run.monsters: run.monsters[id].status="alive" if id=="fenshui_wind_frog_1" else "skipped"
 sm.data[Run.KEY]=run
 _check(sm.record_maze_location("fenshui",Vector2(880,490)).success,"保存巨蛙演示隔离站位")
 if failures:
  get_tree().quit(1)
  return
 maze=load("res://scenes/maze_fenshui.tscn").instantiate()
 get_tree().root.add_child(maze)
 get_tree().current_scene=maze
 await get_tree().process_frame
 await get_tree().process_frame
 controls=_make_controls()
 maze.add_child(controls)
 controls.attach(maze)
 controls.play()
 get_window().title=_window_title()
 var report_path: String=_arg("--frog-window-report=")
 if not report_path.is_empty():
  var window:=get_window()
  var screen: int=window.current_screen
  var report: Dictionary={"pid":OS.get_process_id(),"visible":window.visible,"mode":window.mode,"position":[window.position.x,window.position.y],"size":[window.size.x,window.size.y],"screen":screen,"screen_position":[DisplayServer.screen_get_position(screen).x,DisplayServer.screen_get_position(screen).y],"screen_size":[DisplayServer.screen_get_size(screen).x,DisplayServer.screen_get_size(screen).y],"unfocusable":window.unfocusable,"display_server":DisplayServer.get_name(),"title":window.title,"controls_active":controls.active}
  FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
  await get_tree().process_frame
  RenderingServer.force_draw(false)
  window.get_texture().get_image().save_png(report_path+".png")

func _make_controls() -> Node:
 return preload("res://tools/previews/fenshui_frog_motion_controls.gd").new()

func _window_title() -> String:
 return "料理迷宫 · 巨蛙第4版单朝向动作演示"
