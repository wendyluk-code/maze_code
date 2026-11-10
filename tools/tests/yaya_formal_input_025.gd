extends "res://tools/tests/player_combat_controller_flow.gd"

func battle() -> void:
 await open_map("salt_pool")
 if failures: return
 await attack_case("salt_pool","salt_pool_mimic_crab_2",1)
 if failures: return
 await picture("yaya-input-final")
