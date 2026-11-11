extends RefCounted
## 每趟探索的保命事务状态；跨区、读档保留，只有新建探索初始化。
static func fresh() -> Dictionary:
	return {"used":false,"invincible":0.0,"heal_left":0.0,"total":0.0,"paid":0.0}

static func rank_for(run: Dictionary) -> int:
	for member in run.members:
		if member.id=="chengyan": return int(member.rank)
	return 0

static func rules(rank: int) -> Dictionary:
	return {"invincible":2.0 if rank>=6 else (1.5 if rank>=4 else 1.0),"recovery":[0.10,0.12,0.15,0.15,0.18,0.20][clampi(rank-1,0,5)]}

static func protected(c: Dictionary) -> bool:
	return float(c.get("chengyan_guard",{}).get("invincible",0.0))>0.0000001

## 返回是否应播放普通受击反馈；触发保命也立即免疫击退与闪红。
static func damage(run: Dictionary, amount: int) -> bool:
	var c: Dictionary=run.combat
	if c.hp<=0 or protected(c): return false
	if not c.has("chengyan_guard"): c.chengyan_guard=fresh()
	var state: Dictionary=c.chengyan_guard
	var rank:=rank_for(run)
	if amount>0 and amount>=c.hp and rank>0 and not state.used:
		var config:=rules(rank)
		state.used=true
		state.invincible=config.invincible
		state.heal_left=5.0
		state.total=float(c.max_hp)*float(config.recovery)
		state.paid=0.0
		c.hp=1.0
		c.hit_velocity=[0.0,0.0]
		c.hit_remaining=0.0
		c.flash_remaining=0.0
		return false
	c.hp=maxf(0.0,float(c.hp)-amount)
	return true

static func advance(c: Dictionary, dt: float) -> void:
	if not c.has("chengyan_guard"): return
	var state: Dictionary=c.chengyan_guard
	if c.hp<=0:
		state.invincible=0.0
		state.heal_left=0.0
		return
	var shield_time:=minf(float(state.invincible),dt)
	state.invincible=maxf(0.0,float(state.invincible)-shield_time)
	var used:=minf(float(state.heal_left),maxf(0.0,dt-shield_time))
	if used<=0.0: return
	state.heal_left=maxf(0.0,float(state.heal_left)-used)
	if state.heal_left<0.0000001: state.heal_left=0.0
	var cumulative:=float(state.total)*(5.0-float(state.heal_left))/5.0
	c.hp=minf(float(c.max_hp),float(c.hp)+maxf(0.0,cumulative-float(state.paid)))
	state.paid=cumulative

static func valid(c: Dictionary) -> bool:
	if not c.has("chengyan_guard"): return true
	var state: Variant=c.chengyan_guard
	if not state is Dictionary or not state.get("used") is bool: return false
	for key in ["invincible","heal_left","total","paid"]:
		var value: Variant=state.get(key)
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value<0: return false
	if state.invincible>2.0 or state.heal_left>5.0 or state.paid>state.total: return false
	if state.total>9007199254740991.0: return false
	if not state.used and (state.invincible>0 or state.heal_left>0 or state.total>0 or state.paid>0): return false
	if state.used and state.total<=0: return false
	if state.invincible>0 and (state.heal_left!=5.0 or state.paid!=0.0): return false
	if state.heal_left>0 and not is_equal_approx(float(state.paid),float(state.total)*(5.0-float(state.heal_left))/5.0): return false
	return true
