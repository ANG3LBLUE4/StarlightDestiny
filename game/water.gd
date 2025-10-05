extends Area3D

func _ready() -> void:
	body_entered.connect(_body_entered)
	body_exited.connect(_body_exited)
	
func _body_entered(body: Node3D):
	if body.name == "STAR":
		pass
	
func _body_exited(body: Node3D):
	if body.name == "STAR":
		pass
