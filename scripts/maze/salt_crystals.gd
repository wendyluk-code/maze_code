extends RefCounted
## 命中来自玩家普攻模拟；采集日账本与探索袋由外层同一次保存提交。
const Roads=preload("res://data/maze/salt_pool_roads.gd")
const KEY:="salt_crystal_days_v1"
const POLYGONS:=[4,5]
## 显示轮廓与地形占地不同：原左侧阻挡还包含水洼，不能整块染灰或当晶体命中。
static var SHAPES: Array = [
	[PackedVector2Array([Vector2(522,327),Vector2(536,350),Vector2(537,383),Vector2(525,392),Vector2(509,382),Vector2(508,352)]),
	PackedVector2Array([Vector2(500,367),Vector2(513,380),Vector2(516,400),Vector2(505,408),Vector2(491,400),Vector2(489,382)]),
	PackedVector2Array([Vector2(550,353),Vector2(558,371),Vector2(551,388),Vector2(537,392),Vector2(538,370)]),
	PackedVector2Array([Vector2(464,382),Vector2(474,394),Vector2(457,396)]),
	PackedVector2Array([Vector2(558,384),Vector2(565,399),Vector2(551,403)])],
	[PackedVector2Array([Vector2(1159,274),Vector2(1175,296),Vector2(1174,331),Vector2(1160,340),Vector2(1145,330),Vector2(1142,296)]),
	PackedVector2Array([Vector2(1133,300),Vector2(1145,316),Vector2(1145,337),Vector2(1134,343),Vector2(1123,331),Vector2(1123,315)]),
	PackedVector2Array([Vector2(1186,314),Vector2(1197,335),Vector2(1192,352),Vector2(1177,358),Vector2(1167,346),Vector2(1170,330)]),
	PackedVector2Array([Vector2(1121,330),Vector2(1130,346),Vector2(1116,350)]),
	PackedVector2Array([Vector2(1164,345),Vector2(1173,358),Vector2(1157,359)])]
]
static func near_visible(index: int,p: Vector2,radius: float) -> bool:
	for poly in SHAPES[index]:
		if Geometry2D.is_point_in_polygon(p,poly): return true
		for i in poly.size():
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()]))<=radius: return true
	return false
static func day(at: float=-1.0) -> int:
	return floori(((Time.get_unix_time_from_system() if at<0 else at)+28800.0)/86400.0)
static func valid(ledger: Variant) -> bool:
	if not ledger is Dictionary: return false
	for id in ledger:
		if id not in ["left","right"] or not ledger[id] is Dictionary: return false
		for key in ["day","used"]:
			var v: Variant=ledger[id].get(key)
			if typeof(v) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(v)) or v<0 or float(v)!=floor(float(v)): return false
		if ledger[id].used>3: return false
	return true
static func used(ledger: Dictionary,id: String,today: int) -> int:
	var row: Dictionary=ledger.get(id,{})
	return int(row.get("used",0)) if today<=int(row.get("day",today)) else 0
static func nearest(index: int,p: Vector2) -> Vector2:
	var polygon: PackedVector2Array=Roads.BLOCKERS[POLYGONS[index]]
	var best:=polygon[0]
	for i in polygon.size():
		var q:=Geometry2D.get_closest_point_to_segment(p,polygon[i],polygon[(i+1)%polygon.size()])
		if q.distance_squared_to(p)<best.distance_squared_to(p): best=q
	return best
static func clear_to_edge(p: Vector2,q: Vector2) -> bool:
	var count:=maxi(1,ceili(p.distance_to(q)/2.0))
	for i in count:
		if not Roads.is_walkable(p.lerp(q,float(i)/count),0.0): return false
	return true
static func melee(c: Dictionary,p: Vector2,element: String,serial: int) -> void:
	if c.get("region","")!="salt_pool" or not Roads.is_walkable(p): return
	var selected:=-1
	var distance:=66.001
	for index in 2:
		var edge:=nearest(index,p)
		if p.distance_to(edge)<distance and near_visible(index,p,66.0) and near_visible(index,edge,20.0) and clear_to_edge(p,edge):
			selected=index
			distance=p.distance_to(edge)
	if selected>=0: impact(c,selected,element,serial)
static func projectile(c: Dictionary,p: Vector2,shot: Dictionary) -> bool:
	if c.get("region","")!="salt_pool" or not shot.get("basic",false): return false
	for index in 2:
		# 投射物地形检查使用现有4像素脚底边缘；命中须覆盖该边缘和2像素采样步长。
		if near_visible(index,p,20.0) and (Geometry2D.is_point_in_polygon(p,Roads.BLOCKERS[POLYGONS[index]]) or nearest(index,p).distance_to(p)<=Roads.FOOT_RADIUS+2.0):
			impact(c,index,str(shot.get("element","")),int(shot.get("attack_serial",-1)))
			return true
	return false
static func impact(c: Dictionary,index: int,element: String,serial: int) -> void:
	# 并行弹道可能乱序命中，不能只记最后一次。32次远大于8颗飞行上限和1.5秒寿命。
	if serial<0 or serial<int(c.throws)-32: return
	var receipts: Array=c.get("salt_attack_receipts",[])
	# JSON数字重载为float，按规范化整数比较，不能使用Variant类型敏感的Array.has。
	if receipts.any(func(value): return int(value)==serial): return
	receipts=receipts.filter(func(value): return int(value)>=int(c.throws)-32)
	receipts.append(serial)
	c.salt_attack_receipts=receipts
	if not c.has("salt_impacts"): c.salt_impacts=[]
	c.salt_impacts.append({"id":"left" if index==0 else "right","element":element})
static func apply(state: Dictionary,run: Dictionary,today: int) -> Dictionary:
	var raw: Variant=state.get(KEY,{})
	if not valid(raw): return {"success":false,"reason":"invalid_salt_ledger"}
	var ledger: Dictionary=raw.duplicate(true)
	var changed:=false
	var feedback: Array=[]
	for event in run.combat.get("salt_impacts",[]):
		if event.element!="earth":
			feedback.append("dull")
			continue
		var id: String=event.id
		var row: Dictionary=ledger.get(id,{"day":today,"used":0})
		# 日期只前进；回拨不退已采次数。没有服务器时间，无法防止人为快进时钟。
		if today>int(row.day): row={"day":today,"used":0}
		if int(row.used)>=3:
			feedback.append("empty")
			continue
		row.used+=1
		ledger[id]=row
		run.bag.rock_salt=int(run.bag.get("rock_salt",0))+1
		changed=true
		feedback.append("salt")
	run.combat.erase("salt_impacts")
	if changed: state[KEY]=ledger
	return {"success":true,"changed":changed,"feedback":feedback}
