extends "res://tools/tests/ch2_entry_state.gd"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"详情检查使用隔离存档")
 _completed()
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 get_tree().root.add_child(viewport)
 var dialog=preload("res://scripts/ui/components/character_details_modal.gd").new()
 viewport.add_child(dialog)
 dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 await get_tree().process_frame
 dialog.present("yaya")
 await get_tree().process_frame
 var source: String=preload("res://scripts/characters/character_progression.gd").skill_icon_path("yaya")
 var expected: Texture2D=preload("res://scripts/ui/components/bag_icon_display.gd").texture(load(source))
 _check(source=="res://assets/ui/ingredients/insulating_leaf.png","芽芽使用已确认双叶图标")
 _check(dialog.active_icon.texture==expected and dialog.active_icon.is_visible_in_tree(),"真实角色详情显示同一图标")
 _check(dialog.active_description.text.contains("3枚飞叶"),"详情描述当前三连发")
 _check(dialog.active_interval.text=="0.45 秒","详情显示实际一轮间隔")
 _check(dialog.active_damage.text.contains("25%") and dialog.active_damage.text.contains("取整"),"详情显示单枚倍率及取整")
 RenderingServer.force_draw(false)
 viewport.get_texture().get_image().save_png(_arg("--output-dir=").path_join("yaya-details.png"))
 var tuning=preload("res://scripts/maze/combat_tuning.gd")
 tuning.values["effect.yaya"]={"burst_count":5,"burst_interval":0.2,"burst_damage_scale":50,"burst_cooldown":1.2,"interval_scale":100,"damage_scale":100}
 dialog.refresh()
 _check(dialog.active_description.text.contains("5枚飞叶"),"自定义颗数更新详情")
 _check(dialog.active_interval.text=="1.2 秒","自定义间隔更新详情")
 _check(dialog.active_damage.text.contains("50%"),"自定义单枚倍率更新详情")
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 print("YAYA_DETAILS ",checks," checks, ",failures," failures")
 get_tree().quit(1 if failures else 0)
