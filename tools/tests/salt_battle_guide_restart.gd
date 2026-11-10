extends "res://tools/tests/fenshui_frog_counter_flow.gd"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"跨进程检查使用隔离存档")
 sm._active_save_path="user://chapter-ending-test.json"
 _check(FileAccess.file_exists(sm._active_save_path),"上一次检查已生成独立存档")
 sm.load_data()
 _check(sm.last_load_error.is_empty() and sm.data.get("salt_battle_guide_seen",false)==true,"新进程读取已完成记录")
 viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 get_tree().root.add_child(viewport)
 maze=load("res://scenes/maze_salt_pool.tscn").instantiate()
 viewport.add_child(maze)
 await get_tree().process_frame
 await get_tree().process_frame
 maze.capture_flow.window_focused=true
 var guide: Node=maze.get_node_or_null("SaltBattleGuide")
 _check(is_instance_valid(guide) and guide.completed and not guide.dialog.visible,"新进程重进盐池不重复")
 _finish()
