extends "res://tools/tests/home_owned_cards_input.gd"
## 沿用真实角色簿流程；旧占位提示已由正式召唤面板取代。
func _check(ok: bool, label: String, detail: Dictionary = {}) -> void:
	if label == "召唤页签切换与未开放状态":
		var page = get_tree().get_first_node_in_group("adventurer_home")
		ok = page.selected_tab == 1 and page.summon_panel.visible and not page.collection_scroll.visible
		label = "召唤页签展示当前召唤面板并隐藏角色簿"
	super._check(ok, label, detail)
