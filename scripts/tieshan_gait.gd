extends Node2D
## Independently generated leg parts. Transform-only animation keeps pixels intact.
const BODY_SCALE := 0.1788
const NEAR_HIP := Vector2(-7, -55)
const FAR_HIP := Vector2(13, -55)
const LEG_SOURCE_PIVOT := Vector2(380,190)
const LEG_SOURCE_FOOT := Vector2(365,664)
const BOOT_SOLE_LOCAL := Vector2(-20,184)
const CYCLE_SECONDS := 1.2
const STANCE_FRACTION := 0.64
const STRIDE := 24.0
var body: Sprite2D
var near_leg: Sprite2D
var far_leg: Sprite2D
var near_pants: Sprite2D
var far_pants: Sprite2D
var sheet: Texture2D
var heading := Vector2.LEFT
var phase := 0.0
var near_contact := false
var far_contact := false
var near_world_foot := Vector2.ZERO
var far_world_foot := Vector2.ZERO
var lock_contacts := false
var _was_near_contact := false
var _was_far_contact := false
var _near_plant := Vector2.ZERO
var _far_plant := Vector2.ZERO
var _near_swing_start := Vector2.ZERO
var _far_swing_start := Vector2.ZERO
var _near_swing_end := Vector2.ZERO
var _far_swing_end := Vector2.ZERO
var _near_swung := false
var _far_swung := false

func _ready() -> void:
	sheet = preload("res://assets/characters/tieshan/tieshan_walk_parts.png")
	far_pants = _part(2, false)
	far_leg = _part(2, true)
	near_pants = _part(1, false)
	near_leg = _part(1, true)
	body = _part(0)
	body.scale = Vector2.ONE * BODY_SCALE
	body.offset = -Vector2(450,861)
	pose(0.0)

func _part(index: int, boot := false) -> Sprite2D:
	var part := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(index * 724,0,724,724)
	if index > 0:
		atlas.region = Rect2(index * 724,440,724,284) if boot else Rect2(index * 724,0,724,490)
	part.texture = atlas
	part.use_parent_material = true
	part.centered = false
	if index > 0:
		part.offset = -Vector2(385,40) if boot else -LEG_SOURCE_PIVOT
	add_child(part)
	return part

func pose(cycle: float) -> void:
	phase = fposmod(cycle,1.0)
	near_world_foot = _pose_leg(near_leg, NEAR_HIP, phase, true)
	far_world_foot = _pose_leg(far_leg, FAR_HIP, fposmod(phase + 0.5,1.0), false)
	near_contact = phase < STANCE_FRACTION
	far_contact = fposmod(phase + 0.5,1.0) < STANCE_FRACTION
	body.position.y = sin(phase * TAU * 2.0) * 0.35

func reset_gait() -> void:
	_was_near_contact = false
	_was_far_contact = false
	_near_swung = false
	_far_swung = false
	_near_plant = Vector2.ZERO
	_far_plant = Vector2.ZERO
	_near_swing_start = Vector2.ZERO
	_far_swing_start = Vector2.ZERO
	_near_swing_end = Vector2.ZERO
	_far_swing_end = Vector2.ZERO
	near_contact = false
	far_contact = false
	phase = 0.0

func _pose_leg(leg: Sprite2D, hip: Vector2, leg_phase: float, near: bool) -> Vector2:
	var progress := 0.0
	var lift := 0.0
	if leg_phase < STANCE_FRACTION:
		progress = lerpf(-STRIDE * 0.5, STRIDE * 0.5, leg_phase / STANCE_FRACTION)
	else:
		var swing := (leg_phase - STANCE_FRACTION) / (1.0 - STANCE_FRACTION)
		progress = lerpf(STRIDE * 0.5, -STRIDE * 0.5, smoothstep(0.0,1.0,swing))
		lift = -sin(swing * PI) * 7.0
	var target := -heading.normalized() * progress + Vector2(hip.x * 0.22,lift)
	if lock_contacts:
		var contact := leg_phase < STANCE_FRACTION
		var was_contact := _was_near_contact if near else _was_far_contact
		if contact and not was_contact:
			if near:
				_near_plant = _near_swing_end if _near_swung else to_global(target)
			else:
				_far_plant = _far_swing_end if _far_swung else to_global(target)
		if not contact and was_contact:
			var remaining_travel := STRIDE / STANCE_FRACTION * (1.0 - STANCE_FRACTION)
			var landing := to_global(heading.normalized() * (STRIDE * 0.5 + remaining_travel) + Vector2(hip.x * 0.22,0))
			if near:
				_near_swing_start = _near_plant
				_near_swing_end = landing
				_near_swung = true
			else:
				_far_swing_start = _far_plant
				_far_swing_end = landing
				_far_swung = true
		if contact:
			target = to_local(_near_plant if near else _far_plant)
		else:
			var swing_phase := (leg_phase - STANCE_FRACTION) / (1.0 - STANCE_FRACTION)
			var swing_start := _near_swing_start if near else _far_swing_start
			var swing_end := _near_swing_end if near else _far_swing_end
			target = to_local(swing_start.lerp(swing_end,smoothstep(0.0,1.0,swing_phase))) + Vector2(0,lift)
		if near:
			_was_near_contact = contact
		else:
			_was_far_contact = contact
	# Boots stay rigid and broad; only the trouser section changes length.
	# Keeping a flat sole during stance prevents a rotated whole leg from skating.
	var boot_scale := 0.15
	var boot_sole := Vector2(365,224)
	var boot_pivot := Vector2(385,40)
	leg.scale = Vector2.ONE * boot_scale
	leg.rotation = 0.0
	leg.position = target - (boot_sole - boot_pivot) * boot_scale
	var pants := near_pants if near else far_pants
	var pants_source := Vector2(385,477) - LEG_SOURCE_PIVOT
	var pants_target := leg.position - hip
	var pants_scale := Vector2(0.15, pants_target.length() / pants_source.length())
	pants.position = hip
	pants.scale = pants_scale
	pants.rotation = (pants_source * pants_scale).angle_to(pants_target)
	return to_global(target)
