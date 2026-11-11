extends SceneTree

const Hurt = preload("res://scripts/maze/player_hurt_event.gd")
const Skills = preload("res://scripts/maze/team_attack.gd")
const Fish = preload("res://scripts/maze/silverfish_combat.gd")

func _initialize() -> void:
 var combat := {"region":"fenshui", "hp":9.0, "action":"", "action_left":0.0, "axe_pending":false, "actors":{}, "shots":[]}
 var events: Array=[]
 Hurt.record(combat,10.0,"fish",Vector2.ZERO,Vector2.LEFT,events)
 if not is_equal_approx(float(combat.get("hurt_recovery_left",0.0)),0.8):
  printerr("银鳞鱼真实扣血事务未消费隔离配置：", combat)
  quit(1)
  return
 if not Skills.valid(combat) or not is_equal_approx(Hurt.recovery_time("electric"),0.6):
  printerr("银鳞鱼配置影响其他怪物或真实状态校验")
  quit(1)
  return
 var id:="fenshui_silverfish_1"
 var actor:={"position":[1060.0,450.0],"hp":20.0}
 var fish_combat:={"region":"fenshui","hp":10.0,"hero":[1090.0,450.0],"actors":{id:actor}}
 var run:={"combat":fish_combat,"monsters":{id:{"status":"alive"}}}
 var row:={"id":id,"kind":"silverfish"}
 Fish.advance(run,row,Vector2(1090,450),0.01,{"trigger":180.0},Skills)
 if actor.get("fish_phase")!="warning" or not is_equal_approx(float(actor.get("fish_left",0)),0.95):
  printerr("银鳞鱼真实前摇未读取参数：",actor)
  quit(1)
  return
 print("银鳞鱼真实受击事务采用800毫秒；电鳗仍为600毫秒")
 quit(0)
