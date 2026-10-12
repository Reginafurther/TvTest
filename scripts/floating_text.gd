class_name FloatingText
extends Label

var velocity := Vector2(0, -28)
var lifetime := 0.85

func setup(value: String, tint: Color) -> void:
	text = value
	modulate = tint
	position = Vector2(-24, -48)
	add_theme_font_size_override("font_size", 17)
	add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.05, 0.95))
	add_theme_constant_override("outline_size", 4)

func _process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	modulate.a = clampf(lifetime / 0.35, 0.0, 1.0)
	if lifetime <= 0.0:
		queue_free()

