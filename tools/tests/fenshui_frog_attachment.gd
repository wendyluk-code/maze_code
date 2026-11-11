extends "res://tools/tests/fenshui_frog_counter.gd"
## 自然战斗状态进入正式显示；只隔离其他怪以定位身体与保护膜。
const Monster=preload("res://scripts/maze/capture_monster.gd")
var viewport: SubViewport
var samples: Array=[]

func _run() -> void:
 sm=get_node("/root/SaveManager")
 _check(_verify_isolation(),"身体贴合检查使用隔离存档")
 viewport=SubViewport.new()
 viewport.size=Vector2i(960,540)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 get_tree().root.add_child(viewport)
 var image_keys: Dictionary={}
 var heroes: Array=[Vector2(960,500),Vector2(840,500),Vector2(960,400),Vector2(840,400)]
 for i in heroes.size():
  var hero: Vector2=heroes[i]
  var run:=fresh_frog()
  _check(Boss.Roads.is_walkable(hero) and Boss.Roads.terrain_multiplier(hero)<1.0,"四侧样例玩家处于合法浅水："+str(i))
  for step in 100:
   Combat.advance(run,hero,0.02)
   if run.combat.actors[Boss.ID].frog_phase=="airborne": break
  var a: Dictionary=run.combat.actors[Boss.ID]
  _check(a.frog_phase=="airborne","正常追击自然腾空："+str(i))
  if a.frog_phase!="airborne": continue
  for step in 20: Combat.advance(run,hero,0.02)
  var monster: Node2D=Monster.new()
  monster.config=Boss.row()
  viewport.add_child(monster)
  monster.set_process(false)
  monster.sync_action(a,run.combat)
  monster.position=Vector2(240+(i%2)*480,215+(i/2)*250)
  var body: Sprite2D=monster.body
  var bubble: Sprite2D=monster.membrane
  var center:=visible_center(body,monster.facing)
  var error:=center.distance_to(bubble.global_position)
  _check(body.position.y< -25.0,"样例确实位于跳跃高处："+str(i))
  _check(bubble.visible and error<1.0,"保护泡中心贴合腾空身体而非留在地面："+str(i),{"error":error})
  image_keys[hash(body.texture.get_image().get_data())]=true
  samples.append({"hero":str(hero),"phase":a.frog_phase,"facing":monster.facing,"body_center":str(center),"bubble_center":str(bubble.global_position),"error":error})
  # 同一已保存腾空状态的不同剩时用于显示恢复，状态由正常推进产生。
  for step in 8: Combat.advance(run,hero,0.02)
  monster.sync_action(a,run.combat)
  center=visible_center(body,monster.facing)
  _check(center.distance_to(bubble.global_position)<1.0,"下落途中保护泡仍贴身体："+str(i))
 if _arg("--phase=")!="bubble":
  _check(image_keys.size()==4,"玩家位于四侧时，攻击身体实际使用不同朝向图，不仅更新朝向编号",{"distinct_images":image_keys.size()})
 await get_tree().process_frame
 RenderingServer.force_draw(false)
 viewport.get_texture().get_image().save_png(_arg("--output-dir=")+"/attachment.png")
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"samples":samples,"direction_images":image_keys.size(),"direction_check":_arg("--phase=")!="bubble"},"  "))
 get_tree().quit(1 if failures else 0)

func visible_center(body: Sprite2D, direction: int) -> Vector2:
 if direction==0: return body.to_global(body.get_rect().get_center())
 var image: Image=body.texture.get_image()
 var left:=image.get_width()
 var top:=image.get_height()
 var right:=-1
 var bottom:=-1
 for y in image.get_height():
  for x in image.get_width():
   if image.get_pixel(x,y).a<0.5: continue
   left=mini(left,x)
   top=mini(top,y)
   right=maxi(right,x)
   bottom=maxi(bottom,y)
 return body.to_global(body.get_rect().position+Vector2(left+right+1,top+bottom+1)*0.5)
