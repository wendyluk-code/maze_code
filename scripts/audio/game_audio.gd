extends Node
## 有效 E 交互、全局鼠标点击及实际结果音效；不读写游戏存档。
signal cue_played(cue: StringName)
const Mix = preload("res://scripts/audio/audio_mix.gd")
var mix := Mix.new()
var _mix_poll := 0.0
const STREAMS := {
	# 复用交付素材，独立播放器避免接单重启正在播放的料理提示序列。
	&"order_accepted": preload("res://assets/audio/sfx/serve_correct.wav"),
	&"food_enjoy": preload("res://assets/audio/sfx/food_enjoy.wav"),
	&"water_enjoy": preload("res://assets/audio/sfx/water_enjoy.wav"),
	&"customer_seated": preload("res://assets/audio/sfx/customer_seated.wav"),
	&"party_join": preload("res://assets/audio/sfx/party_join.wav"),
	&"yaya_home_hint": preload("res://assets/audio/sfx/yaya_home_hint.wav"),
	&"yaya_maze_hint": preload("res://assets/audio/sfx/yaya_maze_hint.wav"),
	&"business_complete": preload("res://assets/audio/sfx/business_complete.wav"),
	&"hit_01": preload("res://assets/audio/sfx/character/hit_01.wav"),
	&"hit_02": preload("res://assets/audio/sfx/character/hit_02.wav"),
	&"hit_03": preload("res://assets/audio/sfx/character/hit_03.wav"),
	&"hero_hurt": preload("res://assets/audio/sfx/character/hero_hurt.wav"),
	&"customer_arrival": preload("res://assets/audio/sfx/customer_arrival.wav"),
	&"failure": preload("res://assets/audio/sfx/failure_user.wav"),
	&"capture_throw": preload("res://assets/audio/sfx/capture_throw.wav"),
	&"capture_press": preload("res://assets/audio/sfx/capture_press.wav"),
	&"attack_01": preload("res://assets/audio/sfx/character/attack_01.wav"),
	&"attack_02": preload("res://assets/audio/sfx/character/attack_02.wav"),
	&"attack_03": preload("res://assets/audio/sfx/character/attack_03.wav"),
	&"attack_04": preload("res://assets/audio/sfx/character/attack_04.wav"),
	&"attack_05": preload("res://assets/audio/sfx/character/attack_05.wav"),
	&"tieshan_groan": preload("res://assets/audio/sfx/character/tieshan_groan.wav"),
	&"footstep_01": preload("res://assets/audio/sfx/character/footstep_01.wav"),
	&"footstep_02": preload("res://assets/audio/sfx/character/footstep_02.wav"),
	&"footstep_03": preload("res://assets/audio/sfx/character/footstep_03.wav"),
	&"footstep_04": preload("res://assets/audio/sfx/character/footstep_04.wav"),
	&"sprint_start": preload("res://assets/audio/sfx/character/sprint_start_clip1.wav"),

	&"interact": preload("res://assets/audio/sfx/interaction_click.wav"),
	&"serve_correct": preload("res://assets/audio/sfx/serve_correct.wav"),
	&"cooking_complete": preload("res://assets/audio/sfx/capture_success.wav"),
	&"restaurant_closed": preload("res://assets/audio/sfx/restaurant_closed.wav"),
	&"capture_success": preload("res://assets/audio/sfx/capture_success.wav"),
	&"capture_failure": preload("res://assets/audio/sfx/failure_user.wav"),
}
# 各动作音独立调音；加速在原始音量基础上降低10 dB。
const CUE_VOLUME_DB := {
	&"tieshan_groan": -12.0,
	&"order_accepted": -6.0,
	&"food_enjoy": -6.0,
	&"water_enjoy": 0.0,
	&"customer_seated": -1.0,
	&"party_join": -16.0,
	&"capture_success": -16.0,
	&"cooking_complete": -16.0,
	&"footstep_01": -22.0,
	&"footstep_02": -22.0,
	&"footstep_03": -23.0,
	&"footstep_04": -27.0,
	&"sprint_start": -10.0,
	&"attack_01": -20.0,
	&"attack_02": -20.0,
	&"attack_03": -20.0,
	&"attack_04": -20.0,
	&"attack_05": -20.0,
}
var _pending_mouse_clicks: Dictionary = {}
var _attack_index := 0
var _hit_index := 0
var _business_receipts: Dictionary = {}
var _serve_queue: Array[Dictionary] = []
var _serve_followup: StringName = &""
var _serve_owner: WeakRef
var _players: Dictionary = {}
var _interaction_frame := -1
var _mouse_buttons := 0
var _mouse_release_frame := -1
var maze_music: AudioStreamPlayer
var restaurant_music: AudioStreamPlayer
var home_music: AudioStreamPlayer
var boss_music: AudioStreamPlayer
var _world_music: StringName = &""
var _boss_id := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mix.load_saved()
	mix.refresh()
	for cue in STREAMS:
		var player := AudioStreamPlayer.new()
		player.stream = STREAMS[cue]
		player.volume_db = CUE_VOLUME_DB.get(cue, -6.0)
		player.max_polyphony = 4
		add_child(player)
		bind_volume(player, cue)
		_players[cue] = player
	_players[&"serve_correct"].finished.connect(_serve_first_finished)
	_players[&"food_enjoy"].finished.connect(_serve_next)
	_players[&"water_enjoy"].finished.connect(_serve_next)
	get_tree().scene_changed.connect(_cancel_serve_sequence)
	maze_music = AudioStreamPlayer.new()
	maze_music.name = "MazeExplorationBGM"
	maze_music.stream = preload("res://assets/audio/bgm/maze_exploration.ogg")
	maze_music.stream.loop = true
	maze_music.volume_db = -12.0
	add_child(maze_music)
	bind_volume(maze_music, &"music_maze")
	restaurant_music = AudioStreamPlayer.new()
	restaurant_music.name = "RestaurantBGM"
	restaurant_music.stream = preload("res://assets/audio/bgm/M01_restaurant.ogg")
	restaurant_music.stream.loop = true
	restaurant_music.volume_db = -12.0
	add_child(restaurant_music)
	bind_volume(restaurant_music, &"music_restaurant")
	home_music = AudioStreamPlayer.new()
	home_music.name = "AdventurerHomeBGM"
	home_music.stream = preload("res://assets/audio/bgm/adventurer_home.ogg")
	home_music.stream.loop = true
	home_music.volume_db = -6.0
	add_child(home_music)
	bind_volume(home_music, &"music_home")
	boss_music = AudioStreamPlayer.new()
	boss_music.name = "BossBattleBGM"
	boss_music.stream = preload("res://assets/audio/bgm/boss_battle.mp3")
	boss_music.stream.loop = true
	add_child(boss_music)
	bind_volume(boss_music, &"music_boss")
	get_tree().scene_changed.connect(_sync_maze_music)
	_sync_maze_music.call_deferred()

