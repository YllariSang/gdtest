extends CharacterBody2D

@export var speed: float = 100.0
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D


var last_direction: String = "down"  # default idle direction

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO

	# Input
	if Input.is_action_pressed("right"):
		direction.x += 1
	if Input.is_action_pressed("left"):
		direction.x -= 1
	if Input.is_action_pressed("down"):
		direction.y += 1
	if Input.is_action_pressed("up"):
		direction.y -= 1

	# Normalize diagonal
	direction = direction.normalized()

	# Movement
	velocity = direction * speed
	move_and_slide()

	# Animation logic
	if direction == Vector2.ZERO:
		# No movement -> idle animation
		anim_sprite.play("idle_" + last_direction)
	else:
		if direction.x > 0:
			anim_sprite.play("walk_right")
			last_direction = "right"
		elif direction.x < 0:
			anim_sprite.play("walk_left")
			last_direction = "left"
		elif direction.y > 0:	
			anim_sprite.play("walk_down")
			last_direction = "down"
		elif direction.y < 0:
			anim_sprite.play("walk_up")
			last_direction = "up"
