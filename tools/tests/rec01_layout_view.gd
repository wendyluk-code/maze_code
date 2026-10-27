extends "res://scripts/ui/components/recruit_results.gd"
var amount := 6
func _overview_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i in amount:
		entries.append({"id":"salia","rank":6,"count":1,"duplicates":1,"stardust":100})
	return entries
