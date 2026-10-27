extends RefCounted
## 便当永久格与本趟效果。所有写入由同一次存档提交；坏记录拒绝操作，不能补发。
const KEY := "bento_v1"
const RUN_KEY := "capture_run_v1"
const SLOTS := ["attack", "health", "defense", "satiety", "special"]
const NAMES := {"attack":"攻击","health":"生命","defense":"防御","satiety":"饱腹","special":"特殊"}
const GIFTS := {"health":"cool_slime_jelly","defense":"salt_crust_silverfish","attack":"thunder_eel_roll"}
const Catalog = preload("res://scripts/cooking/recipe_catalog.gd")
const Freezer = preload("res://scripts/restaurant/freezer_store.gd")

static func recipe_slot(recipe_id: String) -> String:
	var recipe := Catalog.get_recipe(recipe_id)
	if "探索" not in recipe.get("uses", []): return ""
	for slot in SLOTS:
		if NAMES[slot] == recipe.get("exploration_category", ""): return slot
	return ""

## 草稿只含格子与具体份编号；一次校验、一次写盘，不经过携带库存。
static func assemble(sm: Node, choices: Dictionary) -> Dictionary:
	var run: Variant = sm.get("_state").get(RUN_KEY, {})
	if not run is Dictionary: return {"success":false,"reason":"invalid_state"}
	if sm.maze_exploration_state().region != "restaurant" or run.get("active", false):
		return {"success":false,"reason":"not_in_restaurant"}
	var b := snapshot(sm)
	var ledger: Dictionary = sm.freezer_snapshot()
	if b.is_empty() or not b.unlocked or ledger.is_empty(): return {"success":false,"reason":"invalid_state"}
	if choices.is_empty(): return {"success":false,"reason":"empty"}
	var now := int(Time.get_unix_time_from_system())
	var used := {}
	for slot in choices:
		if slot not in SLOTS or b.slots.has(slot): return {"success":false,"reason":"occupied"}
		var unit_id: Variant = choices[slot]
		if not Freezer.integer(unit_id, 1) or used.has(int(unit_id)): return {"success":false,"reason":"changed"}
		var found := false
		for unit in ledger.stored:
			if int(unit.id) != int(unit_id): continue
			if int(unit.expires_at) <= now: return {"success":false,"reason":"expired"}
			if recipe_slot(unit.recipe_id) != slot: return {"success":false,"reason":"wrong_dimension"}
			b.slots[slot] = {"id":unit.recipe_id,"stars":int(unit.quality),"eaten":false}
			used[int(unit_id)] = true
			found = true
			break
		if not found: return {"success":false,"reason":"changed"}
	ledger.stored = ledger.stored.filter(func(unit): return not used.has(int(unit.id)))
	if not valid(b) or not Freezer.valid(ledger, sm.prepared_dishes_snapshot()): return {"success":false,"reason":"invalid_state"}
	var before: Dictionary = sm.get("_state").duplicate(true)
	sm.get("_state")[KEY] = b
	sm.get("_state")[Freezer.KEY] = ledger
	return commit(sm, before)

static func empty() -> Dictionary:
	return {"version":1,"granted":false,"unlocked":false,"slots":{}}

static func valid(b: Variant) -> bool:
	if not b is Dictionary or b.get("version")!=1 or not b.get("granted") is bool or not b.get("unlocked") is bool or not b.get("slots") is Dictionary: return false
	if b.unlocked and not b.granted: return false
	if not b.granted and not b.slots.is_empty(): return false
	for slot in b.slots:
		var row: Variant=b.slots[slot]
		if not slot in SLOTS or not row is Dictionary or not row.get("id") is String or recipe_slot(row.id)!=slot: return false
		if not integer(row.get("stars"),1,3) or not row.get("eaten") is bool: return false
	return true

static func integer(v: Variant, low: int, high: int) -> bool:
	return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and v>=low and v<=high and floor(float(v))==v

static func snapshot(sm: Node) -> Dictionary:
	var raw: Variant=sm.get("_state").get(KEY,empty())
	return raw.duplicate(true) if valid(raw) else {}

static func unlocked(sm: Node) -> bool:
	return snapshot(sm).get("unlocked",false)

static func commit(sm: Node, before: Dictionary) -> Dictionary:
	if sm.save(): return {"success":true}
	sm.set("_state",before)
	return {"success":false,"reason":"save_failed"}

