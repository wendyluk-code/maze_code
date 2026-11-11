extends "res://tools/tests/tutorial_cutout_pointer.gd"
## 原回归点击后立即检查输入；本专项等待已有镜头回收完成，再用原断言验收。
func _click_at(point: Vector2) -> void:
	await super._click_at(point)
	if is_instance_valid(scene) and tm.active and not tm._order_explanation_pending:
		await _wait_until(func(): return not scene.get_node("Player").input_locked, 180)

func _cleanup() -> void:
	await super._cleanup()
	# 实景回归的最后一次E会播放点击音，退出前正常停止并释放播放实例。
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null:
		for child in audio.get_children():
			if child is AudioStreamPlayer: child.stop()
		await get_tree().create_timer(0.2).timeout
