extends Control

var ui_base_pos: Vector2
@onready var player = get_tree().root.get_node("Node3D/STAR")

func _ready() -> void:
	ui_base_pos = position

func _process(_delta: float) -> void:
	position = ui_base_pos + (Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * ((player.pain_amount/75)+(player.stress_amount/40)))
