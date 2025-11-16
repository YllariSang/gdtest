extends Node

# Path to return to after combat ends (default to main game scene).
@export var return_scene_path: String = "res://Scenes/game.tscn"
@export var combat_scene_path: String = "res://Scenes/Combat.tscn"
@export var post_dialogue_lines: Array = []
@export var post_dialogue_map: Dictionary = {}
var _combat_outcome: String = ""
var enemy_name: String = "Enemy"
var saved_player_position: Vector2 = Vector2.ZERO

func start() -> void:
	# Change to the combat scene (loads synchronously)
	var packed = load(combat_scene_path)
	if not packed:
		print("Could not load combat scene: ", combat_scene_path)
		queue_free()
		return
	# Instantiate the packed scene and replace the current scene manually. Some
	# Godot versions do not provide `change_scene_to` on SceneTree, so do it
	# explicitly: free the current scene, add the new one as root child, and set
	# it as the current scene.
	var new_scene: Node = null
	if packed is PackedScene:
		new_scene = packed.instantiate()
	else:
		# load() sometimes returns a Resource that is already the scene; try instantiate()
		if packed and packed.has_method("instantiate"):
			new_scene = packed.instantiate()
		else:
			print("Loaded combat scene is not a PackedScene: ", combat_scene_path)
			queue_free()
			return

	# remove existing current scene
	var old_scene = get_tree().current_scene
	if old_scene:
		old_scene.queue_free()

	# add the new scene as a child of the SceneTree root and mark it current
	get_tree().root.add_child(new_scene)
	get_tree().set_current_scene(new_scene)

	# Now current scene should be the Combat scene; configure it
	var cs = get_tree().current_scene
	if cs and cs.has_node("Enemy"):
		cs.get_node("Enemy").unit_name = enemy_name
	
	# Start combat if CombatManager exists
	if cs and cs.has_node("CombatManager"):
		var mgr = cs.get_node("CombatManager")
		if mgr and mgr.has_method("start_combat"):
			mgr.start_combat([cs.get_node("Player"), cs.get_node("Enemy")])
			mgr.connect("combat_ended", Callable(self, "_on_combat_ended"))
		else:
			# If no manager found, cleanup after a short wait and return to the
			# configured return scene by loading and instancing it.
			await get_tree().create_timer(0.2).timeout
			_return_to_scene()
			queue_free()
	else:
		# No combat manager — return immediately
		await get_tree().create_timer(0.2).timeout
		_return_to_scene()
		queue_free()

func _on_combat_ended(_winner: Node) -> void:
	# After combat ends, return to the previous scene path
	# small delay to allow UI to update
	# determine outcome before changing scenes
	if _winner:
		# if winner node is named "Player" consider it a win
		if _winner.name == "Player":
			_combat_outcome = "win"
		else:
			_combat_outcome = "lose"
	else:
		_combat_outcome = "other"

	await get_tree().create_timer(0.35).timeout
	_return_to_scene()
	queue_free()


func _return_to_scene() -> void:
	var packed_ret = load(return_scene_path)
	if not packed_ret:
		print("Could not load return scene: ", return_scene_path)
		return
	var ret_scene: Node = null
	if packed_ret is PackedScene:
		ret_scene = packed_ret.instantiate()
	elif packed_ret and packed_ret.has_method("instantiate"):
		ret_scene = packed_ret.instantiate()
	else:
		print("Return scene is not a PackedScene: ", return_scene_path)
		return

	# remove existing current scene
	var old = get_tree().current_scene
	if old:
		old.queue_free()

	get_tree().root.add_child(ret_scene)
	get_tree().set_current_scene(ret_scene)

	# restore player position if provided
	var p = _find_node_by_name(ret_scene, "Player")
	if p and p is Node2D:
		p.global_position = saved_player_position
		if p.has_method("set_physics_process"):
			p.set_physics_process(true)

	# If post-dialogue content was provided, prefer an outcome-based map then fall back to the simple array
	var dlg = _find_node_by_name(ret_scene, "Dialogue")
	if dlg and dlg.has_method("start_dialogue"):
		var lines_to_play: Array = []
		if post_dialogue_map and _combat_outcome != "" and post_dialogue_map.has(_combat_outcome):
			lines_to_play = post_dialogue_map[_combat_outcome]
		elif post_dialogue_lines and post_dialogue_lines.size() > 0:
			lines_to_play = post_dialogue_lines
		if lines_to_play and lines_to_play.size() > 0:
			# try to find the NPC by the recorded enemy_name so the player faces it
			var npc = _find_node_by_name(ret_scene, enemy_name)
			if npc:
				dlg.start_dialogue(lines_to_play, npc)
			else:
				dlg.start_dialogue(lines_to_play)


func _find_node_by_name(root: Node, target_name: String) -> Node:
	if not root:
		return null
	if root.name == target_name:
		return root
	for child in root.get_children():
		if child is Node:
			var found = _find_node_by_name(child, target_name)
			if found:
				return found
	return null
