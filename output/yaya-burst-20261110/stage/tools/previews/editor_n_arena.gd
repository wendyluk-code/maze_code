extends RefCounted
## 只作用于编辑器隔离场景，游戏事务仍使用实际地图与原怪物。
static var enabled:=false
static var selected_id:=""
static var selected_kind:=""
static var ai_enabled:=true
static var infinite_life:=false
static var show_bounds:=false
static var forced_skill:=""

static func passive() -> bool:
 return enabled and (not ai_enabled or not forced_skill.is_empty())

static func immortal() -> bool:
 return enabled and infinite_life
