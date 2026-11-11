@tool
extends VBoxContainer
signal source_requested(path: String)
const Catalog = preload("res://scripts/audio/audio_catalog.gd")
const Mix = preload("res://scripts/audio/audio_mix.gd")
var mix := Mix.new()
var rows: Array[Dictionary] = []
var selected_id := ""
var dirty := false
var search: LineEdit
var category: OptionButton
var usage_filter: OptionButton
var tree: Tree
var title_label: Label
var detail: Label
var path_label: LineEdit
var sources: OptionButton
var volume_slider: HSlider
var volume_number: SpinBox
var effective_label: Label
var status_label: Label
var playback_label: Label
var live: CheckBox
var loop_button: CheckBox
var player: AudioStreamPlayer
var group_controls: Dictionary = {}
var _updating := false
var _heartbeat := 0.0
var _session := ""
var _playing_id := ""

func _ready() -> void:
	custom_minimum_size = Vector2(700, 330)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_session = str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	rows = Catalog.entries()
	mix.load_saved()
	mix.settings = mix.saved_settings.duplicate(true)
	_build()
	player = AudioStreamPlayer.new()
	add_child(player)
	player.finished.connect(_on_finished)
	_rebuild_list()
	_sync_groups()
	_status("已读取项目音量。选择用途试听；拖动后实时预览，保存后重启保持。" if mix.last_error.is_empty() else mix.last_error)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): stop_preview())

func _build() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	search = LineEdit.new()
	search.placeholder_text = "搜索用途、素材或触发位置…"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(search)
	search.text_changed.connect(func(_text): _rebuild_list())
	category = OptionButton.new()
	for text in ["全部分类", "音乐", "音效", "对白"]: category.add_item(text)
	toolbar.add_child(category)
	category.item_selected.connect(func(_index): _rebuild_list())
	usage_filter = OptionButton.new()
	for text in ["全部状态", "使用中", "仅登记", "未发现引用"]: usage_filter.add_item(text)
	toolbar.add_child(usage_filter)
	usage_filter.item_selected.connect(func(_index): _rebuild_list())
	_button(toolbar, "保存到项目", save_changes)
	_button(toolbar, "撤销未保存", discard_changes)
	var groups := HBoxContainer.new()
	add_child(groups)
	for group in Mix.GROUPS:
		var label := Label.new()
		label.text = group
		groups.add_child(label)
		var spin := _spin()
		spin.tooltip_text = "分类增益，0 dB 为保持原音量；数值与单音效音量相加。"
		groups.add_child(spin)
		group_controls[group] = spin
		spin.value_changed.connect(func(value):
			if _updating: return
			mix.set_group_db(group, value)
			_changed())
	live = CheckBox.new()
	live.text = "实时同步游戏"
	live.button_pressed = true
	live.tooltip_text = "未保存修改也可试听到游戏；关闭后游戏恢复已保存设置。"
	groups.add_child(live)
	live.toggled.connect(func(enabled):
		if enabled and dirty:
			if not _publish_preview(): return
		else: _clear_preview()
		_status("实时同步已开启" if enabled else "实时同步已关闭，游戏恢复已保存设置"))
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	tree = Tree.new()
	tree.custom_minimum_size = Vector2(340, 170)
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.columns = 4
	tree.hide_root = true
	tree.column_titles_visible = true
	tree.select_mode = Tree.SELECT_ROW
	for i in 4:
		tree.set_column_title(i, ["用途", "分类", "状态", "单音 dB"][i])
		tree.set_column_expand(i, i == 0)
		if i > 0: tree.set_column_custom_minimum_width(i, [0, 48, 92, 66][i])
	split.add_child(tree)
	tree.item_selected.connect(_select_item)
	tree.item_activated.connect(play_preview)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 320
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(right)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 18)
	right.add_child(title_label)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(detail)
	path_label = LineEdit.new()
	path_label.editable = false
	path_label.tooltip_text = "素材路径，可选择复制"
	right.add_child(path_label)
	var source_row := HBoxContainer.new()
	right.add_child(source_row)
	sources = OptionButton.new()
	sources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sources.clip_text = true
	source_row.add_child(sources)
	_button(source_row, "打开调用文件", func():
		if sources.item_count > 0: source_requested.emit(sources.get_item_metadata(sources.selected)))
	var volume_row := HBoxContainer.new()
	right.add_child(volume_row)
	volume_slider = HSlider.new()
	volume_slider.min_value = Mix.MIN_DB
	volume_slider.max_value = Mix.MAX_DB
	volume_slider.step = 0.5
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_row.add_child(volume_slider)
	volume_number = _spin()
	volume_row.add_child(volume_number)
	_button(volume_row, "恢复此项默认", reset_selected)
	volume_slider.value_changed.connect(_volume_changed)
	volume_number.value_changed.connect(_volume_changed)
	effective_label = Label.new()
	right.add_child(effective_label)
	var transport := HBoxContainer.new()
	right.add_child(transport)
	_button(transport, "▶ 试听", play_preview)
	_button(transport, "■ 停止", stop_preview)
	loop_button = CheckBox.new()
	loop_button.text = "循环试听"
	transport.add_child(loop_button)
	playback_label = Label.new()
	transport.add_child(playback_label)
	# 底部面板较矮时仍优先显示试听与调音，长用途说明在下方滚动。
	right.move_child(transport, 1)
	right.move_child(volume_row, 2)
	right.move_child(effective_label, 3)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)

