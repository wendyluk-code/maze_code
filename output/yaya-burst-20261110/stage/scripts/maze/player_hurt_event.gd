extends RefCounted
## 原伤害事务内刷新恢复并取消未完成攻击；显示事件仅在外层保存成功后发布。
const RECOVERY=0.6
const SLAM_RECOVERY=0.9
const SilverfishEditor=preload("res://scripts/maze/silverfish_editor.gd")
const Rules=preload("res://scripts/maze/player_combat_rules.gd")

static func recovery_time(kind: String) -> float:
 return SilverfishEditor.seconds("hurt") if kind=="fish" else preload("res://scripts/maze/combat_tuning.gd").effect(kind,"hurt",(SLAM_RECOVERY if kind=="slam" else RECOVERY)*1000.0)/1000.0

static func enabled(c: Dictionary) -> bool:
 return Rules.enabled(c)

static func recovering(c: Dictionary) -> bool:
 return enabled(c) and float(c.get("hp",0.0))>0.0 and float(c.get("hurt_recovery_left",0.0))>0.000001

static func advance(c: Dictionary, dt: float) -> void:
 if c.has("rock_stun_left"):
  c.rock_stun_left=maxf(0.0,float(c.rock_stun_left)-dt) if enabled(c) and c.hp>0.0 and c.get("region","")=="salt_pool" else 0.0
 if c.has("hurt_recovery_left"):
  c.hurt_recovery_left=maxf(0.0,float(c.hurt_recovery_left)-dt) if enabled(c) and c.hp>0.0 else 0.0

static func record(c: Dictionary, before: float, kind: String, point: Vector2, source: Vector2, events: Array) -> void:
 if preload("res://tools/previews/editor_n_arena.gd").immortal(): c.hp=maxf(1.0,float(c.hp))
 if not enabled(c) or float(c.hp)>=before: return
 c.hurt_recovery_left=maxf(recovery_time(kind),float(c.get("rock_stun_left",0.0))) if c.hp>0.0 else 0.0
 c.action=""
 c.action_left=0.0
 c.axe_pending=false
 c.seed_remaining=0
 c.seed_wait=0.0
 var direction:=source.direction_to(point)
 if direction.is_zero_approx(): direction=Vector2.DOWN
 events.append({"kind":kind,"point":[point.x,point.y],"direction":[direction.x,direction.y]})
