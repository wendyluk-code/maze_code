extends "res://scripts/ui/components/loot_modal.gd"
## 复用宝箱获得物品弹窗；只负责展示，不执行发奖。
func present() -> void:
	var items: Array[Dictionary] = []
	var config := preload("res://data/maze/elder_firewood.gd")
	for item in config.REWARD_ITEMS:
		items.append({"name": item.name, "quantity": item.quantity, "icon": config.reward_texture(item)})
	show_items(items)
