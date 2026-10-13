class_name V035Theme
extends RefCounted

# Code-native nine-slice-compatible UI primitives. Painted PNGs can later replace
# these StyleBoxes without changing layout or button behavior.
static func box(fill: Color, edge: Color, radius: int = 12, margin: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style

static func button(control: Button, variant: String = "cream") -> void:
	var fill := Color("#FFF3D9")
	var edge := Color("#C69048")
	var ink := Color("#453122")
	if variant == "blue":
		fill = Color("#D5EFFF")
		edge = Color("#559BC5")
		ink = Color("#224760")
	elif variant == "green":
		fill = Color("#E1F5DA")
		edge = Color("#76A95D")
		ink = Color("#2F5332")
	elif variant == "gold":
		fill = Color("#FFE2A0")
		edge = Color("#B87A2F")
		ink = Color("#5B3D1F")
	var normal := box(fill, edge, 10, 6)
	var hover := box(fill.lightened(0.12), edge.lightened(0.1), 10, 6)
	var pressed := box(fill.darkened(0.1), edge.darkened(0.1), 10, 6)
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_stylebox_override("hover", hover)
	control.add_theme_stylebox_override("pressed", pressed)
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.add_theme_color_override("font_color", ink)
	control.add_theme_color_override("font_hover_color", ink)
	control.add_theme_color_override("font_pressed_color", ink)
	control.add_theme_font_size_override("font_size", 17)

static func label(control: Label, size: int = 17, color: Color = Color("#443528")) -> void:
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color)
