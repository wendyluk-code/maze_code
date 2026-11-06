extends "res://tools/previews/fenshui_borrow_lightning.gd"
## 启动器先复制用户卡住档到隔离目录，真实load_data后检查恢复与再次重启。
func _scene_check(_effects: Node) -> void:
 _check(get_window().unfocusable and not get_window().has_focus(),"旧档重启测试不获取桌面焦点")
 var before: Dictionary=Run.snapshot(sm)
 var id: String=Rules.IDS[1]
 var fish_hp: float=before.combat.actors[id].hp
 var bag: Dictionary=before.bag.duplicate(true)
 var satiety: float=before.satiety
 _check(Run.valid(before),"真实load_data后的旧停顿档已合法")
 _check(before.combat.actors[id].has("fs_aim") and before.combat.actors[id].has("fs_origin") and before.combat.actors[id].has("fs_hit"),"旧停顿阶段补齐字段")
 var elapsed: float=before.combat.elapsed
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(true)
 # 只驱动Godot内部方向动作，保持原档位置和数值。
 Input.action_press("ui_left")
 await get_tree().create_timer(0.2).timeout
 Input.action_release("ui_left")
 await get_tree().create_timer(0.9).timeout
 maze.capture_flow.set_process(false)
 var after: Dictionary=Run.snapshot(sm)
 _check(Run.valid(after) and after.combat.elapsed>elapsed+0.5,"真实重启后战斗继续推进")
 _check(after.combat.actors[id].hp==fish_hp,"恢复已放电状态不重复电伤鱼")
 _check(after.bag==bag and after.satiety==satiety,"重启不发奖励不重复扣费")
 _check(sm.save(),"兼容字段随原事务保存，允许再次重启")
 _report_and_quit()