static func grant(sm: Node) -> Dictionary:
	var b := snapshot(sm)
	if b.is_empty(): return {"success":false,"reason":"invalid_bento"}
	if b.granted: return {"success":true,"created":false}
	if sm.yufeng_salia_record().phase!="gift_pending" or not b.slots.is_empty(): return {"success":false,"reason":"invalid_phase"}
	var before: Dictionary=sm.get("_state").duplicate(true)
	for slot in GIFTS: b.slots[slot]={"id":GIFTS[slot],"stars":3,"eaten":false}
	b.granted=true
	sm.get("_state")[KEY]=b
	var recipes: Array=sm.unlocked_recipe_ids()
	for id in GIFTS.values():
		if id not in recipes: recipes.append(id)
	sm.get("_state")[sm.UNLOCKED_RECIPES_KEY]=recipes
	sm.get("_state")[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"gift_reward","line":0}
	return commit(sm,before)

static func reveal(sm: Node) -> Dictionary:
	var b := snapshot(sm)
	if b.is_empty() or not b.granted or sm.yufeng_salia_record().phase!="bento_unlock": return {"success":false,"reason":"invalid_phase"}
	if b.unlocked: return {"success":true}
	var before: Dictionary=sm.get("_state").duplicate(true)
	b.unlocked=true
	sm.get("_state")[KEY]=b
	return commit(sm,before)

static func effect(slot: String, stars: int) -> float:
	return float(({"attack":[1,2,3],"defense":[1,1,2],"health":[0.1,0.2,0.3]}.get(slot,[0,0,0]))[clampi(stars,1,3)-1])

static func description(slot: String, stars: int, recipe_id: String = "") -> String:
	if recipe_id=="frog_soup": return "立即恢复团队最大生命%d%%" % [15,25,35][clampi(stars,1,3)-1]
	if recipe_id=="wind_frog_bread": return "按队伍顺序恢复合计%d点饱腹" % clampi(stars,1,3)
	if slot=="health": return "20秒恢复团队最大生命%d%%" % roundi(effect(slot,stars)*100)
	return "团队%s +%d · 本趟有效" % [NAMES.get(slot,slot),int(effect(slot,stars))]

static func eat(sm: Node, selected: String = "all") -> Dictionary:
	var api=load("res://scripts/maze/capture_run.gd")
	var run: Dictionary=api.snapshot(sm)
	var b := snapshot(sm)
	if not unlocked(sm) or b.is_empty(): return {"success":false,"reason":"invalid_bento"}
	if sm.maze_exploration_state().region not in ["maze_entry","fenshui","salt_pool"] or not api.valid(run) or not run.get("active",false) or run.combat.hp<=0: return {"success":false,"reason":"not_in_maze"}
	if api.portal_combat_locked(sm) or not run.pending.is_empty() or sm.yufeng_salia_record().phase in ["intro","eat","question","battle","post","gift_pending","gift_reward","bento_unlock","bento_fly","farewell","fade"]: return {"success":false,"reason":"in_combat_or_event"}
	var choices: Array=[]
	for slot in b.slots:
		if (selected=="all" or selected==slot) and not b.slots[slot].eaten: choices.append(slot)
	if choices.is_empty(): return {"success":false,"reason":"nothing_to_eat"}
	var before: Dictionary=sm.get("_state").duplicate(true)
	var progression=preload("res://scripts/characters/character_progression.gd")
	var food: Dictionary=progression.satiety_snapshot(sm)
	if not food.valid: return {"success":false,"reason":"invalid_satiety"}
	# 全吃跳过当前无收益的即时料理；单吃拒绝并保留该份。
	for slot in choices.duplicate():
		var id: String=b.slots[slot].id
		var full: bool=id=="frog_soup" and run.combat.hp>=run.combat.max_hp
		if id=="wind_frog_bread":
			full=true
			for member in run.members:
				if float(food.values.get(member.id,0))<float(progression.record(sm,member.id).satiety_max): full=false
		if full: choices.erase(slot)
	if choices.is_empty(): return {"success":false,"reason":"already_full"}
	var buffs: Dictionary=run.get("bento",{"attack":0,"defense":0,"heal_total":0.0,"heal_elapsed":0.0,"heal_paid":0.0})
	for slot in choices:
		if float(buffs.get("heal_total" if slot=="health" else slot,0))>0: return {"success":false,"reason":"already_consumed_dimension"}
	for slot in choices:
		var amount := effect(slot,int(b.slots[slot].stars))
		b.slots[slot].eaten=true
		if b.slots[slot].id=="frog_soup":
			run.combat.hp=minf(float(run.combat.max_hp),float(run.combat.hp)+float(run.combat.max_hp)*[0.15,0.25,0.35][int(b.slots[slot].stars)-1])
		elif b.slots[slot].id=="wind_frog_bread":
			var remaining:=float(b.slots[slot].stars)
			while remaining>0.000001:
				var paid:=0.0
				for member in run.members:
					var capacity: float=progression.record(sm,member.id).satiety_max
					var gain:=minf(remaining,minf(1.0,maxf(0.0,capacity-float(food.values[member.id]))))
					food.values[member.id]+=gain
					remaining-=gain
					paid+=gain
					if remaining<=0.000001: break
				if paid<=0.000001: break
			progression.store_satiety(sm,food,true)
			run.satiety=api._party_food(food,run.members)
		elif slot=="health":
			buffs.heal_total=float(run.combat.max_hp)*amount
			buffs.heal_elapsed=0.0
			buffs.heal_paid=0.0
		else:
			buffs[slot]=int(amount)
			if slot=="attack": run.combat.attack+=int(amount)
	run.bento=buffs
	sm.get("_state")[KEY]=b
	sm.get("_state")[RUN_KEY]=run
	return commit(sm,before)