func _spin() -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = Mix.MIN_DB
	spin.max_value = Mix.MAX_DB
	spin.step = 0.5
	spin.suffix = "dB"
	spin.custom_minimum_size.x = 102
	return spin

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _rebuild_list() -> void:
	tree.clear()
	var root := tree.create_item()
	var first: TreeItem
	var selected: TreeItem
	for row in rows:
		if category.selected > 0 and row.category != category.get_item_text(category.selected): continue
		if usage_filter.selected > 0 and row.status != usage_filter.get_item_text(usage_filter.selected): continue
		if not search.text.is_empty() and not str(row).to_lower().contains(search.text.to_lower()): continue
		var item := tree.create_item(root)
		item.set_text(0, row.title)
		item.set_text(1, row.category)
		item.set_text(2, row.status)
		item.set_text(3, "%.1f" % mix.cue_db(row.id))
		item.set_metadata(0, row.id)
		item.set_tooltip_text(0, row.usage+"\n"+row.path)
		if first == null: first = item
		if row.id == selected_id: selected = item
	if selected == null: selected = first
	if selected != null:
		selected.select(0)
		_select_item()
	else:
		stop_preview()
		selected_id = ""
		title_label.text = "没有匹配的音效"
		detail.text = "请修改搜索条件。"
		path_label.text = ""
		sources.clear()
		effective_label.text = ""

func _select_item() -> void:
	var item := tree.get_selected()
	if item == null: return
	var id: String = item.get_metadata(0)
	if id != selected_id: stop_preview()
	selected_id = id
	var row: Dictionary = mix.entries[id]
	title_label.text = row.title
	detail.text = row.usage + "\n用途标识：" + id + " · " + row.status
	path_label.text = row.path if not row.path.is_empty() else "代码生成的盐晶敲击声"
	sources.clear()
	for path in row.sources:
		sources.add_item(path)
		sources.set_item_metadata(sources.item_count-1, "res://"+path)
	_update_volume_controls()

func _update_volume_controls() -> void:
	if selected_id.is_empty(): return
	_updating = true
	volume_slider.value = mix.cue_db(selected_id)
	volume_number.value = mix.cue_db(selected_id)
	_updating = false
	effective_label.text = "默认 %.1f dB  ·  分类叠加后 %.1f dB" % [float(mix.entries[selected_id].db), mix.effective_db(selected_id)]

func _sync_groups() -> void:
	_updating = true
	for group in group_controls: group_controls[group].value = mix.group_db(group)
	_updating = false

func _volume_changed(value: float) -> void:
	if _updating or selected_id.is_empty(): return
	mix.set_cue_db(selected_id, value)
	var item := tree.get_selected()
	if item: item.set_text(3, "%.1f" % value)
	_changed()

func _changed() -> void:
	dirty = mix.settings != mix.saved_settings
	_update_volume_controls()
	if not _playing_id.is_empty(): player.volume_db = mix.effective_db(_playing_id)
	if live.button_pressed and dirty:
		if not _publish_preview(): return
	else: _clear_preview()
	if not dirty: _status("当前设置与已保存的项目配置一致。")
	else: _status("未保存 · 已发送实时预览（游戏约 0.2 秒内应用）" if live.button_pressed else "未保存 · 仅面板试听；保存后应用到游戏")

func reset_selected() -> void:
	if selected_id.is_empty(): return
	mix.settings.cues.erase(selected_id)
	mix.apply_all()
	var item := tree.get_selected()
	if item: item.set_text(3, "%.1f" % mix.cue_db(selected_id))
	_changed()

func save_changes() -> void:
	var err := mix.save()
	if err != OK:
		_status("保存失败："+error_string(err)+"；修改仍保留在面板中")
		return
	dirty = false
	_clear_preview()
	_status("已保存到 data/audio/mix.json；游戏自动应用，重启保持。")

func discard_changes() -> void:
	if not mix.load_saved():
		_status(mix.last_error)
		return
	mix.settings = mix.saved_settings.duplicate(true)
	dirty = false
	_clear_preview()
	_sync_groups()
	_rebuild_list()
	if not _playing_id.is_empty(): player.volume_db = mix.effective_db(_playing_id)
	_status("已恢复项目中保存的音量。")

func play_preview() -> void:
	if selected_id.is_empty(): return
	stop_preview()
	var row: Dictionary = mix.entries[selected_id]
	var stream: AudioStream = Catalog.salt_stream() if row.path.is_empty() else load(row.path)
	if stream == null:
		_status("无法加载素材："+row.path)
		return
	stream = stream.duplicate()
	# 不修改原素材循环属性；面板通过 finished 管理循环试听。
	if stream is AudioStreamWAV: stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3: stream.loop = false
	_playing_id = selected_id
	player.stream = stream
	player.volume_db = mix.effective_db(selected_id)
	player.play()

func stop_preview() -> void:
	if is_instance_valid(player): player.stop()
	_playing_id = ""
	if is_instance_valid(playback_label): playback_label.text = "已停止"

func _on_finished() -> void:
	if loop_button.button_pressed and not _playing_id.is_empty(): player.play()
	else: stop_preview()

func _publish_preview() -> bool:
	var err := Mix.write_json(mix.preview_path, {"session":_session, "expires":Time.get_unix_time_from_system()+3.0, "mix":mix.settings})
	if err != OK: _status("实时同步写入失败："+error_string(err))
	return err == OK

func _clear_preview() -> void:
	if not FileAccess.file_exists(mix.preview_path): return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(mix.preview_path))
	if value is Dictionary and value.get("session") == _session:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(mix.preview_path))

func _process(delta: float) -> void:
	_heartbeat += delta
	if _heartbeat >= 1.0:
		_heartbeat = 0.0
		if dirty and is_instance_valid(live) and live.button_pressed: _publish_preview()
	if is_instance_valid(player) and player.playing:
		playback_label.text = "%.1f / %.1f 秒" % [player.get_playback_position(), player.stream.get_length()]

func _status(text: String) -> void:
	status_label.text = text

func _exit_tree() -> void:
	stop_preview()
	_clear_preview()
