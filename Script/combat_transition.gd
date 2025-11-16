extends CanvasLayer

signal transition_finished()

@export var fade_time: float = 0.35

func start(callback: Callable) -> void:
	visible = true
	$Overlay.modulate.a = 0.0
	# fade in
	var t = create_tween()
	t.tween_property($Overlay, "modulate:a", 1.0, fade_time)
	await t.finished
	# call the callback (spawn combat) in the middle
	if callback:
		# pass this node's parent (the scene root) as the argument so the caller can add the combat scene there
		callback.call(get_parent())
	# fade out
	var t2 = create_tween()
	t2.tween_property($Overlay, "modulate:a", 0.0, fade_time)
	await t2.finished
	visible = false
	emit_signal("transition_finished")
