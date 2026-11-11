extends RefCounted
## 角色共用局部卡肉，按招式读取；不绑定怪物。
const FILE="res://data/maze/player_combat_editor.json"
const DEFAULTS={"hero":50,"yaya":50,"tieshan":70}
static var values: Dictionary=DEFAULTS.duplicate()
static var initialized:=false

static func load_settings() -> bool:
 initialized=true
 var override_path:=OS.get_environment("MAZE_PLAYER_TEST_SETTINGS_FILE")
 var file_path:=override_path if not override_path.is_empty() else FILE
 if not FileAccess.file_exists(file_path): return false
 var input: Variant=JSON.parse_string(FileAccess.get_file_as_string(file_path))
 if not input is Dictionary or input.get("version")!=1 or not input.get("effects") is Dictionary: return false
 var next: Dictionary={}
 for id in DEFAULTS:
  var row: Variant=input.effects.get(id)
  if not row is Dictionary or not row.has("hitstop"): return false
  var n: Variant=row.hitstop
  if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)) or n<0 or n>200 or float(n)!=floor(float(n)): return false
  next[id]=int(n)
 if input.effects.size()!=DEFAULTS.size(): return false
 values=next
 return true

static func hitstop(id: String) -> int:
 if not initialized: load_settings()
 return int(preload("res://scripts/maze/combat_tuning.gd").effect(id,"hitstop",float(values.get(id,DEFAULTS.get(id,0)))))
