extends CharacterBody3D

@onready var dash_bar = get_tree().current_scene.get_node("UI/DashBarContainer/DashBar")
@onready var dash_label = get_tree().current_scene.get_node("UI/DashBarContainer/DashLabel")
@onready var hp_bar = get_tree().current_scene.get_node("UI/HPBarContainer/HPBar")
@onready var hp_label = get_tree().current_scene.get_node("UI/HPBarContainer/HPLabel")
@onready var hd_label = get_tree().current_scene.get_node("UI/HPBarContainer/HDLabel")
@onready var pain_overlay := get_tree().current_scene.get_node("UI/PainOverlay/TextureRect")
@onready var lowmood_overlay := get_tree().current_scene.get_node("UI/LowMoodOverlay/TextureRect")
@onready var death_screen = get_tree().current_scene.get_node("UI/DeathScreen")
@onready var stress_label = get_tree().current_scene.get_node("UI/Stress/StressLabel")
@onready var hyjacked_overlay = get_tree().current_scene.get_node("UI/HyjackedOverlay/TextureRect")
@onready var flash_overlay = get_tree().current_scene.get_node("UI/FlashOverlay/TextureRect")
@onready var water_overlay = get_tree().current_scene.get_node("UI/WaterOverlay/TextureRect")
@onready var hypoxia_overlay = get_tree().current_scene.get_node("UI/HypoxiaOverlay/TextureRect")
@onready var pain_sfx := $PlayerLoopingSFX/Pain
@onready var pain_extreme_sfx := $PlayerLoopingSFX/PainExtreme
@onready var stress_sfx := $PlayerLoopingSFX/Stress
@onready var panic_sfx := $PlayerLoopingSFX/Panic
@onready var hyjacked_sfx := $PlayerLoopingSFX/Hyjacked
@onready var death_sfx := $Death
@onready var drowning_sfx := $PlayerLoopingSFX/Drowning
@onready var underwater_sfx := $PlayerLoopingSFX/Underwater
@onready var dash_sfx: = $PlayerSFX/Dash
@onready var grounded_sfx: = $PlayerSFX/Grounded
@onready var hurt_sfx: = $PlayerSFX/Hurt
@onready var jump_sfx: = $PlayerSFX/Jump
@onready var walljump_sfx: = $PlayerSFX/Walljump

@export var move_speed := 10.0
@export var jump_velocity := 14.0
@export var dash_speed := 25.0
@export var dash_time := 0.2
@export var mouse_sensitivity := 0.003
@export var max_dashes := 5.0
@export var dash_recharge_interval := 0.15
@export var max_health := 10.0
@export var health_regen_interval := 0.2
@export var hard_damage_interval := 0.1
@export var pain_amount := 0.0
@export var pain_decrease := 3.0
@export var stress_amount := 0.0
@export var stress_decrease := 1.5
@export var panic_amount := 0.0
@export var flash_amount := 0.0
@export var death_screen_fade := 0.0
@export var wet_amount := 0.0
@export var oxygen := 100.0

var current_health := max_health
var current_dashes := float(max_dashes)
var current_hard_damage := 1.0
var hard_damage_timer := 0.0
var health_regen_timer := 0.0
var recharge_timer := 0.0
var dash_timer := 0.0
var is_dashing := false
var dash_direction := Vector3.ZERO
var dash_bar_display_value := float(max_dashes)
var hp_bar_display_value := float(max_health * 10)
var in_water := false

#Preloading sounds
var sfx_dash := preload("res://sounds/star-dash.mp3")
var sfx_grounded := preload("res://sounds/star-grounded.mp3")
var sfx_hurt := preload("res://sounds/star-hurt.mp3")
var sfx_jump := preload("res://sounds/star-jump.mp3")
var sfx_walljump := preload("res://sounds/star-walljump.mp3")

# Fall damage tracking
var was_on_floor := false
var landing_velocity_y := 0.0

# Camera movement
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		$Camera3D.rotate_x(-event.relative.y * mouse_sensitivity)
		$Camera3D.rotation.x = clamp($Camera3D.rotation.x, deg_to_rad(-89), deg_to_rad(89))

# Player control

