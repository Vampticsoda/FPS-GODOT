extends CharacterBody3D 

var _speed : float
@export_range(5,10,0.1) var CROUCH_SPEED : float = 7.0
@export var CROUCH_SHAPECAST : Node3D
@export var TOGGLE_CROUCH : bool = true
@export var DEFAULT_SPEED : float = 3.0
@export var SPEED_CROUCH : float = 2.0
@onready var SPRINT_SPEED : float = 5.0
@onready var SLIDE_SPEED : float = 9.0
@export var lean_amount := 25.0  # Max degrees of tilt
@export var lean_speed := 5.0    # How fast the lean transitions

var direction : Vector3
var fall : Vector3
var melee_damage = 50
var no_grav = 0
var wall_normal
var w_runnable = false

var cam1
var cam2
var aim

const JUMP_VELOCITY = 4.3
const SENSITIVITY = 0.004
const BOB_FREQ = 1.4
const BOB_AMP = 0.08
var t_bob = 0.0
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 9.8

@onready var gun = $Head/Camera3D/Gun
@onready var melee_weapon = $Head/Camera3D/MeleeWepon
@onready var head = $Head
@onready var camera1 = $Head/Camera3D

@onready var animation_player = $AnimationPlayer
@onready var panel_container = $CanvasLayer/PanelContainer
@onready var hitbox = $Head/Camera3D/Hitbox
@onready var aimcast = $Head/Camera3D/AimCast
@onready var blood_splatter = preload("res://Main Folder/Scenes/BloodSplatter.tscn")
@onready var bullet = preload("res://Main Folder/Scenes/bullet.tscn")

var is_crouching = false
var current_weapon = 1
var state = "IdlePlayerState"
var can_melee = true 
var lean_target := 0.0  # Target lean angle
var can_fire = true
var current_cam

func _ready():
	Global.player = self
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	CROUCH_SHAPECAST.add_exception($".")
	_speed = DEFAULT_SPEED
	Global.gun.visible = false
	current_cam = camera1


func _process(delta):
	if Input.is_action_pressed("lean_left"):
		lean_target = lean_amount
	elif Input.is_action_pressed("lean_right"):
		lean_target = -lean_amount
	else:
		lean_target = 0.0
	camera1.rotation_degrees.z = lerp(camera1.rotation_degrees.z, lean_target, lean_speed * delta)
	weapon_switch()
	update_state_label()
	


	if Input.is_action_just_pressed("crouch") and is_on_floor() and is_crouching == true and self.velocity == Vector3(0,0,0):
		state = "CrochingPlayerState"
		set_movement_speed("crouching")

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		current_cam.rotate_x(-event.relative.y * SENSITIVITY)
		current_cam.rotation.x = clamp(current_cam.rotation.x, deg_to_rad(-40), deg_to_rad(60))

func _physics_process(delta):
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("crouch") and is_on_floor() and is_crouching == true and self.velocity == Vector3(0,0,0):
		state = "CrochingPlayerState"
		set_movement_speed("crouching")
	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() and is_crouching == false:
		velocity.y = JUMP_VELOCITY
		state = "JumpingPlayerState"
	wall_run()
	# Handle Sprint.
	if Input.is_action_pressed("sprint") and is_crouching == false and is_on_floor() and self.velocity.length() > 1:
		set_movement_speed("sprint")
		state = "SprintingPlayerState"
	elif is_crouching:
		set_movement_speed("crouching")
		state = "CrouchingPlayerState"
	else:
		set_movement_speed("default")
		state = "WalkingPlayerState" if velocity.length() > 1 else "IdlePlayerState"
	
	if not is_on_floor() and state != "JumpingPlayerState":
		state = "JumpingPlayerState"

	if Input.is_action_just_pressed("slide"):
		animation_player.play("Sliding")
		set_movement_speed("sliding")
	
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * _speed
			velocity.z = direction.z * _speed
		else:
			velocity.x = lerp(velocity.x, direction.x * _speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * _speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * _speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * _speed, delta * 3.0)
	
	# Head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera1.transform.origin = _headbob(t_bob)
	
	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera1.fov = lerp(camera1.fov, target_fov, delta * 8.0)
	
	move_and_slide()

func update_state_label():
	""" Updates the Debug UI Label with the current state """
	Global.state_label.text=""+ state

