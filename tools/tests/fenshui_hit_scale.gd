extends "res://tools/tests/ch2_entry_state.gd"
const Monster=preload("res://scripts/maze/capture_monster.gd")
const Boss=preload("res://data/maze/fenshui_boss.gd")
const Fenshui=preload("res://data/maze/fenshui_encounters.gd")
var viewport: SubViewport
var output: String
var samples: Array=[]

func _run() -> void:
 sm=get_node("/root/SaveManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"固定尺寸检查隔离用户存档")
 viewport=SubViewport.new()
 viewport.size=Vector2i(256,256)
 viewport.transparent_bg=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 get_tree().root.add_child(viewport)
 var frog=Monster.new()
 frog.config=Boss.row()
 frog.config.position=Vector2(128,158)
 viewport.add_child(frog)
 frog.set_process(false)
 frog.enable_hit_feedback()
 _check(frog.hit_visual.get("watercolor_sheet") is Texture2D,"生产消费者实际安装已确认水彩三格，不再只画程序笔触")
 if frog.hit_visual.get("watercolor_sheet") is Texture2D:
  var source:=Image.load_from_file("res://output/hit-watercolor-demo/effects-candidate.png")
  var installed: Image=frog.hit_visual.watercolor_sheet.get_image()
  _check(source.get_data()==installed.get_data(),"生产水彩与用户确认原图逐像素一致，不偷换图")
 for child in frog.get_children():
  if child is CanvasItem and child!=frog.hit_visual: child.hide()
 var baseline: Dictionary={}
 for kind in ["hero","yaya","tieshan"]:
  baseline[kind]=await contact(frog,kind)
 _check(frog.enable_frog_front24(),"从生产节点启用已确认1.4倍身体")
 for kind in ["hero","yaya","tieshan"]:
  var enlarged: Image=await contact(frog,kind)
  compare(baseline[kind],enlarged,"body_140_"+kind)
  frog.body.material.set_shader_parameter("impact_scale",Vector2(1.6,0.6))
  var deformed: Image=await capture()
  compare(enlarged,deformed,"body_deformation_"+kind)
 # 同一生产节点按反向安装顺序仍不能将体型倍率传给接触图形。
 frog.hit_visual.queue_free()
 frog.hit_visual=null
 await get_tree().process_frame
 frog.enable_hit_feedback()
 for kind in ["hero","yaya","tieshan"]:
  compare(baseline[kind],await contact(frog,kind),"installed_after_140_"+kind)
 await compare_fish(frog)
 await compare_body_height(frog)
 await compare_non_frog_height(frog)
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"samples":samples},"  "))
 get_tree().quit(1 if failures else 0)

func compare_fish(frog: Node2D) -> void:
 var fish=Monster.new()
 fish.config=Fenshui.all()[0]
 fish.config.position=Vector2(128,158)
 viewport.add_child(fish)
 fish.set_process(false)
 fish.enable_hit_feedback()
 for child in fish.get_children():
  if child is CanvasItem and child!=fish.hit_visual: child.hide()
 for kind in ["hero","yaya","tieshan"]:
  for age in [0.035,0.075,0.13]:
   for protected in [false,true]:
    frog.hide()
    fish.show()
    var reference: Image=await contact(fish,kind,age,protected)
    fish.hide()
    frog.show()
    var actual: Image=await contact(frog,kind,age,protected)
    compare(reference,actual,"fish_frog_"+kind+"_"+str(age)+"_"+str(protected))
 fish.queue_free()

func compare_body_height(frog: Node2D) -> void:
 for kind in ["hero","yaya","tieshan"]:
  frog.body.position.y=0.0
  var reference: Image=await contact(frog,kind,0.045,true)
  var before: Rect2i=reference.get_used_rect()
  for height in [-36.0,-28.0,-16.0,0.0]:
   frog.body.position.y=height
   frog.hit_visual.advance(0.0)
   var actual: Image=await capture()
   var after: Rect2i=actual.get_used_rect()
   _check(after.position==before.position+Vector2i(0,int(height)) and after.size==before.size,"巨蛙短效跟随当前腾空/翻落高度，尺寸不变："+kind+str(height),{"before":str(before),"after":str(after)})
   _check(reference.get_region(before).get_data()==actual.get_region(after).get_data(),"高度补偿只平移笔触，不变形或缩放："+kind+str(height))
 frog.body.position.y=0.0

func compare_non_frog_height(frog: Node2D) -> void:
 frog.hide()
 for kind in ["silverfish","thunder_eel"]:
  var monster=Monster.new()
  monster.config=Fenshui.all().filter(func(row): return row.kind==kind)[0].duplicate(true)
  monster.config.position=Vector2(128,158)
  viewport.add_child(monster)
  monster.set_process(false)
  monster.enable_hit_feedback()
  for child in monster.get_children():
   if child is CanvasItem and child!=monster.hit_visual: child.hide()
  var reference: Image=await contact(monster,"hero",0.045,true)
  monster.body.position.y=-20.0
  monster.hit_visual.advance(0.0)
  var actual: Image=await capture()
  _check(reference.get_data()==actual.get_data(),"鱼鳗不套用巨蛙垂直挂点："+kind)
  monster.queue_free()
  await get_tree().process_frame
 frog.show()

func contact(frog: Node2D,kind: String,age: float=0.045,protected: bool=false) -> Image:
 var visual: Node2D=frog.hit_visual
 visual.clear()
 visual.receive({"kind":kind,"point":[128.0,158.0],"direction":[1.0,0.0],"protected":protected})
 visual.advance(age)
 return await capture()

func capture() -> Image:
 await get_tree().process_frame
 RenderingServer.force_draw(false)
 return viewport.get_texture().get_image()

func compare(before: Image,after: Image,label: String) -> void:
 var a:=before.get_used_rect()
 var b:=after.get_used_rect()
 _check(a.size.x>0 and a.size.y>0,"实际绘制非空接触图形："+label)
 _check(a==b and before.get_data()==after.get_data(),"接触图形不随身体放大或形变："+label,{"before":str(a),"after":str(b)})
 samples.append({"case":label,"before":str(a),"after":str(b)})
 before.save_png(output+"/"+label+"_baseline.png")
 after.save_png(output+"/"+label+"_actual.png")