func _physics_process(delta):
	var direction = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("move_left"):
		direction -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		direction += transform.basis.x
	direction = direction.normalized()

	# Dash
	if Input.is_action_just_pressed("dash") and not is_dashing and floor(current_dashes) > 0:
		is_dashing = true
		$PlayerSFX/Dash.play()
		dash_timer = dash_time
		dash_direction = direction
		if dash_direction == Vector3.ZERO:
			dash_direction = -transform.basis.z
		current_dashes -= 1.0
		recharge_timer = 0.0

	if is_dashing:
		velocity = dash_direction * dash_speed
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	else:
		# Horizontal movement
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed

		# Jumping & Wall jumping
		if Input.is_action_just_pressed("jump"):
			if is_on_wall() and not is_on_floor():
				if current_dashes >= 0.7:
					var wall_normal = get_wall_normal()
					var push_off = -wall_normal * move_speed * 1.5
					velocity.x = push_off.x
					velocity.z = push_off.z
					velocity.y = jump_velocity
					if current_dashes <= max_dashes:
						current_dashes -= 0.7
						$PlayerSFX/Walljump.play()
			elif is_on_floor():
				velocity.y = jump_velocity
				current_dashes -= 0.2
				$PlayerSFX/Jump.play()

		# Gravity and wall slide
		if not is_on_floor():
			if is_on_wall() or in_water:
				velocity.y = max(velocity.y - 30.0 * delta, -5)
			else:
				velocity.y -= 30.0 * delta

	if not is_on_floor():
		landing_velocity_y = velocity.y

	# Dash modifiers
	if current_dashes < max_dashes and not is_dashing:
		var recharge_rate_multiplier = 1.0
		if direction == Vector3.ZERO and is_on_floor():
			recharge_rate_multiplier = 1.5
		elif is_on_wall() and not is_on_floor() and velocity.y < 0:
			recharge_rate_multiplier = 0.4
		elif not is_on_wall() and not is_on_floor():
			recharge_rate_multiplier = 0.1

		recharge_timer += delta * recharge_rate_multiplier

		if recharge_timer >= dash_recharge_interval:
			current_dashes += 0.1
			current_dashes = clamp(current_dashes, 0.0, float(max_dashes))
			recharge_timer = 0.0
	
	# Fall damage
	if not was_on_floor and is_on_floor():
		if landing_velocity_y < -23.0 and not in_water:
			var damage: float = clamp((-landing_velocity_y - 15.0) * 0.2, 0.0, 10.0)
			$PlayerSFX/Hurt.play()
			current_health -= damage
			current_hard_damage += damage
			pain_amount += damage*12.0
			current_health = clamp(current_health, 0.0, max_health)
		else:
			$PlayerSFX/Grounded.play()
		landing_velocity_y = 0.0
	was_on_floor = is_on_floor()
 
	move_and_slide()

	if position.y < -150:
		position = Vector3.ZERO
		velocity = Vector3.ZERO

