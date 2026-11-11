extends "res://tools/tests/fenshui_borrow_lightning.gd"
const EEL="fenshui_thunder_eel_1"
const FISH="fenshui_silverfish_1"
const FISH2="fenshui_silverfish_2"
const Eel=preload("res://scripts/maze/thunder_eel_combat.gd")
const Fish=preload("res://scripts/maze/silverfish_combat.gd")

func formal() -> Dictionary:
 var run:=fresh()
 run.combat.fs01_trial=false
 for id in run.monsters: run.monsters[id].status="alive" if id in [EEL,FISH,FISH2] else "skipped"
 run.combat.actors[EEL].position=[980.0,440.0]
 for pair in [[FISH,Vector2(930,440)],[FISH2,Vector2(1030,440)]]:
  var a: Dictionary=run.combat.actors[pair[0]]
  a.position=Combat.pack(pair[1])
  a.fish_origin=a.position.duplicate()
  a.fish_aim=[0.0,1.0]
  a.fish_hit=false
  a.fish_phase="recover"
  a.fish_left=2.5
 return run

func run_tests() -> void:
 var run:=formal()
 for id in [EEL,FISH,FISH2]:
  check(Catalog.Fenshui.water(Combat.vec(run.combat.actors[id].position)),"样例身体完整位于正式浅水："+id)
 tick(run,Vector2(980,490),0.02)
 var eel: Dictionary=run.combat.actors[EEL]
 check(eel.get("eel_phase","")=="charging","普通入口开始正式范围蓄电，不依赖试玩标记")
 tick(run,Vector2(980,490),1.0)
 check(run.combat.actors[FISH].hp==20 and run.combat.hp==100,"1.2秒前摇未结束不能提前结算")
 tick(run,Vector2(980,490),0.22)
 check(run.combat.actors[FISH].hp==15 and run.combat.actors[FISH2].hp==15,"一次正式释放分别伤及两条活鱼各5点")
 check(run.combat.hp==95 and eel.hp==30,"玩家沿用原5点伤害，鳗自身免疫")
 tick(run,Vector2(980,490),0.25)
 check(run.combat.actors[FISH].hp==15 and run.combat.hp==95,"余电不重复结算")
 check(Combat.valid(run.combat),"未主动攻击先受电后仍可保存")
 protection_window()
 geometry_and_exclusions()
 recovery_values()
 player_defense_and_shore()
 print("正式范围借电：",checks,"项，失败",failures)
 quit(1 if failures else 0)

func player_defense_and_shore() -> void:
 var run:=formal()
 run.bento={"defense":3}
 release(run)
 check(run.combat.hp==98,"玩家电伤仍经过原防御，5攻击减3防御为2")
 run=formal()
 run.combat.actors[EEL].position=[860.0,485.0]
 var shore:=Vector2(781,475)
 check(Catalog.Fenshui.water(Vector2(860,485)) and Fish.dry(shore) and Vector2(860,485).distance_to(shore)<125,"岸上免电样例在半径内且鳗完整留水")
 release(run,shore)
 check(run.combat.hp==100,"半径内岸上玩家不受水面导电")

