extends CharacterBody3D

@onready var animation = $AnimationPlayer
var health = 100

func _ready():
	death()
	
func death():
	if health <= 0:
		animation.play("death")
		await get_tree().create_timer(0.6)
		queue_free()
func _process(delta):
	death()
