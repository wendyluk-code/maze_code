extends Node
var sm: Node
var checks:=0
var failures:=0
func _ready(): call_deferred("_run")
func _check(ok:bool,name:String): checks+=1; if not ok: failures+=1; print("YF_STATE ",name," ",ok)
func _run():
 sm=get_node("/root/SaveManager")
 sm.data=sm._defaults(); sm._active_save_path="user://yf-state.json"
 _check(sm.yufeng_salia_state()=="unseen","旧档默认unseen")
 _check(sm.set_yufeng_salia_state("intro_pending").success,"intro_pending保存")
 sm.load_data(); _check(sm.yufeng_salia_state()=="intro_pending","磁盘恢复intro_pending")
 _check(sm.set_yufeng_salia_state("awaiting_battle").success,"awaiting保存")
 sm.load_data(); _check(sm.yufeng_salia_state()=="awaiting_battle","磁盘恢复awaiting")
 var before=sm.data.duplicate(true)
 var bytes=FileAccess.get_file_as_bytes(sm._active_save_path)
 sm._active_save_path=""
 _check(not sm.set_yufeng_salia_state("unseen").success and sm.data==before,"无路径保存失败完整回滚")
 sm._active_save_path="user://yf-state.json"
 DirAccess.make_dir_absolute(ProjectSettings.globalize_path(sm._active_save_path+".tmp"))
 _check(not sm.set_yufeng_salia_state("unseen").success and sm.data==before and FileAccess.get_file_as_bytes(sm._active_save_path)==bytes,"真实tmp目录失败内存磁盘回滚")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(sm._active_save_path+".tmp"))
 sm.data.yufeng_salia_encounter="bad"; _check(sm.yufeng_salia_state()=="unseen","坏字段诊断回退")
 var f=FileAccess.open("user://yf-state-report.json",FileAccess.WRITE); f.store_string(JSON.stringify({"checks":checks,"failures":failures,"user_dir":OS.get_user_data_dir()})); f.close(); get_tree().quit(1 if failures else 0)