func weapon_switch():
	if Input.is_action_just_pressed("melee"):
		current_weapon = 1
	elif Input.is_action_just_pressed("wepon1"):
		current_weapon = 2
	if current_weapon == 1:
		melee_weapon.visible = true
		melee()
		SPRINT_SPEED = 6.5
	else:
		melee_weapon.visible = false
		SPRINT_SPEED = 5.0

	if current_weapon == 2:
		Global.gun.visible = true
		shoot()
	else:
		Global.gun.visible = false

func shoot():
	
	if can_fire == true and Input.is_action_just_pressed("fire"):
		can_fire = false
		Global.gun_animation.play("gunfire")
		if aimcast.is_colliding():
			var b = bullet.instantiate()
			Global.muzzle.add_child(b)
			b.look_at(aimcast.get_collision_point(), Vector3.UP)
			b.shoot = true
			await get_tree().create_timer(0.4).timeout
			can_fire = true

func wall_run():		
		if Input.is_action_pressed("jump") and w_runnable == false:	
			if Input.is_action_pressed("up"):
				if is_on_wall():
					
					#wall_normal = get_last_slide_collision()
					#get_tree().create_timer(0.2).timeout
					velocity.y = 0
					_speed = 8.0
					await get_tree().create_timer(5).timeout
					w_runnable = true
		if w_runnable == true:
			await get_tree().create_timer(1.5).timeout
			w_runnable = false


func is_near_wall() -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_transform.origin, global_transform.origin + transform.basis.z * -1.0, 0b1)
	var result = space_state.intersect_ray(query)
	if result and not is_on_floor():
		wall_normal = result.normal
		return true
	return false
func melee():	
	if can_melee == true and Input.is_action_just_pressed("fire"):
		can_melee = false
		if not animation_player.is_playing():
			animation_player.play("Attack")
			animation_player.queue("Melee_Return")
			
		if animation_player.current_animation == "Attack":
			for body in hitbox.get_overlapping_bodies():
				if body.is_in_group("Enemy"):
					var b = blood_splatter.instantiate()# Ensure the instance was created successfully
					b.global_position = body.to_global(Vector3.ZERO)
					get_tree().root.add_child(b)  # Fallback if no damage function
					body.health -= melee_damage
		await get_tree().create_timer(0.5).timeout
		can_melee = true

func _input(event):
	if event.is_action_pressed("exit"):
		get_tree().quit()
	if event.is_action_pressed("crouch") and is_on_floor():
		toggle_crouch()  # Short cooldown
	if event.is_action_pressed("crouch") and is_on_floor() and is_crouching == false and TOGGLE_CROUCH == false:
		crouching(true)
	if event.is_action_released("crouch") and TOGGLE_CROUCH == false:
		if CROUCH_SHAPECAST.is_colliding() == false:
			crouching(false)
		elif CROUCH_SHAPECAST.is_colliding() == true:
			uncrouch_check()
	


func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func toggle_crouch():
	if is_crouching == true and CROUCH_SHAPECAST.is_colliding() == false:
		crouching(false)
		set_movement_speed('default')
	elif is_crouching == false:
		crouching(true)
		set_movement_speed("crouching")


func crouching(state: bool):
	match state:
		true:
			animation_player.play("Crouch", 0, CROUCH_SPEED)
			set_movement_speed("crouching")
			self.state = "CrouchingPlayerState"
			is_crouching = true
		false:
			animation_player.play("Crouch", 0, -CROUCH_SPEED, true)
			set_movement_speed("default")
			self.state = "IdlePlayerState" # Ensure animation finishes before another change
			is_crouching = false
func uncrouch_check():
	if CROUCH_SHAPECAST.is_colliding() == false:
		crouching(false)
		
	if CROUCH_SHAPECAST.is_colliding() ==true:
		await get_tree().create_timer(0.1).timeout
		uncrouch_check()

func _on_animation_player_animation_started(anim_name):
	if anim_name == "Crouch":
		is_crouching = !is_crouching
		set_movement_speed("crouching")
		state = "CrouchingPlayerState"


func set_movement_speed(state : String):
	match state:
		"default":
			_speed = DEFAULT_SPEED
		"crouching":
			_speed = SPEED_CROUCH
		"sprint":
			if not is_crouching:  # Prevent sprinting while crouched
				_speed = SPRINT_SPEED
		"sliding":
			_speed = SLIDE_SPEED
