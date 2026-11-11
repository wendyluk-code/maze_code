extends Node
## 隔离试玩的档位和相同条件重置，不装入正式场景。
const Hitstop=preload("res://scripts/maze/axe_hitstop.gd")
const Run=preload("res://scripts/maze/capture_run.gd")
const DURATIONS=[0,40,70]
var maze: Node2D
var baseline: Dictionary
var choice:=0
var hint: Label
var heal_button: Button
var tool_status: Label
var ranged_trial:=false

func durations() -> Array:
 return [0,30,50] if ranged_trial else DURATIONS

func _configure_clock() -> void:
 maze.capture_flow.axe_hitstop.configure(70 if ranged_trial else DURATIONS[choice])
 if ranged_trial: maze.capture_flow.axe_hitstop.configure_ranged(durations()[choice])

func attach(target: Node2D) -> void:
 maze=target
 baseline=SaveManager.data.duplicate(true)
 maze.capture_flow.axe_hitstop=Hitstop.new()
 var layer:=CanvasLayer.new()
 layer.layer=100
 add_child(layer)
 hint=preload("res://scripts/ui/components/feedback_toast.gd").new()
 hint.position=Vector2(280,76)
 hint.add_theme_font_size_override("font_size",15)
 layer.add_child(hint)
 # 只复用提示样式，说明常驻，不再用短暂提示的自动隐藏计时。
 hint.set_process(false)
 heal_button=SproutButton.new().set_icon_visible(false).set_focus_visual(false)
 layer.add_child(heal_button)
 heal_button.position=Vector2(280,162)
 heal_button.custom_minimum_size=Vector2(170,42)
 heal_button.size=Vector2(170,42)
 heal_button.add_theme_font_size_override("font_size",17)
 heal_button.focus_mode=Control.FOCUS_NONE
 heal_button.pressed.connect(_tool_pressed)
 tool_status=Label.new()
 tool_status.position=Vector2(465,171)
 tool_status.theme=SproutTheme.make_theme()
 tool_status.add_theme_font_size_override("font_size",14)
 tool_status.add_theme_color_override("font_color",SproutTheme.CREAM)
 tool_status.add_theme_color_override("font_outline_color",SproutTheme.INK)
 tool_status.add_theme_constant_override("outline_size",3)
 tool_status.mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(tool_status)
 maze.tree_exited.connect(_maze_exited)
 get_tree().scene_changed.connect(_scene_changed)
 reset()

func active_trial() -> bool:
 if not is_instance_valid(maze) or maze.is_queued_for_deletion() or maze.get("region_id")!="fenshui": return false
 var run: Dictionary=Run.snapshot(SaveManager)
 if not run.get("active",false) or run.get("combat",{}).get("region","")!="fenshui": return false
 for id in baseline[Run.KEY].monsters:
  if baseline[Run.KEY].monsters[id].status=="skipped" and run.monsters.get(id,{}).get("status","")!="skipped": return false
 return true

func _maze_exited() -> void:
 maze=null
 _update_hint()
 _scene_changed.call_deferred()

func _scene_changed() -> void:
 var current: Node=get_tree().current_scene
 if is_instance_valid(current) and not current.is_queued_for_deletion() and current.has_method("show_toast") and current.get("region_id")=="fenshui":
  maze=current
  if not maze.tree_exited.is_connected(_maze_exited): maze.tree_exited.connect(_maze_exited)
  if active_trial():
   maze.capture_flow.axe_hitstop=Hitstop.new()
   _configure_clock()
   tool_status.text="已重载对照，档位保持不变"
 else:
  maze=null
 _update_hint()

func _update_hint() -> void:
 hint.show()
 heal_button.show()
 if not active_trial():
  hint.text="已离开卡肉对照（本窗口仍为隔离试玩）\n点击返回对照或按F6，将重置这次体验。\n其他地图不启用本对照的停顿时钟。"
  heal_button.text="返回卡肉对照"
  tool_status.text="当前不是对照地图，不能给正式怪物回血"
  return
 var label: String=["无停顿","轻停顿","较明显停顿"][choice]
 if ranged_trial:
  hint.text="远程卡肉对照 · %s（%d毫秒）　F5切档／F6重置\n空格锅铲／1芽芽／2铁山70毫秒；左键攻击。\n怪物回满血按钮：活体只回血；倒地或捕获后会重置对照。" % [label,durations()[choice]]
 else:
  hint.text="铁山卡肉对照 · %s（%d毫秒）　F5切档并重置\n按2选择铁山，左键挥斧；F6重置站位与生命。\n怪物回满血按钮：活体只回血；倒地或捕获后会重置对照。" % [label,DURATIONS[choice]]
 heal_button.text="怪物回满血"

func _tool_pressed() -> void:
 if not active_trial():
  return_to_trial()
  return
 var run: Dictionary=Run.snapshot(SaveManager)
 var ids: Array=[]
 for id in baseline[Run.KEY].monsters:
  if baseline[Run.KEY].monsters[id].status!="alive": continue
  if run.monsters[id].status!="alive" or run.combat.actors[id].hp<=0:
   reset()
   tool_status.text="目标已倒地或捕获：已重置站位，当前档位不变"
   return
  ids.append(id)
 var before: Dictionary=SaveManager.data.duplicate(true)
 for id in ids: run.combat.actors[id].hp=Run.Combat.STATS[maze.capture_flow.monsters[id].config.kind].hp
 SaveManager.data[Run.KEY]=run
 if not SaveManager.save():
  SaveManager.data=before
  tool_status.text="回血保存失败，状态未改变"
  return
 tool_status.text="怪物已回满血；玩家站位、档位及其他状态不变"

func return_to_trial() -> void:
 var before: Dictionary=SaveManager.data.duplicate(true)
 SaveManager.data=baseline.duplicate(true)
 if not SaveManager.save():
  SaveManager.data=before
  tool_status.text="返回保存失败，状态未改变"
  return
 get_tree().change_scene_to_file("res://scenes/maze_fenshui.tscn")

func _input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode not in [KEY_F5,KEY_F6]: return
 get_viewport().set_input_as_handled()
 if not active_trial():
  if event.keycode==KEY_F6: return_to_trial()
  return
 if event.keycode==KEY_F5: choice=(choice+1)%durations().size()
 reset()

func reset() -> void:
 var flow: Node=maze.capture_flow
 var selected: int=int(Run.snapshot(SaveManager).combat.get("selected",0))
 flow.set_process(false)
 if maze.map_ui.expanded: maze.map_ui.close_map()
 flow.dialog.hide()
 flow.attempt.close()
 flow.reward.hide()
 flow.busy=false
 flow.resolving=false
 flow.current=""
 flow.death_presented=false
 flow.save_retry_delay=0.0
 flow.combat_time=0.0
 flow.hero_flash_display_remaining=0.0
 flow.monster_flash_display.clear()
 _configure_clock()
 maze._busy=false
 maze.player.input_locked=false
 maze.player.set_physics_process(true)
 maze.player.clear_combat_input()
 SaveManager.data=baseline.duplicate(true)
 Run.Combat.Skills.ensure(SaveManager.data[Run.KEY].combat)
 if ranged_trial: SaveManager.data[Run.KEY].combat.selected=selected
 maze.player.position=Run.Combat.vec(baseline[Run.KEY].combat.hero)
 maze.camera.snap_to_target()
 for monster in flow.monsters.values():
  monster.action_paused=false
  monster.action_time=0.0
  monster.elapsed=0.0
  monster.wake_rings.clear()
 SaveManager.save()
 flow.set_process(true)
 _update_hint()
 tool_status.text="相同站位和生命已重置；当前档位保持"