func _process(delta: float) -> void:
	
	# UI loop
	
	dash_bar_display_value = lerp(dash_bar_display_value, current_dashes, 4.0 * delta)
	dash_bar.value = dash_bar_display_value
	dash_label.text = str(floor(pain_amount))

	hp_bar_display_value = lerp(hp_bar_display_value, current_health, 4.0 * delta)
	hp_bar.value = clamp(hp_bar_display_value * 10, 0.0, max_health * 10)
	hp_label.text = str(int(floor(current_health * 10)))
	
	# Stress display & handling
	
	stress_amount += pain_amount / 30.0 * delta
	stress_amount += (10.0 - current_health) / 3.5 * delta
	stress_amount -= stress_decrease * delta
	stress_amount = clamp(stress_amount, 0, 100)
	
	stress_label.text = str(floor(int(stress_amount)))
	if stress_amount >= 35:
		stress_label.modulate = Color(1, 1-(clamp(stress_amount-40, 0, 100) / 20.0), 1-(clamp(stress_amount-40, 0, 100) / 20.0), (clamp(stress_amount-35, 0, 100) / 35.0 + 0.2))
	else:
		stress_label.modulate = Color(1, 1, 1, 0.2)
		
	if stress_amount >= 99.9:
		panic_amount += 1.0 * delta
		if not hyjacked_sfx.playing:
			$PlayerLoopingSFX/Hyjacked.play(0.0)
	else:
		if hyjacked_sfx.playing:
			panic_amount = 0.0
			$PlayerLoopingSFX/Hyjacked.stop()
			flash_amount = 10.0
			stress_amount -= 20.0
		
	if panic_amount >= 14.9:
		current_health = 0.0
	
	# Stress sound effects
	
	if stress_amount >= 50:
		var vol = -60 + clamp(stress_amount-50, 0, 100) * 3
		stress_sfx.volume_db = clamp(vol, -80.0, -10)
	else:
		stress_sfx.volume_db = -80.0

	if stress_amount >= 80:
		var vol = -60 + clamp(stress_amount-80, 0, 100) * 5
		panic_sfx.volume_db = clamp(vol, -80.0, -10)
	else:
		panic_sfx.volume_db = -80.0
		
	# Health & hard damage
	
	if current_hard_damage > 0.0:
		hard_damage_timer += delta
		if hard_damage_timer >= hard_damage_interval:
			current_hard_damage -= 0.1
			current_hard_damage = max(current_hard_damage, 0.0)
			hard_damage_timer = 0.0
			hd_label.text = str(current_hard_damage)
	else:
		health_regen_timer += delta
		if health_regen_timer >= health_regen_interval:
			current_health += 0.1
			current_health = clamp(current_health, 0.0, max_health)
			health_regen_timer = 0.0
	
	# Effects overlay & handling
	if stress_amount >= 50:
		lowmood_overlay.modulate.a = clamp(stress_amount-50, 0, 100) / 50.0
	else:
		lowmood_overlay.modulate.a = 0.0
		
	if pain_amount >= 40:
		pain_overlay.modulate.a = clamp(pain_amount-40, 0, 400) / 50.0
	else:
		pain_overlay.modulate.a = 0.0
	if pain_amount > 0:
		pain_amount -= pain_decrease * delta
		
	if panic_amount >= 0:
		hyjacked_overlay.modulate.a = clamp(panic_amount, 0, 15) / 10
	else:
		hyjacked_overlay.modulate.a = 0.0
		
	if flash_amount >= 0.0:
		flash_overlay.modulate.a = clamp(flash_amount, 0, 10.0) / 10.0
	else:
		flash_overlay.modulate.a = 0.0
	flash_amount -= 10.0 * delta
	flash_amount = clamp(flash_amount, 0, 10.0)
	
	if in_water:
		wet_amount = 100.0
		oxygen -= 5.0 * delta
		stress_amount += 1.5 * delta
		var vol = -10
		underwater_sfx.volume_db = clamp(vol, -80.0, -10)
		AudioServer.set_bus_effect_enabled(4, 0, true)
	else:
		wet_amount -= 50.0 * delta
		oxygen += 15.0 * delta
		var vol = -80
		underwater_sfx.volume_db = clamp(vol, -80.0, -10)
		AudioServer.set_bus_effect_enabled(4, 0, false)
	
	wet_amount = clamp(wet_amount, 0 , 100)
	oxygen = clamp(oxygen, 0 , 100)
	
	if wet_amount >= 0.0:
		water_overlay.modulate.a = clamp(wet_amount, 0, 100.0) / 150.0
		
	if oxygen <= 60.0:
		hypoxia_overlay.modulate.a = clamp(60-oxygen, 0, 100.0) / 60
		var vol = -80 + clamp(60-oxygen, 0, 100) * 1.5
		drowning_sfx.volume_db = clamp(vol, -80.0, -10)
	else:
		hypoxia_overlay.modulate.a = 0.0
		drowning_sfx.volume_db = -80.0
	
	# Drowning
	if oxygen <= 0.1:
		current_health -= 1.0 * delta
		current_hard_damage += 2.0 * delta
		pain_amount += 10.0 * delta
		stress_amount += 5.0 * delta
		
	# Death trigger
	if current_health <= 0.1:
		if not death_screen.visible:
			death_screen.visible = true
			death_screen_fade = 8.0
			AudioServer.set_bus_volume_linear(1, 0.0)
			AudioServer.set_bus_volume_linear(2, 0.0)
			AudioServer.set_bus_volume_linear(4, 0.0)
			death_sfx.play()
			flash_amount += 10.0
		death_screen.modulate = Color(1-(death_screen_fade/8), 1-(death_screen_fade/8), 1-(death_screen_fade/8))
		death_screen_fade -= 1.0 * delta
		death_screen_fade = clamp(death_screen_fade, 0.0, 8.0)
		
	# Pain sound effects
	if pain_amount >= 0:
		var vol = lerp(-80.0, -5.0, (pain_amount - 0) / 50.0)
		pain_sfx.volume_db = clamp(vol, -80.0, -5.0)
	else:
		pain_sfx.volume_db = -80.0
	if pain_amount >= 60:
		var vol = lerp(-80.0, -5.0, (pain_amount - 0) / 90.0)
		pain_extreme_sfx.volume_db = clamp(vol, -80.0, -5.0)
	else:
		pain_extreme_sfx.volume_db = -80.0
