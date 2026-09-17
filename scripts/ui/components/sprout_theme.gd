class_name SproutTheme
extends RefCounted
## Sprout Lands 基础主题工厂。
## 只创建局部 Theme 资源，不注册全局主题或自动加载单例。

const PANEL_TEXTURE: Texture2D = preload("res://assets/ui/ui_big_play_blank.png")
const ICON_TEXTURE: Texture2D = preload("res://assets/ui/all_icons.png")
const FONT_CN: Font = preload("res://assets/ui/zcool_kuail.ttf")
const FONT_PIXEL: Font = preload("res://assets/ui/sprout_lands.ttf")

const INK := Color("#5b3b20")
const INK_MUTED := Color("#876b47")
const CREAM := Color("#fff4dc")
const PANEL := Color("#f0d4a1")
const PANEL_DARK := Color("#d8b77d")
const GREEN := Color("#9fca86")
const GREEN_HOVER := Color("#b9dc9c")
const GREEN_PRESSED := Color("#7fae69")
const DISABLED := Color("#b9b5a5")

static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT_CN
	theme.default_font_size = 18
	theme.set_font("font", "Button", FONT_CN)
	theme.set_font("font", "Label", FONT_CN)
	theme.set_font("font", "LineEdit", FONT_CN)
	theme.set_font("font", "ScrollBar", FONT_PIXEL)
	theme.set_font_size("font_size", "Button", 18)
	theme.set_font_size("font_size", "Label", 18)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", CREAM)
	theme.set_color("font_disabled_color", "Button", Color("#736d60"))
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_color("font_color", "Label", INK)
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_constant("outline_size", "Button", 1)
	theme.set_color("font_outline_color", "Button", Color(1, 0.95, 0.82, 0.75))
	theme.set_stylebox("normal", "Button", button_style(PANEL))
	theme.set_stylebox("hover", "Button", button_style(GREEN_HOVER))
	theme.set_stylebox("pressed", "Button", button_style(GREEN_PRESSED))
	theme.set_stylebox("disabled", "Button", button_style(DISABLED))
	theme.set_stylebox("focus", "Button", focus_style())
	theme.set_stylebox("normal", "Panel", panel_style())
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_constant("separation", "Button", 8)
	return theme

static func panel_style(modulate := Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = PANEL_TEXTURE
	style.texture_margin_left = 9.0
	style.texture_margin_top = 9.0
	style.texture_margin_right = 9.0
	style.texture_margin_bottom = 9.0
	style.content_margin_left = 18.0
	style.content_margin_top = 16.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 16.0
	style.modulate_color = modulate
	return style

static func button_style(modulate: Color) -> StyleBoxTexture:
	var style := panel_style(modulate)
	style.content_margin_left = 13.0
	style.content_margin_right = 13.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style

static func focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("#5d9c63")
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style

static func icon(index: int, tile_size := 16) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = ICON_TEXTURE
	var columns := int(ICON_TEXTURE.get_width() / tile_size)
	atlas.region = Rect2((index % columns) * tile_size, (index / columns) * tile_size, tile_size, tile_size)
	return atlas

static func selected_style() -> StyleBoxTexture:
	return button_style(Color("#c2e0a5"))

static func unselected_style() -> StyleBoxTexture:
	return button_style(Color("#f0d4a1"))
