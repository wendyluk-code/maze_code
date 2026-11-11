extends RefCounted
## 仅怪物攻击基础值；原伤害计算、怪物资格及状态提交仍由游戏负责。
const FILE="res://data/maze/monster_attack.json"
const KINDS=["slime","snail","beetle","lizard","silverfish","thunder_eel","wind_frog","mimic_crab","blind_scorpion","rockmane"]
static var values: Dictionary={}
static var initialized:=false

static func load_settings() -> bool:
 initialized=true
 var override_path:=OS.get_environment("MAZE_MONSTER_TEST_SETTINGS_FILE")
 var file_path:=override_path if not override_path.is_empty() else FILE
 if not FileAccess.file_exists(file_path): return false
 var input: Variant=JSON.parse_string(FileAccess.get_file_as_string(file_path))
 if not input is Dictionary or input.get("version")!=1: return false
 var next: Variant=input.get("attack")
 if not next is Dictionary or next.size()!=KINDS.size(): return false
 for kind in KINDS:
  if not next.has(kind) or typeof(next[kind]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(next[kind])): return false
  if float(next[kind])<0 or float(next[kind])>100 or float(next[kind])!=floor(float(next[kind])): return false
 values=next.duplicate(true)
 return true

static func attack(kind: String, original: int) -> int:
 if not initialized: load_settings()
 return int(preload("res://scripts/maze/combat_tuning.gd").number("base."+kind,"attack",float(values.get(kind,original))))
