extends SceneTree

var checks := 0
var failures := 0
var Combat = preload("res://scripts/maze/combat_simulation.gd")
var Catalog = preload("res://data/maze/capture_catalog.gd")
var Roads = preload("res://data/maze/fenshui_roads.gd")
var Rules
const IDS := ["fenshui_silverfish_1", "fenshui_silverfish_2", "fenshui_thunder_eel_1"]

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
 else: print("通过：", message)

func fresh() -> Dictionary:
 var rows: Array = Catalog.all() + Catalog.Fenshui.all()
 var c: Dictionary = Combat.create(3, 100, Vector2(920,440), rows)
 Combat.Skills.ensure(c)
 c.layout = []
 c.region = "fenshui"
 c.fenshui_encounters = true
 c.fs01_trial = true
 var run := {"combat":c,"monsters":{},"members":[],"pending":""}
 for row in rows:
  run.monsters[row.id] = {"status":"skipped","refresh_count":0}
 for id in IDS:
  run.monsters[id].status = "alive"
 c.actors[IDS[0]].position = [920.0,440.0]
 c.actors[IDS[1]].position = [1050.0,440.0]
 c.actors[IDS[2]].position = [980.0,440.0]
 return run

func tick(run: Dictionary, point: Vector2, seconds: float) -> void:
 for i in ceili(seconds / 0.02): Combat.advance(run,point,0.02)

func _initialize() -> void:
 call_deferred("run_tests")

