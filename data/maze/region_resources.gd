extends RefCounted
## 固定领取身份：植物每趟一次，木材和真宝箱永久一次。
const POINTS := {
	"fenshui": [
		["herb_1",1060,300,"cool_whisker_herb",2],
		["herb_2",480,320,"cool_whisker_herb",2],
		["herb_3",760,600,"cool_whisker_herb",2],
		["wood_1",320,245,"wood",3],
		["lotus_1",360,510,"canal_lotus_root",2],
		["lotus_2",1180,650,"canal_lotus_root",2],
		["chest_1",300,480,"gold",100],
		["chest_2",980,755,"gold",100],
		["chest_3",740,220,"gold",100]],
	"salt_pool": [
		["fruit_1",570,690,"lantern_fruit",2],
		["fruit_2",1280,590,"lantern_fruit",2],
		["chest_1",400,310,"gold",100],
		["chest_2",1140,650,"gold",100],
		["chest_3",1360,300,"gold",100]]
}
static func all(region: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for p in POINTS.get(region,[]):
		result.append({"id":region+"_resource_"+p[0],"region":region,"position":Vector2(p[1],p[2]),"item":p[3],"amount":p[4],"permanent":p[3] in ["gold","wood"]})
	return result
static func find(id: String) -> Dictionary:
	for region in POINTS:
		for row in all(region):
			if row.id==id: return row
	return {}
static func protected(region: String,point: Vector2,margin: float=0.0) -> bool:
	for row in all(region):
		if point.distance_to(row.position)<42.0+margin: return true
	return false
