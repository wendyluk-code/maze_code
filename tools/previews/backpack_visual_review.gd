extends "res://tools/tests/maze_capture.gd"
const Warehouse := preload("res://scripts/ui/warehouse_modal.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
func _run() -> void:
 sm = get_node("/root/SaveManager")
 tm = get_node("/root/TutorialManager")
 _check(_verify_isolation(),"预览隔离存档")
 _completed()
 sm.cancel_maze_entry()
 DisplayServer.window_set_size(Vector2i(1152,648))
 maze = load("res://scenes/maze_entry.tscn").instantiate()
 get_tree().root.add_child(maze)
 get_tree().current_scene = maze
 await get_tree().process_frame
 maze.capture_flow.set_process(false)
 maze.capture_flow.hud.hide()
 maze.player.position = Vector2(688,396)
 maze.player.set_physics_process(false)
 maze.camera.snap_to_target()
 maze.toast_label.dismiss()
 suffix = ""
 for empty in [false,true]:
  var modal := Warehouse.new()
  maze._ui_root.add_child(modal)
  var items := {}
  if not empty:
   for entry in [["slime_shell",2],["slime_gel",3],["brick_snail_meat",2],["sword_beetle_leg",1],["petrifying_lizard_tail",1]]:
    items[entry[0]] = entry[1]
  modal.open_backpack(items, true)
  modal._heading.text = "背包"
  var height := 300.0 if empty else 480.0
  modal._panel.custom_minimum_size = Vector2(620,height)
  modal._panel.size = Vector2(620,height)
  modal._panel.position = Vector2((1152.0-620.0)/2.0,(648.0-height)/2.0)
  await get_tree().create_timer(0.3).timeout
  await _capture_image("empty" if empty else "filled")
  _check(modal._panel.get_global_rect().end.y<648,"面板完整显示")
  modal.queue_free()
  await get_tree().process_frame
 var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit()
