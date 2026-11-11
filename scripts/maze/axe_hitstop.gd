extends RefCounted
## 仅隔离对照安装；局部时钟在内存中，随成功探索事务一起采用。
var state: Dictionary={}

func configure(milliseconds: int) -> void:
 state={"duration":float(milliseconds)/1000.0,"left":0.0,"ids":[],"serial":-1,"step_held":0.0,"step_ids":[]}

func configure_ranged(milliseconds: int) -> void:
 state.ranged_duration=float(milliseconds)/1000.0
 state.ranged_kinds={}
 state.ranged_left={}
 state.ranged_step={}

func configure_ranged_kind(kind: String, milliseconds: int) -> void:
 if not state.has("ranged_kinds"): state.ranged_kinds={}
 state.ranged_kinds[kind]=float(milliseconds)/1000.0

func paused(id: String) -> bool:
 return (float(state.get("left",0.0))>0.000001 and id in state.get("ids",[])) or (float(state.get("step_held",0.0))>0.000001 and id in state.get("step_ids",[])) or float(state.get("ranged_left",{}).get(id,0.0))>0.000001 or float(state.get("ranged_step",{}).get(id,0.0))>0.000001

func advance_wait(dt: float) -> void:
 # 击倒后原流程等待倒地动画，不推进战斗事务；停顿不能把该等待锁死。
 begin_step(state,dt)

static func begin_step(clock: Dictionary, dt: float) -> void:
 if clock.is_empty(): return
 clock.step_held=minf(float(clock.left),dt)
 clock.step_ids=clock.ids.duplicate() if clock.step_held>0.000001 else []
 clock.left=maxf(0.0,float(clock.left)-dt)
 if clock.left<=0.000001: clock.ids=[]
 if clock.has("ranged_left"):
  clock.ranged_step={}
  for id in clock.ranged_left.keys():
   clock.ranged_step[id]=minf(float(clock.ranged_left[id]),dt)
   clock.ranged_left[id]=maxf(0.0,float(clock.ranged_left[id])-dt)
   if clock.ranged_left[id]<=0.000001: clock.ranged_left.erase(id)

static func action_delta(clock: Dictionary, dt: float) -> float:
 return maxf(0.0,dt-float(clock.get("step_held",0.0)))

static func actor_delta(clock: Dictionary, id: String, dt: float) -> float:
 var held: float=float(clock.get("step_held",0.0)) if id in clock.get("step_ids",[]) else 0.0
 return maxf(0.0,dt-maxf(held,float(clock.get("ranged_step",{}).get(id,0.0))))

static func trigger_ranged(clock: Dictionary, id: String, kind: String="") -> void:
 var duration: float=float(clock.get("ranged_kinds",{}).get(kind,clock.get("ranged_duration",0.0)))
 if duration<=0.0: return
 # 同目标已停顿时只结算伤害，不刷新截止，防止同时多弹累加锁定。
 if float(clock.ranged_left.get(id,0.0))>0.000001 or float(clock.get("ranged_step",{}).get(id,0.0))>0.000001: return
 clock.ranged_left[id]=duration

static func trigger(clock: Dictionary, serial: int, ids: Array) -> void:
 if clock.is_empty() or float(clock.duration)<=0.0 or ids.is_empty() or int(clock.serial)==serial: return
 clock.left=clock.duration
 clock.ids=ids.duplicate()
 clock.serial=serial
