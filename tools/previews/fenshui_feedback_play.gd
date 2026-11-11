extends "res://tools/previews/fenshui_web_play.gd"
## 真实战斗候选入口；不覆盖G版默认入口，不是独立动画编辑器。
var splash: Node2D
var _attack_clicks:=0
const FrogCombat=preload("res://scripts/maze/wind_frog_combat.gd")
const MonsterCombat=preload("res://scripts/maze/monster_combat.gd")

func _prepare_frog() -> bool:
 if not super._prepare_frog(): return false
 maze.capture_flow.player_hurt_visual.enable_refined_pose()
 var frog: Node=maze.capture_flow.monsters["fenshui_wind_frog_1"]
 splash=frog.get_node_or_null("LandingSplashCandidate")
 if not is_instance_valid(splash):
  splash=preload("res://scripts/maze/frog_splash_aligned_visual.gd").new()
  splash.name="LandingSplashCandidate"
  splash.flow=maze.capture_flow
  frog.add_child(splash)
 return true

func _play_message() -> String:
 return "分水庭 · 真实七怪战斗试玩\n巨蛙预警与落地水花跟随当前实际伤害范围。\n已保存的战斗参数由游戏读取；未保存的候选不会自动生效。\nTab锁定切换，Q解除，空格/1/2换招，Ctrl+0满血。\n使用独立试玩存档，不改变正式游戏进度。"

func _play_title() -> String:
 return "料理迷宫 · 分水庭 · 怪物共用战斗 N版试玩"

func _input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  _attack_clicks+=1

func _process(dt: float) -> void:
 super._process(dt)
 if not OS.has_feature("web") or _web_clock!=0.0 or not is_instance_valid(splash): return
 var hurt: Node=maze.capture_flow.player_hurt_visual
 var flow: Node=maze.capture_flow
 var c: Dictionary=flow.display_run().get("combat",{})
 var area: Dictionary=splash.area_snapshot()
 var points: Array=[]
 for point in area.shape: points.append([point.x,point.y])
 var controller: Node=maze.player.combat_controller
 var eligible: Array=[]
 var run: Dictionary=flow.display_run()
 for id in flow.monsters:
  if MonsterCombat.eligible(run,id): eligible.append(id)
 var status:={"version":"20261109-fenshui-production","monster_combat":{"kinds":MonsterCombat.STATS.keys(),"eligible":eligible},"player_combat":{"installed":is_instance_valid(controller),"owned_by_player":is_instance_valid(controller) and controller.get_parent()==maze.player,"enabled":flow.character_combat_enabled()},"candidate":true,"slam_area":{"visible":area.visible,"phase":area.phase,"center":[area.center.x,area.center.y],"shape":points,"alpha":area.alpha},"splash":{"kind":splash.kind,"age":splash.age,"frame":splash.frame,"takeoffs":splash.takeoffs,"landings":splash.landings,"radius":preload("res://scripts/maze/fenshui_electric_area.gd").radius("fenshui_wind_frog_1_slam")},"hurt_pose_refined":hurt.refined_pose,"hurt_direction_frame":hurt.pose_frame,"attack_gate":{"clicks":_attack_clicks,"focused":flow.window_focused,"busy":flow.busy or maze._busy,"combat_paused":flow.combat_paused(),"input_locked":maze.player.input_locked,"save_retry":flow.save_retry_delay,"cooldown":c.get("cooldown",0.0),"action_left":c.get("action_left",0.0),"recovering":flow.player_recovering(),"pending":flow.display_run().get("pending","")}}
 JavaScriptBridge.eval("Object.assign(window.fenshuiStatus,"+JSON.stringify(status)+")",true)
