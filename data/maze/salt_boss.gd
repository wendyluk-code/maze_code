extends RefCounted
## 中央陆地出生，按脚底碰撞绕障追击；不改变玩家碰撞。
const Roads = preload("res://data/maze/salt_pool_roads.gd")
const ID := "salt_pool_rockmane_1"
const HOME := Vector2(850,425)
const BODY := 8.0
const TYPE := {"name":"岩鬃兽","power":120,"element":"earth","chance":50,"sheet":"res://assets/monsters/rockmane/idle.png","animation_dir":"res://assets/monsters/rockmane/","drops":["rockmane_meat"],"width":120.0,"anchor":0.823}
static func row() -> Dictionary:
	var r:=TYPE.duplicate(true)
	r.merge({"id":ID,"kind":"rockmane","region":"salt_pool","position":HOME,"direction":0})
	return r
static func line(a: Vector2,b: Vector2,radius: float=0.0) -> bool:
	for i in range(maxi(1,ceili(a.distance_to(b)/2.0))+1):
		if not Roads.is_walkable(a.lerp(b,float(i)/maxi(1,ceili(a.distance_to(b)/2.0))),radius): return false
	return true
static func allowed(p: Vector2) -> bool:
	return Roads.is_walkable(p,BODY)
static func move(p: Vector2,delta: Vector2) -> Vector2:
	var n:=maxi(1,ceili(delta.length()/2.0))
	var out:=p
	for i in n:
		var q:=out+delta/n
		if not allowed(q): break
		out=q
	return out
