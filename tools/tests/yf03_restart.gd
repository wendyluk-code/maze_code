extends "res://tools/tests/maze_capture.gd"
const Bento=preload("res://scripts/restaurant/bento_store.gd")
const STAGES := ["gift_pending","gift_reward","bento_unlock","bento_fly","farewell","fade","done","healing"]

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"跨进程正式存档隔离")
	var mode := OS.get_environment("YF03_RESTART")
	if failures==0:
		if mode=="seed":
			_completed()
			sm.cancel_maze_entry()
			sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
			_check(Run.begin(sm,Roads.SPAWN).success,"建立真实出征")
			sm.record_maze_location("fenshui",Vector2(1300,325))
			var base: Dictionary=sm.data.duplicate(true)
			for stage in STAGES:
				sm.data=base.duplicate(true)
				sm._active_save_path="user://yf03_"+stage+".json"
				sm.set_yufeng_salia_record({"version":2,"phase":"gift_pending","line":0})
				if stage!="gift_pending":
					_check(Bento.grant(sm).success,"真实赠礼事务："+stage)
				if stage in ["bento_fly","farewell","fade","done","healing"]:
					sm.set_yufeng_salia_record({"version":2,"phase":"bento_unlock","line":0})
					_check(Bento.reveal(sm).success,"解锁凭证："+stage)
				_check(sm.set_yufeng_salia_record({"version":2,"phase":"done" if stage=="healing" else stage,"line":1 if stage=="farewell" else 0}).success,"写入演出阶段："+stage)
				if stage=="healing":
					sm.data[Run.KEY].combat.hp=1.0
					_check(Bento.eat(sm).success,"跨进程真实全部食用")
					for i in 24: Run.combat_tick(sm,Vector2(1300,325),0.1)
					sm.data["yf03_expect"]={"hp":Run.snapshot(sm).combat.hp,"bento":Run.snapshot(sm).bento.duplicate(true)}
				_check(sm.save(),"独立文件提交："+stage)
		else:
			for stage in STAGES:
				sm._active_save_path="user://yf03_"+stage+".json"
				sm.load_data()
				_check(sm.yufeng_salia_state()==("done" if stage=="healing" else stage),"新进程读取阶段："+stage)
				var initial: Dictionary=Bento.snapshot(sm)
				if stage=="healing":
					_check(_same_saved(Run.snapshot(sm).bento,sm.data.yf03_expect.bento) and absf(Run.snapshot(sm).combat.hp-sm.data.yf03_expect.hp)<0.000001,"离线时间不恢复，累计量与剩余时间不丢")
				maze=load("res://scenes/maze_fenshui.tscn").instantiate()
				get_tree().root.add_child(maze)
				get_tree().current_scene=maze
				await get_tree().process_frame
				maze.capture_flow.window_focused=true
				await get_tree().create_timer(0.15).timeout
				var event=maze.yf_encounter
				_check(not event._gift_invalid,"恢复凭证有效："+stage)
				if stage in ["gift_pending","gift_reward"]:
					_check(event.phase=="gift_reward" and event.gift_modal.visible,"恢复真实奖励展示："+stage)
					_check(Bento.snapshot(sm).slots.size()==3 and not Bento.unlocked(sm),"恢复不重复三份且未提前解锁")
				if stage=="bento_unlock":
					_check(event.unlock_modal.visible and Bento.unlocked(sm),"恢复解锁蒙层")
					_check(not maze.bento_entry.is_visible_in_tree() and not maze.bento_entry.get_node("BentoShadow").is_visible_in_tree(),"重进解锁蒙层仍隐藏入口及投影")
				if stage=="bento_fly":
					_check(event.phase=="bento_fly" and maze.player.input_locked,"恢复飞入锁")
					await get_tree().create_timer(0.6).timeout
					_check(event.phase=="farewell","恢复飞入完成后对白")
				if stage=="farewell": _check(event.record.line==1 and event.dialog.visible,"恢复第二句，不重放第一句")
				if stage=="fade":
					_check(event.phase=="fade" and maze.player.input_locked,"淡出恢复不提前done")
					await get_tree().create_timer(0.8).timeout
					_check(event.phase=="done" and not maze.player.input_locked,"淡出完成释放输入锁")
				if stage in ["done","healing"]: _check(not event.idle.visible and not maze.player.input_locked,"done永久不触发")
				if stage!="gift_pending": _check(Bento.snapshot(sm).slots==initial.slots,"跨进程不重复奖励或食用")
				maze.queue_free()
				await get_tree().process_frame
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
