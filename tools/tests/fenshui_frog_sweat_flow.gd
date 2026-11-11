extends "res://tools/tests/fenshui_return_water_flow.gd"

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"汗滴尺寸检查由真实七怪入口开始")
 if failures: return
 await frog_return()

func picture(label: String) -> void:
 if label!="frog_return_crossing":
  await super.picture(label)
  return
 var node: Node=maze.capture_flow.monsters[Boss.ID]
 var sweat: Node2D=node.return_water_visual
 _check(await until_true(func(): return sweat.clock>0.0,0.5),"真实显示时钟已推进并计算汗滴尺寸与锚点")
 if failures: return
 # 固定显示时钟仅用于前后尺寸比较；实际腾空、身体姿态与位置均来自本次战斗。
 node.set_process(false)
 sweat.clock=0.12
 sweat.queue_redraw()
 await super.picture("frog_sweat")
 trace.append({"sweat_ratio":sweat.size_ratio,"radius":5.7*sweat.size_ratio,"body_scale":str(node.body.scale),"anchor":str(sweat.position),"actor":actor()})
 _check(is_equal_approx(float(sweat.size_ratio),100.0/108.0),"巨蛙汗滴沿100基础宽度，不乘身体额外1.4倍")
 _check(node.frog_front24!=null and sweat.visible,"缩小汗滴不撤掉1.4倍新身体或真实回水表现")
 node.set_process(true)
