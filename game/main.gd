extends Node3D

@onready var level_manager = $LevelManager

func _ready():
	load_level("res://levels/fudge_0_1.tscn")  # or any level you want at start

func load_level(path: String) -> void:
	# Clear any previous level
	for child in level_manager.get_children():
		child.queue_free()

	# Load and add the new level
	var level_scene = load(path)
	if level_scene:
		var level = level_scene.instantiate()
		level_manager.add_child(level)
	else:
		print("Failed to load level at path:", path)
