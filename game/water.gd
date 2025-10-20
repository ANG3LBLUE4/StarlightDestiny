extends Area3D

@onready var splash_sfx = get_tree().current_scene.get_node("STAR/PlayerSFX/Splash")
@onready var player = get_tree().current_scene.get_node("STAR")

var value: int = 0

func _ready() -> void:
	area_entered.connect(_area_entered)
	area_exited.connect(_area_exited)
	
func _area_entered(body: Node3D):
	if body.name == "CameraCollisionArea":
		player.in_water = true
		player.flash_amount = 1
		splash_sfx.play()
	
func _area_exited(body: Node3D):
	if body.name == "CameraCollisionArea":
		player.in_water = false
