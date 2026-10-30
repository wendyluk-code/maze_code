extends "res://tools/tests/fenshui_area_flow.gd"

func _draw_samples() -> void:
 await _reset(Vector2(1040,490))
 maze.capture_flow.set_process(false)
 var captures: Array[Image]=[]
 for sample in [["charging",1.2,"bright"],["charging",0.95,"dim"],["discharge",0.35,"release"],["discharge",0.15,"spread"],["recover",1.0,"ended"]]:
  var run: Dictionary=Run.snapshot(sm)
  for id in [EEL,"fenshui_thunder_eel_2"]:
   var a: Dictionary=run.combat.actors[id]
   a.eel_origin=a.position.duplicate()
   a.eel_path=[]
   a.eel_phase=sample[0]
   a.eel_left=sample[1]
   a.mode="chase"
   a.windup=0.0
  run.combat.actors[FISH].electric_left=4.0 if sample[2]=="release" else 0.0
  sm.data[Run.KEY]=run
  await get_tree().process_frame
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  captures.append(get_viewport().get_texture().get_image())
  await _image("vfx_"+sample[2])
 _check(captures[0].get_data()!=captures[1].get_data(),"蓄电明暗时点真实画面不同")
 _check(captures[2].get_data()!=captures[4].get_data(),"释放与结束真实画面不同")