func bind_volume(player: AudioStreamPlayer, cue: StringName) -> void:
	mix.bind_player(player, String(cue))

func _process(delta: float) -> void:
	# 导出的游戏只在启动时读取配置；编辑器运行的游戏支持实时预览。
	if not OS.has_feature("editor"): return
	_mix_poll += delta
	if _mix_poll >= 0.2:
		_mix_poll = 0.0
		mix.refresh()

func _sync_maze_music() -> void:
	var scene := get_tree().current_scene
	# 换图的空窗期保留播放，直到目标场景就绪后才判断是否离开迷宫。
	if not is_instance_valid(scene): return
	var home := get_tree().get_first_node_in_group("adventurer_home")
	if is_instance_valid(home) and not home._closing:
		set_world_music(&"home")
	elif scene.is_in_group("maze_entry"):
		set_world_music(&"maze")
	elif scene.scene_file_path == "res://scenes/restaurant_map_2d.tscn":
		set_world_music(&"restaurant")
	else:
		set_world_music(&"")

func music_for_destination(path: String) -> void:
	if path == "res://scenes/adventurer_home.tscn":
		set_world_music(&"home")
	elif path in ["res://scenes/maze_entry.tscn", "res://scenes/maze_moss_pool.tscn", "res://scenes/maze_salt_pool.tscn", "res://scenes/maze_fenshui.tscn"]:
		set_world_music(&"maze")
	elif path == "res://scenes/restaurant_map_2d.tscn":
		set_world_music(&"restaurant")
	else:
		set_world_music(&"")

func set_world_music(kind: StringName) -> void:
	_world_music = kind
	_boss_id = ""
	boss_music.stop()
	maze_music.stream_paused = false
	if kind != &"home": home_music.stop()
	if kind != &"maze": maze_music.stop()
	if kind != &"restaurant": restaurant_music.stop()
	if kind == &"maze" and not maze_music.playing: maze_music.play()
	if kind == &"restaurant" and not restaurant_music.playing: restaurant_music.play()
	if kind == &"home" and not home_music.playing: home_music.play()

