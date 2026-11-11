extends "res://tools/tests/yufeng_sitting_flow.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		_completed()
		var view=preload("res://scripts/ui/components/recruit_results.gd").new()
		add_child(view)
		for target in [3,6]:
			view.present([{"id":"yufeng","rank":target,"kind":"upgrade","stardust":0}])
			var ranks: Array=[]
			var deadline:=Time.get_ticks_msec()+8000
			while view.stage!="ready" and Time.get_ticks_msec()<deadline:
				if view.displayed_rank not in ranks:
					ranks.append(view.displayed_rank)
					if view.displayed_rank>1:
						_check(view.next_button.disabled,"逐星期间不能提前切卡")
						await get_tree().create_timer(0.13).timeout
						var star: TextureRect=view.current_face.stars[view.displayed_rank-1]
						_check(star.modulate.a>0 and star.modulate.a<1,"新星渐亮中间帧")
						await _capture_image("rank_%d_step_%d" % [target,view.displayed_rank])
				await get_tree().process_frame
			_check(ranks==range(1,target+1),"从第2颗起依次升至%d星" % target)
			_check(view.stage=="ready" and not view.next_button.disabled,"结束后恢复确认")
			_check(view.outcome_line.text=="升至%d星" % target,"最终星级文案")
		view.present([{"id":"yufeng","rank":6,"kind":"upgrade","stardust":0},{"id":"salia","rank":3,"kind":"upgrade","stardust":0}])
		await get_tree().create_timer(1.5).timeout
		await _send_key(KEY_ESCAPE)
		_check(view.overview,"逐星中可跳过到总览")
		await get_tree().create_timer(2.0).timeout
		_check(view.overview and view.current_face==null,"跳过后旧补间不继续操作卡片")
		view.queue_free()
		await get_tree().create_timer(2.0).timeout
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
