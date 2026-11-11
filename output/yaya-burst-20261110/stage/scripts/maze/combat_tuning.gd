extends RefCounted
## 共用参数读取：缺省保持游戏值，显式候选只作用于隔离编辑器。
const FILE="res://data/maze/combat_tuning.json"
const SCHEMA="res://data/maze/combat_tuning_schema.json"
static var values: Dictionary={}
static var reads: Dictionary={}
static var error:=""
static var initialized:=false
static var schema: Dictionary={}

static func definition() -> Dictionary:
 if schema.is_empty():
  var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(SCHEMA))
  if raw is Dictionary: schema=raw
  var candidate: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/maze/player_skill_candidate.json"))
  if candidate is Dictionary:
   for group in candidate.get("groups",{}):
    if schema.get("groups",{}).has(group): schema.groups[group].fields.merge(candidate.groups[group],true)
 return schema

static func validate(raw: Variant, persistent: bool=false) -> String:
 if not raw is Dictionary: return "参数必须是对象"
 var groups: Dictionary=definition().get("groups",{})
 for group in raw:
  if not groups.has(group) or not raw[group] is Dictionary: return "未知参数组："+str(group)
  for key in raw[group]:
   if not groups[group].fields.has(key): return "未知字段："+str(group)+"."+str(key)
   var rule: Dictionary=groups[group].fields[key]
   var n: Variant=raw[group][key]
   if not rule.get("connected",false) or (persistent and not rule.get("persist",false)): return "字段不支持当前保存目标："+str(group)+"."+str(key)
   if typeof(n) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(n)) or n<rule.min or n>rule.max: return "数值越界："+str(group)+"."+str(key)
   if (rule.unit in ["点","颗"] or key=="hitstop") and float(n)!=floorf(float(n)): return "必须为整数："+str(group)+"."+str(key)
 return ""

static func load_settings() -> bool:
 initialized=true
 values={}
 reads={}
 error=""
 var override_path:=OS.get_environment("MAZE_COMBAT_TEST_SETTINGS_FILE")
 var file:=FILE if override_path.is_empty() else override_path
 if not FileAccess.file_exists(file): return true
 var packet: Variant=JSON.parse_string(FileAccess.get_file_as_string(file))
 if not packet is Dictionary or packet.get("version")!=1:
  error="战斗参数文件版本或格式错误"
  return false
 error=validate(packet.get("values"),true)
 if not error.is_empty(): return false
 values=packet.values.duplicate(true)
 return true

static func install() -> void:
 load_settings()
 if not OS.has_feature("web") or ProjectSettings.get_setting("application/config/name")!="maze_fenshui_editor_isolated": return
 var raw: Variant=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.parent.runtimeTuning || {})",true)))
 var problem:=validate(raw)
 if not problem.is_empty():
  error=problem
  return
 for group in raw:
  if not values.has(group): values[group]={}
  values[group].merge(raw[group],true)

static func number(group: String,key: String,fallback: float) -> float:
 if not initialized: load_settings()
 var n:=float(values.get(group,{}).get(key,fallback))
 reads[group+"."+key]=n
 return n

static func effect(kind: String,key: String,fallback: float) -> float:
 return number("effect."+kind,key,fallback)

static func apply_stats(stats: Dictionary) -> void:
 for kind in stats:
  for key in stats[kind]:
   if key!="attack": stats[kind][key]=number("base."+str(kind),str(key),float(stats[kind][key]))
