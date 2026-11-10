extends SceneTree
## 只在无系统窗口模式核对真人开始分支，绝不改变桌面焦点。
var checks:=0
var failures:=0
func _initialize() -> void:
 call_deferred("_run")

func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  push_error(label)

func _run() -> void:
 if DisplayServer.get_name()!="headless" or "--fs01-check" in OS.get_cmdline_user_args():
  push_error("真人入口分支检查必须无系统窗口且不带自动入口跳过标记")
  quit(1)
  return
 var bootstrap: Node=load("res://tools/previews/fenshui_frog_play.tscn").instantiate()
 root.add_child(bootstrap)
 var deadline:=Time.get_ticks_msec()+10000
 while bootstrap.get("gate")==null and Time.get_ticks_msec()<deadline: await process_frame
 check(bootstrap.gate!=null,"真实入口应准备好")
 if bootstrap.gate!=null:
  # 无系统窗口模式不能证明原生不可聚焦样式，样式另由真实窗口取证。
  check(bootstrap.gate.visible,"真人入口仍先等待确认")
  check(bootstrap.maze.capture_flow.monsters.size()==7,"仍是真实七怪场景")
  bootstrap.gate.confirmed.emit()
  check(not bootstrap.gate.visible and not bootstrap.maze.player.input_locked,"确认开始后释放遮罩和输入锁")
  check(not root.unfocusable,"真人分支允许后续手动聚焦；本检查没有系统窗口")
  check(root.visible,"开始后主窗口保持可见，不调用禁止的隐藏操作")
 var report:={"checks":checks,"failures":failures,"human_entry_branch":true,"headless":true}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="): FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 quit(1 if failures else 0)
