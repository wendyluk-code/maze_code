extends RefCounted
## 角色配置循环复用；每次到店的订单标识由存档序号生成。
# 以真实餐厅中原铁山坐姿同屏校准脸部宽度；帽子、熊兜帽和头发不计入脸宽。
# 内部ID保留旧存档兼容，展示身份和对白头像分别配置。
const LEGACY_CUSTOMERS := [
	{"id": "mage", "scale": 0.58, "name": "萨莉亚", "recipe": "slime_candy", "portrait": "res://assets/characters/salia/salia_portrait.png"},
	{"id": "dingdang", "scale": 0.43, "name": "叮当", "recipe": "brick_snail_sashimi", "portrait": "res://assets/characters/dingdang/dingdang_portrait.png"},
	{"id": "half_elf", "scale": 0.58, "name": "御风", "recipe": "lizard_tail_skewer", "portrait": "res://assets/characters/yufeng/yufeng_portrait.png"},
]
# 经营身份与配方不变；展示配置独立，旧角色模板仍可显式查询。
const CUSTOMERS := [
	{"id": "mage", "scale": 0.40, "name": "冒险者", "recipe": "slime_candy", "portrait": "res://assets/characters/customers/adventurers/male_01_portrait.png", "actions": "res://assets/characters/customers/adventurers/male_01_actions.png", "cell_size": 384},
	{"id": "dingdang", "scale": 0.40, "name": "冒险者", "recipe": "brick_snail_sashimi", "portrait": "res://assets/characters/customers/adventurers/female_05_portrait.png", "actions": "res://assets/characters/customers/adventurers/female_05_actions.png", "cell_size": 384},
	{"id": "half_elf", "scale": 0.40, "name": "冒险者", "recipe": "lizard_tail_skewer", "portrait": "res://assets/characters/customers/adventurers/male_08_portrait.png", "actions": "res://assets/characters/customers/adventurers/male_08_actions.png", "cell_size": 384},
]
const SEATS := preload("res://scripts/restaurant/three_seat_layout.gd").SEATS
# 脚底锚点全部位于柜台北侧外部道路；向左后方排队，不进入吧台座位。
const COUNTER := Vector2(910, 198)
const QUEUE := [Vector2(795, 180), Vector2(680, 162)]
const ROTATION := ["male_01","female_01","male_02","female_02","male_03","female_03","male_04","female_04","male_05","female_05","male_06","female_06","male_07","female_07","male_08","female_08","male_09","female_09"]
static var _rotation_manifest: Dictionary = {}

static func rotating_customer(serial: int) -> Dictionary:
	return customer(ROTATION[posmod(serial-1,ROTATION.size())])

static func customer(id: String) -> Dictionary:
	for entry in CUSTOMERS:
		if entry.id == id:
			return entry.duplicate(true)
	if id in ROTATION:
		# 原三个持久身份继续可读；新订单使用明确的男女编号。
		var existing := {"male_01":0,"female_05":1,"male_08":2}
		if existing.has(id):
			var entry: Dictionary = CUSTOMERS[existing[id]].duplicate(true)
			entry["face_template"] = entry.id
			entry.id = id
			return entry
		if _rotation_manifest.is_empty():
			_rotation_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/customers/adventurers/rotation_manifest.json"))
		return {"id":id,"scale":0.40,"name":"冒险者","recipe":"slime_candy","portrait":"res://assets/characters/customers/adventurers/%s_portrait.png" % id,"actions":"res://assets/characters/customers/adventurers/%s_actions.png" % id,"cell_size":384,"face":_rotation_manifest[id].face}
	return {}

static func legacy_customer(id: String) -> Dictionary:
	for entry in LEGACY_CUSTOMERS:
		if entry.id == id:
			return entry.duplicate(true)
	return {}
