class_name EffectRing
extends Node2D

var age := 0.0
var tint := Color.WHITE

func _process(delta: float) -> void:
	age += delta
	queue_redraw()
	if age > 0.45:
		queue_free()

func _draw() -> void:
	var radius := 12.0 + age * 80.0
	var color := tint
	color.a = 1.0 - age / 0.45
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color, 4.0)
