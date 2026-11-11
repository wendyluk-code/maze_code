extends "res://tools/tests/home_character_details.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离存档")
	_seed()
	var ids := ["yaya","tieshan","dingdang","yufeng","salia","jiaopopo","ahong","xiluomei","chengyan","lanjiao"]
	var expected := [2,3,1,4,3,5,2,4,1,2]
	# 由目录名称匹配新增角色，避免把展示顺序当作内部ID。
	var names := ["芽芽","铁山","叮当","御风","萨莉亚","椒婆婆","阿轰","汐罗美","澄砚","岚角"]
	for i in names.size():
		for id in Progression.CHARACTERS:
			if Progression.CHARACTERS[id].name==names[i]: ids[i]=id
	sm.data[preload("res://scripts/characters/recruitment.gd").OWNED_KEY] = ids
	var modal := preload("res://scripts/ui/components/character_details_modal.gd").new()
	add_child(modal)
	await get_tree().process_frame
	for i in ids.size():
		var id: String = ids[i]
		_check(Progression.satiety_limit(id,1)==expected[i],"初始饱腹"+names[i])
		var previous: int = expected[i]
		for level in range(1,31):
			_put(id,level,1)
			var record := Progression.record(sm,id)
			_check(record.valid and record.satiety_max>=previous and record.satiety_max<=10 and (level%5==0 or record.satiety_max==previous),"等级边界%s/%d" % [id,level])
			previous = record.satiety_max
		_check(previous==10,"30级统一10"+names[i])
		modal.present(id)
		_check(modal.attribute_values[2].text.ends_with(" / 10"),"详情显示30级上限"+names[i])
		modal.hide()
	_put("yaya",5,1)
	sm.data[Progression.FOOD_KEY] = {"values":{"yaya":2.0},"at":1000.0,"paused":true}
	_check(Progression.satiety_snapshot(sm,1000).values.yaya==2.0,"上限提高不补满余额")
	_check(sm.save(),"保存成长状态")
	sm.load_data()
	_check(Progression.record(sm,"yaya").satiety_max==3 and Progression.satiety_snapshot(sm,1000).values.yaya==2.0,"读档上限和余额一致")
	modal.present("yaya")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_arg("--output-dir=").path_join("yaya_level5.png"))
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
