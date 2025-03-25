extends RigidBody3D

var shoot = false
const bullet_damage = 20
const speed = 8
@onready var blood_splatter = preload("res://Main Folder/Scenes/BloodSplatter.tscn")

func _ready():
	top_level = true
	Global.bullet = self


func _physics_process(delta):
	if shoot:
		apply_impulse(-transform.basis.z * speed, transform.basis.z )
		


func _on_area_3d_body_entered(body):
	if body.is_in_group("Enemy"):
		var b = blood_splatter.instantiate()# Ensure the instance was created successfully
		b.global_transform.origin = body.global_transform.origin
		get_tree().current_scene.add_child(b)
		body.health -= bullet_damage
		queue_free()
		
	else:
		queue_free()
