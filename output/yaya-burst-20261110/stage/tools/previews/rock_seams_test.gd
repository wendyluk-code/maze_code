extends "res://tools/tests/ch2_entry_state.gd"
const Motion=preload("res://scripts/maze/rock_lunge_visual_mapping.gd")
func weights(p: Dictionary) -> Dictionary:
 if p.has("entry") and float(p.get("entry_mix",1.0))==0.0: return weights(p.entry)
 var out: Dictionary={}
 var blend:=float(p.get("blend",0.0))
 var first: String=str(p.action)+":"+str(p.frame)
 var second: String=str(p.next_action)+":"+str(p.next_frame)
 if 1.0-blend>0.000001: out[first]=1.0-blend
 if blend>0.000001: out[second]=float(out.get(second,0.0))+blend
 return out
func _run() -> void:
 for seam in [["lunge_charge",1.2,"lunge",0.45],["lunge",0.45,"lunge_recover",2.0],["lunge_recover",2.0,"rest",5.0],["charge",1.1,"rush",0.45],["rush",0.45,"lunge_charge",1.0]]:
  var first: Dictionary=Motion.pose(seam[0],0.0,seam[1])
  var next: Dictionary=Motion.pose(seam[2],seam[3],seam[3],first)
  _check(weights(first)==weights(next),"阶段切换不得瞬间换姿态："+seam[0]+"→"+seam[2])
 var audit: Array=[]
 _check(Motion.pose("rest",4.0,5.0).action=="exhausted","力竭使用独立低伏姿态")
 _check(Motion.pose("stunned",1.0,1.5).action=="exhausted","撞晕使用低伏姿态")
 _check(Motion.pose("lunge_recover",1.8,2.0).action=="brake","冲撞后使用制动姿态")
 for action in ["idle","swim","charge","rush","brake","attack","exhausted","defeated"]:
  var img: Image=load("res://assets/monsters/rockmane_candidate48/"+action+".png").get_image()
  var side:=img.get_width()/4
  _check(img.get_width()==724 and img.get_height()==724,"四向四格动作表尺寸："+action)
  var cells: Array=[]
  for row in 4:
   for col in 4:
    var rect:=img.get_region(Rect2i(col*side,row*side,side,side)).get_used_rect()
    _check(rect.has_area(),"四向动作槽位非空："+action+"/"+str(row)+"/"+str(col))
    cells.append([row,col,rect.position.x,rect.position.y,rect.size.x,rect.size.y])
  audit.append({"action":action,"size":[img.get_width(),img.get_height()],"cells":cells})
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"source_bounds":audit},"  "))
 print("ROCK_SEAMS ",checks," checks; failures=",failures)
 get_tree().quit(1 if failures else 0)
