extends RefCounted
const RECIPES := {"wind_frog":["frog_soup","wind_frog_bread"],"mimic_crab":["mimic_crab_gratin"],"blind_scorpion":["scorpion_lotus_fritters"]}
static func unlock(sm: Node, kind: String) -> void:
	var ids: Array=sm.unlocked_recipe_ids()
	for id in RECIPES.get(kind,[]):
		if id not in ids: ids.append(id)
	sm.get("_state")[sm.UNLOCKED_RECIPES_KEY]=ids
static func historical(state: Dictionary) -> Array[String]:
	var result: Array[String]=[]
	var run: Variant=state.get("capture_run_v1",{})
	if not run is Dictionary or not run.get("monsters",{}) is Dictionary: return result
	if not load("res://scripts/maze/capture_run.gd").valid(run): return result
	for kind in RECIPES:
		var prefix: String=("fenshui_" if kind=="wind_frog" else "salt_pool_")+kind+"_"
		for key in run.get("monsters",{}):
			var row: Variant=run.monsters[key]
			var known: Array=[prefix+"1"] if kind=="wind_frog" else [prefix+"1",prefix+"2",prefix+"3"]
			if key not in known or not row is Dictionary: continue
			if row.get("status")!="captured": continue
			if row.has("capture_result") and (not row.capture_result is Dictionary or row.capture_result.get("reason")!="captured"): continue
			for id in RECIPES[kind]:
				if id not in result: result.append(id)
	return result