func run_tests() -> void:
 var baseline := fresh()
 tick(baseline,Vector2(920,500),0.02)
 check(baseline.combat.actors[IDS[0]].get("fs_phase", "") == "warning", "真实战斗循环产生锁向冲刺预警")
 if failures:
  quit(1)
  return
 Rules = load("res://scripts/maze/fenshui_borrow_lightning.gd")
 check(Roads.terrain_multiplier(Vector2(920,440)) == 0.65, "保留浅水65%速度")
 check(Rules.conducts(Vector2(920,440),Vector2(980,440)), "局部相通浅水可导电")
 check(not Rules.conducts(Vector2(920,440),Vector2(755,404)), "岸上不导电")
 check(not Rules.conducts(Vector2(920,337),Vector2(1080,337)), "植被岛截断导电")
 check(not Rules.conducts(Vector2(920,440),Vector2(1200,440)), "超出局部范围不导电")
 var run := fresh()
 var fish: Dictionary = run.combat.actors[Rules.IDS[0]]
 tick(run,Vector2(920,500),0.02)
 check(fish.get("fs_phase","") == "warning", "真实战斗入口触发鱼冲刺预警")
 var aim: Array = fish.fs_aim.duplicate()
 tick(run,Vector2(1080,440),0.2)
 check(fish.fs_aim == aim, "预警后锁向不追踪新位置")
 run = fresh()
 run.monsters[Rules.IDS[2]].status = "skipped"
 run.monsters[Rules.IDS[1]].status = "skipped"
 tick(run,Vector2(920,500),1.15)
 check(run.combat.hp < 100, "冲刺轨迹命中玩家")
 run = fresh()
 run.monsters[Rules.IDS[2]].status = "skipped"
 run.monsters[Rules.IDS[1]].status = "skipped"
 tick(run,Vector2(920,500),0.02)
 tick(run,Vector2(850,500),0.95)
 check(run.combat.hp == 100, "横向移动可躲冲刺")
 check(Catalog.Fenshui.water(Combat.vec(run.combat.actors[Rules.IDS[0]].position)), "冲刺结束身体仍完整留水")
 run = fresh()
 run.monsters[Rules.IDS[0]].status = "skipped"
 run.monsters[Rules.IDS[1]].status = "skipped"
 var eel: Dictionary = run.combat.actors[Rules.IDS[2]]
 tick(run,Vector2(980,490),0.02)
 check(eel.get("fs_phase","") == "warning", "雷鳗进入蓄电预警")
 tick(run,Vector2(980,490),1.25)
 check(run.combat.hp == 95, "蓄电结束单次造成现有5点原始伤害")
 tick(run,Vector2(980,490),0.3)
 check(run.combat.hp == 95, "持续电纹不重复伤害")
 var restored: Dictionary = JSON.parse_string(JSON.stringify(run))
 tick(restored,Vector2(980,490),0.3)
 check(restored.combat.hp == 95, "放电后序列化恢复不补发伤害")
 check(Combat.valid(restored.combat), "新阶段可通过现有存档校验")
 run = fresh()
 run.monsters[Rules.IDS[1]].status = "skipped"
 fish = run.combat.actors[Rules.IDS[0]]
 fish.fs_phase = "recover"
 fish.fs_left = 2.0
 fish.mode = "chase"
 tick(run,Vector2(980,490),1.25)
 check(fish.hp == 15, "雷鳗放电伤及水中银鳞鱼，沿用5点攻击")
 run = fresh()
 run.monsters[Rules.IDS[0]].status = "skipped"
 run.monsters[Rules.IDS[1]].status = "skipped"
 tick(run,Vector2(980,490),0.02)
 tick(run,Vector2(755,404),1.25)
 check(run.combat.hp == 100, "蓄电期间上岸可完全避电")
 run = fresh()
 run.combat.fs01_trial = false
 tick(run,Vector2(920,500),0.02)
 check(not run.combat.actors[Rules.IDS[0]].has("fs_phase"), "正常探索不启用试玩规则")
 # 回归：鱼第一次主动预警前先被电，不能使整场探索失效。
 run=fresh()
 run.monsters[Rules.IDS[0]].status="skipped"
 var first_eel: Dictionary=run.combat.actors[Rules.IDS[2]]
 first_eel.fs_phase="warning"
 first_eel.fs_left=0.01
 first_eel.fs_origin=first_eel.position.duplicate()
 first_eel.fs_aim=[0.0,1.0]
 first_eel.fs_hit=false
 tick(run,Vector2(755,404),0.02)
 check(run.combat.actors[Rules.IDS[1]].hp==15,"未发动攻击的鱼先受雷电伤害")
 check(Combat.valid(run.combat),"鱼先被电后的战斗状态仍合法")
 var sm: Node=root.get_node("SaveManager")
 var old_run:=fresh()
 var old_fish: Dictionary=old_run.combat.actors[Rules.IDS[1]]
 old_fish.fs_phase="recover"
 old_fish.fs_left=0.9
 old_fish.hp=15.0
 sm.data["capture_run_v1"]=old_run
 var original_raw: Dictionary=sm.data.duplicate(true)
 var api=load("res://scripts/maze/capture_run.gd")
 var normalized: Dictionary=api.snapshot(sm)
 check(Combat.valid(normalized.combat),"已有缺字段停顿档可恢复为合法战斗")
 check(sm.data==original_raw and normalized.combat.actors[Rules.IDS[1]].hp==15,"读取兼容不写原档不改生命")
 # 非试玩档不应获得阶段字段；错误类型仍由既有校验拒绝。
 old_run.combat.fs01_trial=false
 sm.data["capture_run_v1"]=old_run
 check(api.snapshot(sm)==old_run,"不迁移非试玩档")
 old_run.combat.fs01_trial=true
 old_run.combat.actors[Rules.IDS[1]].fs_aim=null
 sm.data["capture_run_v1"]=old_run
 check(not Combat.valid(api.snapshot(sm).combat),"兼容不吞掉已有字段的错误类型")
 old_run.combat.actors[Rules.IDS[1]].fs_phase="unknown"
 sm.data["capture_run_v1"]=old_run
 check(not Combat.valid(api.snapshot(sm).combat),"兼容不放行未知攻击阶段")
 var visual=load("res://scripts/maze/fenshui_trial_effects.gd").new()
 var times: Array=[]
 for center in [Vector2(1267.45,696.26),Vector2(1267.55,696.26)]:
  var started:=Time.get_ticks_usec()
  visual._water_shape(center)
  times.append((Time.get_ticks_usec()-started)/1000.0)
 check(times.max()<100.0,"首次及位置变化后的电纹计算均低于100毫秒："+str(times))
 visual.free()
 print("FS01：", checks, "项，失败", failures)
 quit(1 if failures else 0)
