extends RefCounted
## 原图目录与已确认首批拥有记录分开：增加素材不会自动获得卡牌。
const COLLECTION_KEY := "owned_character_cards_v1"

static func initial_counts(party: Array) -> Dictionary:
	var counts := {}
	if party.has("yaya"):
		counts = {"yaya/yaya": 1, "yaya/small_spoon_person": 1, "yaya/warm_care": 2,
			"yaya/field_kitchen": 1, "yaya/hotpot_collab": 1}
	if party.has("tieshan"): counts["tieshan/tieshan"] = 1
	return counts

static func valid_counts(value) -> bool:
	if not value is Dictionary: return false
	for key in value:
		var quantity = value[key]
		if not key is String or typeof(quantity) not in [TYPE_INT, TYPE_FLOAT]: return false
		if not is_finite(float(quantity)) or quantity < 0 or quantity > 9007199254740991 or quantity != floor(float(quantity)): return false
	return true

static func owned_for_character(id: String, counts: Dictionary, party: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not party.has(id) or not valid_counts(counts): return result
	for item in for_character(id):
		var quantity := int(counts.get(item.id, 0))
		if quantity <= 0: continue
		item["quantity"] = quantity
		result.append(item)
	return result

static func for_character(id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if id == "yaya":
		for name in ["yaya", "small_spoon_person", "warm_care", "field_kitchen", "hotpot_collab"]:
			result.append({"id": "yaya/" + name, "path": "res://assets/ui/battle/cards/yaya/%s.png" % name, "role": name == "yaya"})
	elif id == "tieshan":
		result.append({"id": "tieshan/tieshan", "path": "res://assets/ui/party_cards/tieshan.png", "role": true})
	return result
