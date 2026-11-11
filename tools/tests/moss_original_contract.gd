extends SceneTree
## 独立原图样点先于实现固定，不从道路定义生成预期。
const Moss = preload("res://data/maze/moss_pool_roads.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	check(FileAccess.get_sha256("res://assets/maps/moss_pool.png")=="c9a317212982089ba3fa4340f7c6d4d1286c5ca1bea100aa63905c95cc73edf1","生产底图与飞书下载原件逐字节一致")
	check(Moss.SIZE==Vector2(1408,1117),"原图世界尺寸1408乘1117")
	for point in [Vector2(1120,1070),Vector2(1050,950),Vector2(974,824),Vector2(1060,702),Vector2(1315,710),Vector2(667,575),Vector2(390,354),Vector2(548,917),Vector2(970,435)]:
		check(Moss.is_walkable(point),"原图独立土路样点可走"+str(point))
	for point in [Vector2(400,180),Vector2(740,430),Vector2(400,560),Vector2(900,650),Vector2(600,800),Vector2(600,345),Vector2(800,350),Vector2(860,510),Vector2(320,420),Vector2(1200,500),Vector2(1201,956),Vector2(1030,950),Vector2(345,249),Vector2(962,336)]:
		check(not Moss.is_walkable(point),"原图水池瀑布树林及旧图错误站位阻挡"+str(point))
	check(not Moss.is_walkable(Vector2(NAN,0)),"非法坐标拒绝")
	check(not Moss.is_walkable(Vector2(1120,1070),-1),"负脚底半径拒绝")
	print(JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("失败："+label)
