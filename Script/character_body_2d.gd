extends CharacterBody2D

@export var speed: float = 100.0
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D


var last_direction: String = "down"  # default idle direction
var locked: bool = false

func set_locked(value: bool) -> void:
	locked = value
	if locked:
		velocity = Vector2.ZERO
		anim_sprite.play("idle_" + last_direction)

func set_facing_towards(target_global: Vector2) -> void:
	var dir = target_global - global_position
	if dir.length() == 0:
		return
	# choose dominant axis
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			last_direction = "right"
		else:
			last_direction = "left"
	else:
		if dir.y > 0:
			last_direction = "down"
		else:
			last_direction = "up"
	anim_sprite.play("idle_" + last_direction)

func _physics_process(_delta: float) -> void:
	# If a Combat scene is present as a child of the current scene root, disable movement
	var root = get_tree().current_scene
	if root and root.has_node("Combat"):
		return

	# If locked by dialogue or other systems, keep showing idle but prevent movement
	if locked:
		velocity = Vector2.ZERO
		move_and_slide()
		anim_sprite.play("idle_" + last_direction)
		return

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
