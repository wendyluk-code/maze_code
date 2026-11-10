extends RefCounted
## 首批只读取银鳞鱼参数；错误数据保留已有有效值。
const FILE := "res://data/maze/silverfish_editor.json"
const DEFAULTS := {"fx_scale":100.0,"fx_duration":230.0,"opacity":100.0,"offset_x":0.0,"offset_y":0.0,"angle":0.0,"hurt":600.0,"windup":750.0,"recover":900.0}
const LIMITS := {"fx_scale":[25.0,250.0],"fx_duration":[60.0,1200.0],"opacity":[0.0,100.0],"offset_x":[-80.0,80.0],"offset_y":[-80.0,80.0],"angle":[-180.0,180.0],"hurt":[190.0,1500.0],"windup":[100.0,1200.0],"recover":[100.0,1200.0]}
static var values: Dictionary=DEFAULTS.duplicate(true)
static var initialized:=false

static func load_settings() -> bool:
 initialized=true
 var test_path:=OS.get_environment("MAZE_COMBAT_TEST_SETTINGS_FILE")
 var file_path:=test_path if not test_path.is_empty() else FILE
 if not FileAccess.file_exists(file_path): return false
 var input: Variant=JSON.parse_string(FileAccess.get_file_as_string(file_path))
 if not input is Dictionary or input.get("version")!=1 or input.get("monster")!="silverfish": return false
 var fish: Variant=input.get("fish")
 if not fish is Dictionary or fish.size()!=DEFAULTS.size(): return false
 for key in DEFAULTS:
  if not fish.has(key) or typeof(fish[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(fish[key])): return false
  if float(fish[key])<LIMITS[key][0] or float(fish[key])>LIMITS[key][1]: return false
 values=fish.duplicate(true)
 return true

static func value(key: String) -> float:
 if not initialized: load_settings()
 return preload("res://scripts/maze/combat_tuning.gd").effect("fish",key,float(values[key]))

static func seconds(key: String) -> float:
 return value(key)/1000.0
