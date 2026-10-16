extends RefCounted
## 角色配置循环复用；每次到店的订单标识由存档序号生成。
# 以真实餐厅中原铁山坐姿同屏校准脸部宽度；帽子、熊兜帽和头发不计入脸宽。
# 内部ID保留旧存档兼容，展示身份和对白头像分别配置。
const CUSTOMERS := [
	{"id": "mage", "scale": 0.58, "name": "萨莉亚", "recipe": "slime_candy", "portrait": "res://assets/characters/salia/salia_portrait.png"},
	{"id": "dingdang", "scale": 0.43, "name": "叮当", "recipe": "brick_snail_sashimi", "portrait": "res://assets/characters/dingdang/dingdang_portrait.png"},
	{"id": "half_elf", "scale": 0.45, "name": "御风", "recipe": "lizard_tail_skewer", "portrait": "res://assets/characters/yufeng/yufeng_portrait.png"},
]
const SEATS := [Vector2(471, 251), Vector2(397, 264), Vector2(321, 278)]
# 脚底锚点全部位于柜台北侧外部道路；向左后方排队，不进入吧台座位。
const COUNTER := Vector2(910, 198)
const QUEUE := [Vector2(795, 180), Vector2(680, 162)]

static func customer(id: String) -> Dictionary:
	for entry in CUSTOMERS:
		if entry.id == id:
			return entry.duplicate(true)
	return {}
