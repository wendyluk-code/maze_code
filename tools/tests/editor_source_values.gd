extends SceneTree
const Fish=preload("res://scripts/maze/silverfish_editor.gd")
const Monster=preload("res://scripts/maze/monster_editor.gd")
const Player=preload("res://scripts/maze/player_editor.gd")

func _initialize() -> void:
 var fish: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/maze/silverfish_editor.json"))
 var monsters: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/maze/monster_attack.json"))
 var player: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/maze/player_combat_editor.json"))
 if not fish is Dictionary or not monsters is Dictionary or not player is Dictionary:
  printerr("真实项目参数文件不可读取")
  quit(1)
  return
 if not Fish.load_settings() or not Monster.load_settings() or not Player.load_settings():
  printerr("真实项目参数读取或校验失败")
  quit(1)
  return
 for key in Fish.DEFAULTS:
  if not is_equal_approx(Fish.value(key),float(fish.fish[key])):
   printerr("银鳞鱼参数不一致：",key)
   quit(1)
   return
 for id in Monster.KINDS:
  if Monster.attack(id,-1)!=int(monsters.attack[id]):
   printerr("怪物参数不一致：",id)
   quit(1)
   return
 for id in Player.DEFAULTS:
  if Player.hitstop(id)!=int(player.effects[id].hitstop):
   printerr("角色参数不一致：",id)
   quit(1)
   return
 print("SOURCE_GAME_VALUES_REAL_PATH fish=",Fish.DEFAULTS.size()," monsters=",Monster.KINDS.size()," player=",Player.DEFAULTS.size())
 quit(0)