## 只消费已提交的战斗状态；攻击前摇触发一次，死亡/失败立即恢复。
func update_boss_music(run: Dictionary) -> void:
	if _world_music != &"maze": return
	var combat: Dictionary = run.get("combat", {})
	var actors: Dictionary = combat.get("actors", {})
	var region := str(combat.get("region", "maze_entry"))
	var id: String = {"salt_pool":"salt_pool_rockmane_1", "fenshui":"fenshui_wind_frog_1", "maze_entry":"lizard_1"}.get(region, "")
	var actor: Dictionary = actors.get(id, {})
	var monster: Dictionary = run.get("monsters", {}).get(id, {})
	var alive: bool = run.get("active", false) and combat.get("hp", 0) > 0 and actor.get("hp", 0) > 0 and monster.get("status", "") == "alive"
	if not alive or (not _boss_id.is_empty() and _boss_id != id):
		if not _boss_id.is_empty():
			_boss_id = ""
			boss_music.stop()
			maze_music.stream_paused = false
			if not maze_music.playing: maze_music.play()
		return
	var attacking: bool = actor.get("rock_phase", "") in ["charge", "rush"] or (actor.get("mode", "") != "return" and (actor.get("frog_phase", "") in ["warning", "airborne", "landing"] or actor.get("mode", "") == "windup"))
	if _boss_id.is_empty() and attacking:
		_boss_id = id
		maze_music.stream_paused = true
		boss_music.play()

func _exit_tree() -> void:
	if is_instance_valid(boss_music): boss_music.stop()
	if is_instance_valid(home_music): home_music.stop()
	if is_instance_valid(maze_music): maze_music.stop()
	if is_instance_valid(restaurant_music): restaurant_music.stop()

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton: return
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]: return
	var bit: int = 1 << event.button_index
	if event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 等本次输入完成分发，成功攻击可以取消同一次点击的通用音。
			_pending_mouse_clicks[event.get_instance_id()] = true
			_flush_mouse_click.call_deferred(event.get_instance_id())
		else:
			_play_interaction_once()
		_mouse_buttons |= bit
	else:
		_mouse_buttons &= ~bit
		_mouse_release_frame = Engine.get_process_frames()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_mouse_buttons = 0

func interaction() -> void:
	# 鼠标按下已响；按下或松开触发的业务回调不再重复播放。
	if _mouse_buttons != 0 or _mouse_release_frame == Engine.get_process_frames(): return
	_play_interaction_once()

func _play_interaction_once() -> void:
	# 同一输入经过共享处理器时，本帧只播放一次。
	var frame := Engine.get_process_frames()
	if _interaction_frame == frame: return
	_interaction_frame = frame
	play_cue(&"interact")

func play_cue(cue: StringName) -> void:
	if not _players.has(cue): return
	_players[cue].play()
	cue_played.emit(cue)

func play_served(kind: StringName) -> void:
	var owner_scene := get_tree().current_scene
	if not is_instance_valid(owner_scene): return
	_serve_queue.append({"cue": &"water_enjoy" if kind == &"water" else &"food_enjoy", "owner": weakref(owner_scene)})
	if _serve_followup.is_empty(): _serve_next()

func _serve_next() -> void:
	_serve_followup = &""
	while not _serve_queue.is_empty():
		var item: Dictionary = _serve_queue.pop_front()
		var owner_scene = item.owner.get_ref()
		if not is_instance_valid(owner_scene) or not owner_scene.is_inside_tree(): continue
		_serve_owner = item.owner
		_serve_followup = item.cue
		if not owner_scene.tree_exiting.is_connected(_cancel_serve_sequence):
			owner_scene.tree_exiting.connect(_cancel_serve_sequence, CONNECT_ONE_SHOT)
		play_cue(&"serve_correct")
		return

func _serve_first_finished() -> void:
	if _serve_followup.is_empty(): return
	var owner_scene = _serve_owner.get_ref()
	if not is_instance_valid(owner_scene) or not owner_scene.is_inside_tree():
		_cancel_serve_sequence()
		return
	# 正确交付仅保留提示音，不再追加料理/甘露水赞叹。
	_serve_next()

func _cancel_serve_sequence() -> void:
	_serve_queue.clear()
	_serve_followup = &""
	for cue in [&"serve_correct", &"food_enjoy", &"water_enjoy"]:
		if _players.has(cue): _players[cue].stop()

func _flush_mouse_click(event_id: int) -> void:
	if not _pending_mouse_clicks.has(event_id): return
	_pending_mouse_clicks.erase(event_id)
	_play_interaction_once()

func play_attack(event_id: int = 0) -> void:
	_pending_mouse_clicks.erase(event_id)
	play_cue(StringName("attack_%02d" % (_attack_index + 1)))
	_attack_index = (_attack_index + 1) % 5

func play_hit() -> void:
	play_cue(StringName("hit_%02d" % (_hit_index + 1)))
	_hit_index = (_hit_index + 1) % 3

func business_completed(save_path: String, day: int) -> void:
	var receipt := save_path + ":" + str(day)
	if _business_receipts.has(receipt): return
	_business_receipts[receipt] = true
	play_cue(&"business_complete")
