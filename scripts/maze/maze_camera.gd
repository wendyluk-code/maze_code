extends Camera2D
const Roads := preload("res://data/maze/entry_roads.gd")
var target: Node2D
var map_size := Roads.SIZE
var roar_shake := 0.0
var shake_clock := 0.0
var mining_shake := 0.0
const ROAR_SWAY_DURATION:=0.7
var roar_visual_left:=0.0
var roar_visual_age:=100.0
var roar_visual_started:=-100.0
var previous_roar_remaining:=0.0
var previous_combat_clock:=-1.0
var roar_paused:=false
var combo_active:=false
var combo_focus:=Vector2.ZERO
var combo_weight:=0.0
var impact_left:=0.0
var impact_strength:=0.0
var combo_last_phase:=""
var combo_last_hits:=0

func set_combo_frame(combat: Dictionary,paused: bool) -> void:
	var a: Dictionary=combat.get("actors",{}).get("salt_pool_rockmane_1",{})
	combo_active=combat.get("region","")=="salt_pool" and combat.get("hp",0)>0 and a.get("hp",0)>0 and a.get("rock_combo",false)
	if combo_active: combo_focus=Vector2(a.position[0],a.position[1])
	var phase: String=a.get("rock_phase","")
	var hits:=int(a.get("rock_combo_released",0))
	if not paused and phase!=combo_last_phase:
		if phase=="lunge" and combo_active:
			impact_left=0.12
			impact_strength=0.8 if hits<4 else 1.4
		elif phase=="stunned" or (phase=="lunge_recover" and a.get("rock_hit",false)):
			impact_left=0.26 if hits>=4 else 0.16
			impact_strength=4.5 if hits>=4 or phase=="stunned" else 2.0
	combo_last_phase=phase
	combo_last_hits=hits
	if paused: offset=Vector2.ZERO

func shake_mining() -> void:
	mining_shake = 0.18

func set_roar_shake(remaining: float, combat_clock: float=-1.0, presentation_paused: bool=false) -> void:
	roar_shake=remaining
	roar_paused=presentation_paused
	if combat_clock>=0.0:
		if combat_clock<previous_combat_clock:
			roar_visual_started=-100.0
			previous_roar_remaining=0.0
		if remaining>0.0 and (previous_roar_remaining<=0.0 or remaining>previous_roar_remaining+0.1): roar_visual_started=combat_clock
		roar_visual_age=maxf(0.0,combat_clock-roar_visual_started)
		roar_visual_left=maxf(0.0,ROAR_SWAY_DURATION-roar_visual_age)
		previous_combat_clock=combat_clock
		previous_roar_remaining=remaining
	else:
		roar_visual_left=remaining
		roar_visual_age=clampf(ROAR_SWAY_DURATION-remaining,0.0,ROAR_SWAY_DURATION)
	if (roar_visual_left<=0.0 or roar_paused) and mining_shake<=0: offset=Vector2.ZERO

func _roar_offset() -> Vector2:
	if roar_visual_left<=0.0 or roar_paused: return Vector2.ZERO
	var envelope:=pow(clampf(roar_visual_left/ROAR_SWAY_DURATION,0.0,1.0),1.35)
	return Vector2(sin(roar_visual_age*24.0)*6.0,sin(roar_visual_age*17.0)*3.0)*envelope

func _notification(what: int) -> void:
	if what==NOTIFICATION_PAUSED: offset=Vector2.ZERO

func _ready() -> void:
	zoom = Vector2.ONE * 1.65
	make_current()
	snap_to_target()

func _process(delta: float) -> void:
	shake_clock+=delta
	offset=_roar_offset()
	mining_shake = maxf(0.0, mining_shake - delta)
	offset += Vector2(sin(shake_clock*109.0), cos(shake_clock*89.0))*2.5*(mining_shake/0.18)
	impact_left=maxf(0.0,impact_left-delta)
	if not roar_paused: offset+=Vector2(sin(shake_clock*65.0),cos(shake_clock*48.0))*impact_strength*minf(1.0,impact_left/0.2)
	combo_weight=lerpf(combo_weight,1.0 if combo_active else 0.0,1.0-exp(-4.0*delta))
	if is_instance_valid(target):
		var focus:=target.global_position
		if combo_weight>0.001: focus+= (combo_focus-target.global_position).limit_length(180.0)*0.32*combo_weight
		global_position = _clamp_position(global_position.lerp(focus, 1.0 - exp(-7.0 * delta)))

func _clamp_position(point: Vector2) -> Vector2:
	# 窗口变大时也确保可见画面不超出原图。
	var viewport_size := get_viewport_rect().size
	var factor := maxf(1.65*(1.0-0.10*combo_weight), maxf(viewport_size.x / map_size.x, viewport_size.y / map_size.y))
	zoom = Vector2.ONE * factor
	var half := viewport_size / zoom * 0.5
	return Vector2(clampf(point.x, half.x, map_size.x - half.x), clampf(point.y, half.y, map_size.y - half.y))

func snap_to_target() -> void:
	combo_active=false
	combo_weight=0.0
	impact_left=0.0
	combo_last_phase=""
	mining_shake = 0.0
	roar_shake=0.0
	roar_visual_started=-100.0
	roar_visual_left=0.0
	previous_roar_remaining=0.0
	previous_combat_clock=-1.0
	offset=Vector2.ZERO
	if is_instance_valid(target):
		global_position = _clamp_position(target.global_position)
		reset_smoothing()
