extends RefCounted
## 隔离编辑器的数值覆盖；没有显式安装时只返回现有游戏默认值。
static var values: Dictionary={}
static var error:=""
static var reads: Dictionary={}
static func install() -> void:
 values={}
 reads={}
 error=""
 if not OS.has_feature("web"): return
 var raw: Variant=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.parent.runtimeTuning || {})",true)))
 var schema: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/previews/editor-tuning.json"))
 if not raw is Dictionary:
  error="调参候选必须是对象，保留游戏基准"
  return
 for group in raw:
  if not schema.groups.has(group) or not raw[group] is Dictionary:
   error="未知调参组，保留游戏基准："+str(group)
   return
  for key in raw[group]:
   if not schema.groups[group].fields.has(key):
    error="未知调参字段，保留游戏基准："+str(group)+"."+str(key)
    return
   var rule: Dictionary=schema.groups[group].fields[key]
   var value: Variant=raw[group][key]
   if not rule.get("connected",false) or typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)) or value<rule.min or value>rule.max or (key=="hitstop" and float(value)!=floorf(float(value))):
    error="调参越界，保留游戏基准："+str(group)+"."+str(key)
    return
 values=raw.duplicate(true)
static func number(group: String, key: String, fallback: float) -> float:
 var result:=float(values.get(group,{}).get(key,fallback))
 reads[group+"."+key]=result
 return result
static func effect(kind: String, key: String, fallback: float) -> float:
 return number("effect."+kind,key,fallback)
