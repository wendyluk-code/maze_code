extends RefCounted
const Catalog=preload("res://data/maze/region_resources.gd")
const Run=preload("res://scripts/maze/capture_run.gd")
static func claim(sm: Node,id: String,point: Vector2) -> Dictionary:
	var row:=Catalog.find(id)
	var run:=Run.snapshot(sm)
	if row.is_empty() or row.item=="gold" or not sm.can_enter_maze() or sm.maze_exploration_state().region!=row.region: return {"success":false,"reason":"invalid_location"}
	if not sm.maze_terrain(row.region).is_walkable(point) or point.distance_to(row.position)>52.0: return {"success":false,"reason":"invalid_location"}
	if not Run.valid(run) or not run.get("active",false) or run.combat.hp<=0 or Run.portal_combat_locked(sm) or not run.pending.is_empty(): return {"success":false,"reason":"in_combat"}
	if not sm.dig_reward_state_valid(): return {"success":false,"reason":"invalid_reward_state"}
	if sm.is_dig_site_claimed(id): return {"success":false,"reason":"already_claimed"}
	var state: Dictionary=sm.get("_state")
	var before:=state.duplicate(true)
	if row.permanent:
		var count: int=state[sm.INVENTORY_KEY].get("wood",0)
		if count>9007199254740991-row.amount: return {"success":false,"reason":"overflow"}
		var claims: Array=state.get(sm.CLAIMED_DIG_SITES_KEY,[]).duplicate()
		claims.append(id)
		state[sm.CLAIMED_DIG_SITES_KEY]=claims
		state[sm.INVENTORY_KEY]["wood"]=count+row.amount
	else:
		if int(run.bag.get(row.item,0))+row.amount>100000: return {"success":false,"reason":"overflow"}
		var claims: Array=run.get("resource_claims",[]).duplicate()
		claims.append(id)
		run.resource_claims=claims
		run.bag[row.item]=int(run.bag.get(row.item,0))+row.amount
	state[Run.KEY]=run
	state[sm.MAZE_STATE_KEY].position=[point.x,point.y]
	if not sm.save():
		sm.set("_state",before)
		return {"success":false,"reason":"save_failed"}
	return {"success":true,"amount":row.amount,"item":row.item}
