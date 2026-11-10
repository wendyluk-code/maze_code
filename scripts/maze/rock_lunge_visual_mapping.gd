extends RefCounted
## 身体只读真实阶段时间，使用48格候选重排动作表，不另有技能计时器。
static func frames(action: String, value: float) -> Dictionary:
 var v:=clampf(value,0.0,3.0)
 var index:=int(v)
 return {"action":action,"frame":index,"next_action":action,"next_frame":mini(3,index+1),"blend":smoothstep(0.0,1.0,v-index),"squash":Vector2.ONE,"angle":0.0}

static func transition(first: String, first_frame: int, second: String, second_frame: int, progress: float) -> Dictionary:
 var out:=frames(first,float(first_frame))
 out.next_action=second
 out.next_frame=second_frame
 out.blend=smoothstep(0.0,1.0,clampf(progress,0.0,1.0))
 return out

static func pose(phase: String, left: float, duration: float, source: Dictionary={}, combo: bool=false, finale: bool=false) -> Dictionary:
 var out:=_target_pose(phase,left,duration,combo,finale)
 if out.is_empty() or source.is_empty(): return out
 out.entry=source
 out.entry_mix=smoothstep(0.0,1.0,clampf((duration-left)/0.14,0.0,1.0))
 var prior_scale: Vector2=source.get("squash",Vector2.ONE)
 out.squash=prior_scale.lerp(out.squash,out.entry_mix)
 out.angle=lerpf(float(source.get("angle",0.0)),float(out.angle),out.entry_mix)
 return out

static func walk(distance_phase: float, source: Dictionary, age: float, moving: bool=true) -> Dictionary:
 var cycle:=fposmod(distance_phase,4.0)
 var out:=frames("swim" if moving else "idle",floorf(cycle) if moving else 0.0)
 out.blend=0.0
 out.next_frame=out.frame
 out.entry=source
 out.entry_mix=smoothstep(0.0,1.0,clampf(age/0.14,0.0,1.0))
 var weight:=sin(cycle*PI)*0.012 if moving else 0.0
 out.squash=Vector2(1.0+weight,1.0-weight*0.65)
 out.angle=weight*0.4
 out.squash=source.get("squash",Vector2.ONE).lerp(out.squash,out.entry_mix)
 return out

static func _target_pose(phase: String, left: float, duration: float, combo: bool=false, finale: bool=false) -> Dictionary:
 if not is_finite(left) or not is_finite(duration) or duration<=0.0: return {}
 var p:=clampf(1.0-left/duration,0.0,1.0)
 if phase=="charge":
  return transition("idle",0,"attack",1,smoothstep(0.0,1.0,p))
 if phase=="lunge_charge":
  var out:=frames("charge",1.5-0.5*cos((duration-left)*TAU*(2.2 if finale else 3.0)))
  out.squash=Vector2(1.0+0.025*p,1.0-0.025*p)
  if phase=="lunge_charge":
   var paw:=sin((duration-left)*TAU*5.0)*0.012*p
   out.squash+=Vector2(paw,-paw*0.65)
   out.angle=paw*0.35
  return out
 if phase=="lunge":
  var out:=transition("rush",0,"brake",0,(p-0.72)/0.28) if p>0.72 else frames("rush",0.0)
  out.squash=Vector2(1.0+0.035*sin(p*PI),1.0-0.025*sin(p*PI))
  return out
 if phase=="lunge_recover":
  if combo:
   return transition("brake",0,"exhausted" if finale else "swim",0,smoothstep(0.35,1.0,p))
  p=clampf((duration-left-0.18)/0.4,0.0,1.0)
  if p>=1.0: return frames("idle",0.0)
  return transition("brake",0,"idle",0,p)
 if phase=="rush": return frames("attack",1.0)
 if phase=="stunned":
  var out:=frames("exhausted",0.0) if left>0.22 else transition("exhausted",0,"idle",0,1.0-left/0.22)
  out.angle=sin(p*TAU*5.0)*0.045*exp(-p*5.0)
  out.squash=Vector2(1.0+0.04*exp(-p*12.0),1.0-0.04*exp(-p*12.0))
  return out
 if phase=="rest":
  var out:=frames("exhausted",0.0) if left>0.3 else transition("exhausted",0,"idle",0,1.0-left/0.3)
  out.squash=Vector2(1.0+0.012*sin(p*TAU*2.0),1.0-0.02*sin(p*TAU*2.0))
  return out
 return {}
