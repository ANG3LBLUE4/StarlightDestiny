extends Area3D

@onready var splash_sfx = get_tree().current_scene.get_node("STAR/Splash")

var value: int = 0

func _ready() -> void:
	body_entered.connect(_body_entered)
	body_exited.connect(_body_exited)
	
func _body_entered(body: Node3D):
	if body.name == "STAR":
		body.in_water = true
		body.flash_amount = 1
		splash_sfx.play()
	
func _body_exited(body: Node3D):
	if body.name == "STAR":
		body.in_water = false
