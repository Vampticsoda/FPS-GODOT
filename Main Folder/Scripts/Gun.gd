extends Node3D

@onready var animation = $"../../../AnimationPlayer" as AnimationPlayer 
@onready var animation_gun = $Gun_Animation 
@onready var aimcast = $"../AimCast" # Ensure it is an AnimationPlayer
var damage_gun = 20
var can_fire = true
@onready var bullet = preload("res://Main Folder/Scenes/bullet.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.gun = self
	
		
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

func ADS():
	if Input.is_action_just_pressed("AIDS") :
		Global.animation.play("AIDS")
		await get_tree().create_timer(0.3).timeout
		Global.animation.pause()
	if Input.is_action_just_released("AIDS"):
		Global.animation.play("ADS_return")
		
# Called every frame. 'delta' is the elapsed time since the previous frame.

func _process(delta):
	ADS()
	#_on_animation_player_animation_started("AIDS")


func _on_animation_player_animation_started(anim_name):
	if anim_name == "AIDS":
		pass
	else:
		pass
