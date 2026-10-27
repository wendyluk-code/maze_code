extends RefCounted
## 正式底图红圈路边脚底坐标；事务和场景共用同一距离约束。
const POSITION := Vector2(864, 490)
const INTERACT_RADIUS := 64.0
const REQUIRED := 12
const INTRO := ["唉……那孩子说去砍柴，到现在也没回来，不知道又跑哪儿去了。", "我还等着生火做饭呢。你能帮我带来12个木材吗？"]
## 按玩家实际观看顺序逐段播放；food_reward 是食材获得蒙层。
const REWARD_STEPS := [
	{"speaker": "白虎爷爷", "lines": ["谢谢你，这下能生火做饭了。", "等等，你是那个餐厅的经营者？"]},
	{"speaker": "主角", "lines": ["你认识我？"]},
	{"speaker": "白虎爷爷", "lines": ["呵呵，看来你又忘了啊。没事，这些调味的食材送给你，你会用得上的。"]},
	{"food_reward": true},
]
const REWARD_ITEMS := [
	{"id": "moondew_honey", "name": "月露蜜", "quantity": 3, "icon": "res://assets/ui/ingredients/day1/moondew_honey.png", "region": Rect2(77, 82, 103, 93)},
	{"id": "cooking_sake", "name": "烧酒", "quantity": 3, "icon": "res://assets/ui/ingredients/day1/cooking_sake.png", "region": Rect2(76, 84, 104, 89)},
	{"id": "sour_vine_juice", "name": "酸浆藤汁", "quantity": 3, "icon": "res://assets/ui/ingredients/sour_vine_juice.png", "region": Rect2(95, 77, 66, 103)},
]

static func reward_texture(item: Dictionary) -> Texture2D:
	if item.id in ["moondew_honey", "cooking_sake"]:
		return load(item.icon)
	var texture := AtlasTexture.new()
	texture.atlas = load(item.icon)
	texture.region = item.region
	return texture

