extends SceneTree
const Parameters=preload("res://scripts/maze/player_editor.gd")
const Hitstop=preload("res://scripts/maze/axe_hitstop.gd")

func _initialize() -> void:
 if Parameters.hitstop("hero")!=80 or Parameters.hitstop("yaya")!=40 or Parameters.hitstop("tieshan")!=100:
  printerr("角色参数未加载或互相污染")
  quit(1)
  return
 var clock=Hitstop.new()
 clock.configure(Parameters.hitstop("tieshan"))
 clock.configure_ranged(Parameters.hitstop("hero"))
 clock.configure_ranged_kind("hero",Parameters.hitstop("hero"))
 clock.configure_ranged_kind("yaya",Parameters.hitstop("yaya"))
 Hitstop.trigger_ranged(clock.state,"fish","yaya")
 if not is_equal_approx(float(clock.state.ranged_left.fish),0.04):
  printerr("芽芽真实局部时钟未读取40毫秒")
  quit(1)
  return
 Hitstop.trigger(clock.state,1,["frog"])
 if not is_equal_approx(float(clock.state.left),0.1):
  printerr("铁山真实局部时钟未读取100毫秒")
  quit(1)
  return
 clock.configure_ranged(30)
 Hitstop.trigger_ranged(clock.state,"fish","hero")
 if not is_equal_approx(float(clock.state.ranged_left.fish),0.03):
  printerr("旧接口重设远程时钟后未覆盖角色专属窗口")
  quit(1)
  return
 print("PLAYER_SETTINGS_REAL_CLOCK hero=80 yaya=40 tieshan=100")
 quit(0)
