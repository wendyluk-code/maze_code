extends "res://tools/tests/fenshui_frog_counter_flow.gd"

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"正式分水庭入口恢复输入")
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 if _arg("--phase=")=="editor":
  _check(frog.enable_frog_front24(),"仅在隔离测试中启用编辑器动作")
 await picture("formal-frog")
 var texture: Texture2D=frog.body.texture
 var source: String=texture.atlas.resource_path if texture is AtlasTexture and texture.atlas!=null else texture.resource_path
 var details={"enabled":frog.frog_front24!=null,"texture":source,"body_scale":str(frog.body.scale),"shadow_scale":str(frog.shadow.scale),"config_width":frog.config.width}
 _check(frog.frog_front24!=null and source.ends_with("front24.png"),"正式场景默认使用编辑器双前向动作和体型",details)