func geometry_and_exclusions() -> void:
 var Area=load("res://scripts/maze/fenshui_electric_area.gd")
 var center:=Vector2(980,440)
 var shape: PackedVector2Array=Area.polygon(center,EEL)
 for pair in [[center,true,"中心"],[center+Vector2(124.9,0),true,"临界内"],[center+Vector2(125,0),true,"125边界"],[center+Vector2(125.1,0),false,"临界外"]]:
  check(Catalog.Fenshui.water(pair[0],0),"边界样例先证明是浅水："+pair[2])
  check(Area.contains(shape,pair[0])==pair[1],"共享有效区域："+pair[2])
 # 小岛两侧由地图半径推导；仅依据地形选样例，不按待测导电结果筛绿点。
 var island_pair: Array=[]
 for island in Roads.ISLANDS:
  for i in 16:
   var direction:=Vector2.RIGHT.rotated(TAU*i/16.0)
   var radius:=1.0/sqrt(pow(direction.x/island.z,2)+pow(direction.y/island.w,2))
   var left:=Vector2(island.x,island.y)-direction*(radius+17)
   var right:=Vector2(island.x,island.y)+direction*(radius+17)
   if left.distance_to(right)<=125 and Catalog.Fenshui.water(left) and Catalog.Fenshui.water(right):
    island_pair=[left,right]
    break
  if not island_pair.is_empty(): break
 check(not island_pair.is_empty(),"存在半径125内、两端身体完整留水的小岛遮断样例")
 if not island_pair.is_empty():
  print("小岛遮断输入：",island_pair)
  check(not Area.contains(Area.polygon(island_pair[0],EEL),island_pair[1]),"半径内小岛同时截断有效区域与命中")
 var Gate=load("res://data/maze/fenshui_gates.gd")
 for gate in Gate.GATES:
  var point: Vector2=Gate.center(gate)
  check(not Area.contains(Area.polygon(point,EEL),point),"栅栏本体不成为导电起点或命中面："+gate.name)
 var run:=formal()
 var same="fenshui_thunder_eel_2"
 run.monsters[same].status="alive"
 run.combat.actors[same].position=[980.0,390.0]
 run.combat.actors[same].cooldown=10.0
 run.monsters[FISH2].status="captured"
 release(run)
 check(run.combat.actors[same].hp==30 and run.combat.actors[FISH2].hp==20,"同类鳗免疫，已捕获鱼排除")
 run=formal()
 run.combat.actors[FISH].hp=0.0
 release(run)
 check(run.combat.actors[FISH].hp==0 and not run.combat.actors[FISH].has("electric_left"),"已死鱼不重结算或添加破膜")

func recovery_values() -> void:
 var run:=formal()
 check(Combat.valid(run.combat),"旧正式档缺破膜字段可继续")
 release(run)
 var copy: Dictionary=JSON.parse_string(JSON.stringify(run))
 check(Combat.valid(copy.combat),"已释放与破膜状态可JSON恢复")
 for bad in ["4",-0.1,4.01,NAN]:
  copy=run.duplicate(true)
  copy.combat.actors[FISH].electric_left=bad
  check(not Combat.valid(copy.combat),"拒绝损坏破膜剩时："+str(bad))
 for bad in ["1",-1,0.5,NAN]:
  copy=run.duplicate(true)
  copy.combat.electric_serial=bad
  check(not Combat.valid(copy.combat),"拒绝损坏放电序号："+str(bad))

func release(run: Dictionary, hero: Vector2=Vector2(980,490)) -> void:
 var a: Dictionary=run.combat.actors[EEL]
 if not a.has("eel_phase"): Combat.advance(run,hero,0.02)
 a.eel_phase="charging"
 a.eel_left=0.01
 a.cooldown=2.0
 Combat.advance(run,hero,0.02)

func protection_window() -> void:
 var run:=formal()
 release(run)
 check(is_equal_approx(float(run.combat.actors[FISH].get("electric_left",0)),4.0) and is_equal_approx(float(run.combat.actors[FISH2].get("electric_left",0)),4.0),"同次多鱼破膜均完整4秒，不受遍历先后影响")
 var a: Dictionary=run.combat.actors[FISH]
 a.fish_phase="forming"
 a.fish_left=1.0
 run.monsters[EEL].status="skipped"
 tick(run,Vector2(1560,218),1.1)
 var hp: float=a.hp
 Combat.Skills.damage(run,FISH,8)
 check(a.hp==hp-8 and not Fish.shielded(run.combat,FISH),"回水1秒凝膜结束仍处破膜窗口，承受完整8点")
 run.monsters[EEL].status="alive"
 release(run)
 check(is_equal_approx(float(a.get("electric_left",0)),4.0),"再次受电刷新4秒，不叠加剩余时间")
 run.monsters[EEL].status="skipped"
 # 独立活鱼验证窗口到期，不让前述伤害把样例提前击败。
 a=run.combat.actors[FISH2]
 a.fish_phase="forming"
 a.fish_left=1.0
 tick(run,Vector2(1560,218),3.9)
 check(not Fish.shielded(run.combat,FISH2),"破膜4秒到期前不恢复保护")
 tick(run,Vector2(1560,218),0.12)
 hp=a.hp
 Combat.Skills.damage(run,FISH2,8)
 check(a.hp==hp-2 and Fish.shielded(run.combat,FISH2),"破膜到期后水中保护恢复为25%承伤")