static func discard(sm: Node, slot: String) -> Dictionary:
	var b := snapshot(sm)
	if b.is_empty() or not b.unlocked or not b.slots.has(slot) or b.slots[slot].eaten: return {"success":false,"reason":"not_discardable"}
	var before: Dictionary=sm.get("_state").duplicate(true)
	b.slots.erase(slot)
	sm.get("_state")[KEY]=b
	return commit(sm,before)

static func valid_effects(run: Dictionary) -> bool:
	if not run.has("bento"): return true
	if not run.get("combat") is Dictionary: return false
	var maximum: Variant=run.combat.get("max_hp")
	if typeof(maximum) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(maximum)) or maximum<1: return false
	var b: Variant=run.bento
	if not b is Dictionary or not integer(b.get("attack"),0,3) or not integer(b.get("defense"),0,2): return false
	for key in ["heal_total","heal_elapsed","heal_paid"]:
		var v: Variant=b.get(key)
		if typeof(v) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(v)) or v<0: return false
	return b.heal_elapsed<=20.0 and b.heal_paid<=b.heal_total+0.000001 and b.heal_total<=run.combat.max_hp*0.3+0.000001

static func presentation_valid(sm: Node, phase: String) -> bool:
	var b := snapshot(sm)
	if b.is_empty(): return false
	if phase=="gift_pending" and b.granted: return false
	if phase in ["gift_reward","bento_unlock","bento_fly","farewell","fade","done"]:
		if not b.granted: return false
		for id in GIFTS.values():
			if id not in sm.unlocked_recipe_ids(): return false
		if phase in ["gift_reward","bento_unlock","bento_fly","farewell","fade"]:
			for slot in GIFTS:
				if not b.slots.has(slot) or b.slots[slot].id!=GIFTS[slot] or b.slots[slot].stars!=3 or b.slots[slot].eaten: return false
		if phase in ["bento_fly","farewell","fade","done"] and not b.unlocked: return false
	return true

static func advance(run: Dictionary, dt: float) -> bool:
	if not run.has("bento") or run.bento.heal_elapsed>=20.0 or run.bento.heal_total<=0 or run.combat.hp<=0: return false
	var b: Dictionary=run.bento
	b.heal_elapsed=minf(20.0,float(b.heal_elapsed)+dt)
	var due: float=float(b.heal_total)*float(b.heal_elapsed)/20.0
	run.combat.hp=minf(float(run.combat.max_hp),float(run.combat.hp)+maxf(0,due-float(b.heal_paid)))
	b.heal_paid=due
	return true

static func finish(sm: Node, run: Dictionary) -> void:
	var b := snapshot(sm)
	if not b.is_empty():
		for slot in b.slots.keys():
			if b.slots[slot].eaten: b.slots.erase(slot)
		sm.get("_state")[KEY]=b
	if run.has("bento"):
		run.combat.attack-=int(run.bento.attack)
		run.erase("bento")
