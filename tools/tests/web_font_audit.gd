extends SceneTree

func _initialize() -> void:
	var fonts := [load("res://assets/ui/zcool_kuail.ttf") as FontFile, load("res://assets/ui/chapter_end/ZCOOLXiaoWei-Regular.ttf") as FontFile]
	var available := ""
	for font in fonts:
		font.allow_system_fallback = false
		available += font.get_supported_chars()
	var chars := {}
	for directory in ["res://scripts", "res://scenes", "res://data"]:
		_scan(directory, chars)
	var missing := ""
	for character in chars:
		if character.unicode_at(0) > 127 and not available.contains(character):
			missing += character
	print("MISSING_ALL_BUNDLED: ", missing)
	var primary_missing := ""
	var primary_chars: String = fonts[0].get_supported_chars()
	for character in chars:
		if character.unicode_at(0) > 127 and not primary_chars.contains(character):
			primary_missing += character
	print("MISSING_PRIMARY: ", primary_missing)
	print("TOOLTIP_FONT: ", ThemeDB.get_default_theme().get_font("font", "TooltipLabel").has_char("继".unicode_at(0)))
	var combined := load("res://assets/ui/game_font.tres") as Font
	var missing_game := ""
	for character in chars:
		if character.unicode_at(0) > 127 and not combined.has_char(character.unicode_at(0)):
			missing_game += character
	print("MISSING_GAME_FONT: ", missing_game)
	var custom := load(ProjectSettings.get_setting("gui/theme/custom_font", "")) as Font
	var tooltip_font := ThemeDB.get_default_theme().get_font("font", "TooltipLabel")
	var tooltip_ok := custom != null and custom.has_char("继".unicode_at(0)) and tooltip_font.has_char("继".unicode_at(0))
	print("CUSTOM_TOOLTIP_CN: ", tooltip_ok)
	var numeric_ok := true
	for character in "0123456789×−+/%Shift":
		numeric_ok = numeric_ok and ThemeDB.fallback_font.has_char(character.unicode_at(0))
	print("NUMERIC_FONT: ", numeric_ok)
	print("SCANNED_UNIQUE_CHARACTERS: ", chars.size())
	quit(0 if missing_game.is_empty() and tooltip_ok and numeric_ok else 1)

func _scan(path: String, chars: Dictionary) -> void:
	var regex := RegEx.new()
	regex.compile('"([^"\\n]*)"')
	for file in DirAccess.get_files_at(path):
		if file.get_extension() not in ["gd", "tscn", "json", "tres"]:
			continue
		for matched in regex.search_all(FileAccess.get_file_as_string(path.path_join(file))):
			for character in matched.get_string(1):
				chars[character] = true
	for directory in DirAccess.get_directories_at(path):
		_scan(path.path_join(directory), chars)
