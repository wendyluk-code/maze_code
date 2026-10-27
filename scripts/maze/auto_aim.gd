extends RefCounted
## 左键只触发攻击；方向由当前招式范围内最近的有效目标决定。
const Combat=preload("res://scripts/maze/combat_simulation.gd")
const Catalog=preload("res://data/maze/capture_catalog.gd")

static func target(run: Dictionary, point: Vector2, sparring: bool=false) -> String:
	var c: Dictionary=run.get("combat",{})
	if c.is_empty() or float(c.get("hp",0))<=0: return ""
	var kind:=Combat.Skills.kind(run,int(c.get("selected",0)))
	var reach: float=Combat.Skills.AXE_RADIUS if kind=="tieshan" else float(Combat.Skills.LENGTH.get(kind,0))
	var nearest:=""
	var distance:=reach+0.001
	var ids: Array=[]
	if sparring:
		if float(c.get("lock_left",-1))>=0: return ""
		ids=["yufeng","salia"]
	else:
		for row in Catalog.rows(c): ids.append(row.id)
	for id in ids:
		if not c.actors.has(id) or not run.monsters.has(id): continue
		var actor: Dictionary=c.actors[id]
		if run.monsters[id].status!="alive" or actor.hp<=0 or actor.mode=="return": continue
		if not sparring and not Catalog.targetable(c,id): continue
		var at:=Combat.vec(actor.position)
		var d:=point.distance_to(at)
		if d>reach or d>=distance: continue
		var region:=str(c.get("region","maze_entry"))
		var clear:=true
		if kind=="tieshan":
			clear=Combat.Skills.clear_line(point,at,region)
		else:
			var steps:=maxi(1,ceili(d/2.0))
			for i in range(steps+1):
				if not Combat.projectile_clear(point.lerp(at,float(i)/steps),region):
					clear=false
					break
		if clear:
			nearest=id
			distance=d
	return nearest

static func direction(run: Dictionary,point: Vector2,facing: Vector2,sparring: bool=false) -> Vector2:
	var id:=target(run,point,sparring)
	if not id.is_empty():
		var aim:=point.direction_to(Combat.vec(run.combat.actors[id].position))
		if not aim.is_zero_approx(): return aim
	return Vector2.DOWN if facing.is_zero_approx() else facing.normalized()
