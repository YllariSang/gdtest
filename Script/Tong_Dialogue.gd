extends Area2D

@export var dialogue_lines: Array = [
	"Sige man|CHOICE|Sige man",
    "BRANCH:Sige man|White Monster."

]
@export var post_dialogue_lines: Array = []
@export var post_dialogue_map: Dictionary = {}

var _player_nearby: bool = false
var _current_branch: String = ""
var _locked_player: Node = null
var _spawned_combat_scene: Node = null
var _return_scene_path: String = "res://Scenes/game.tscn"
var _current_dialogue_node: Node = null

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))
	set_process(true)
	print("Tree interaction script initialized") # Debug print

func _on_body_entered(body: Node) -> void:
	print("Body entered: ", body.name) # Debug print
	if body is CharacterBody2D:
		print("Player nearby set to true") # Debug print
		_player_nearby = true
		# show on-screen prompt (use Dialogue node if present)
		var root = get_tree().current_scene
		print("Looking for Dialogue node in: ", root.name) # Debug print
		if root and root.has_node("Dialogue"):
			var dlg = root.get_node("Dialogue")
			if dlg and dlg.has_method("show_prompt"):
				print("Showing prompt") # Debug print
				dlg.show_prompt("[E] Talk")

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_nearby = false
		var root = get_tree().current_scene
		if root and root.has_node("Dialogue"):
			var dlg = root.get_node("Dialogue")
			if dlg and dlg.has_method("hide_prompt"):
				dlg.hide_prompt()

func _process(_delta: float) -> void:
	# Prefer a dedicated "interact" action; accept "ui_accept" as fallback
	if _player_nearby and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept")):
		var root = get_tree().current_scene
		if root and root.has_node("Dialogue"):
			var dlg = root.get_node("Dialogue")
			if dlg and dlg.has_method("start_dialogue"):
				if not dlg.active:
					# start pre-combat dialogue and wait for it to finish
					dlg.start_dialogue(dialogue_lines, self)
					_current_dialogue_node = dlg
					dlg.connect("dialogue_finished", Callable(self, "_on_pre_dialogue_finished"))
			else:
				# fallback: start transition immediately
				var trans_scene = load("res://Scenes/CombatTransition.tscn").instantiate()
				root.add_child(trans_scene)
				trans_scene.start(Callable(self, "_spawn_combat_with_parent"))

func _spawn_combat_with_parent(root: Node) -> void:
	# Called from the transition during the midpoint. `root` is the current scene root where combat should be added.
	if not root:
		return
	# Instead of instancing combat under the current scene, create a persistent bridge
	# node under the SceneTree root so it survives the scene change. The bridge will
	# change to the Combat scene, configure it, and return to `_return_scene_path`.
	var bridge_res = load("res://Script/combat_bridge.gd")
	if not bridge_res:
		print("Failed to load combat_bridge.gd")
		return
	var bridge = null
	if bridge_res is PackedScene:
		bridge = bridge_res.instantiate()
	elif bridge_res is Script:
		bridge = bridge_res.new()
	else:
		print("Unsupported bridge resource type: ", typeof(bridge_res))
		return
	# put it under the SceneTree root so it isn't freed when changing scenes
	get_tree().root.add_child(bridge)
	# configure bridge
	# capture player position (if a CharacterBody2D is present) so we can restore it
	var saved_pos: Vector2 = Vector2.ZERO
	var player_node = _find_player(root)
	if player_node and player_node is CharacterBody2D:
		saved_pos = player_node.global_position

	bridge.return_scene_path = _return_scene_path
	bridge.enemy_name = name
	# attach saved position to the bridge so it can restore the player when returning
	bridge.saved_player_position = saved_pos
	# attach optional post-dialogue lines so the bridge can play them after returning
	if post_dialogue_lines and post_dialogue_lines.size() > 0:
		bridge.post_dialogue_lines = post_dialogue_lines
	# pass optional outcome-based post-dialogue map
	if post_dialogue_map and post_dialogue_map.size() > 0:
		bridge.post_dialogue_map = post_dialogue_map

	bridge.start()

func _find_player(root: Node) -> Node:
	if not root:
		return null
	if root.name == "Player" and root is CharacterBody2D:
		return root
	for child in root.get_children():
		if child is Node:
			var found = _find_player(child)
			if found:
				return found
	return null

func _on_pre_dialogue_finished() -> void:
	# disconnect from the dialogue node and start the transition which will spawn combat
	if _current_dialogue_node:
		var cb = Callable(self, "_on_pre_dialogue_finished")
		if _current_dialogue_node.is_connected("dialogue_finished", cb):
			_current_dialogue_node.disconnect("dialogue_finished", cb)
		_current_dialogue_node = null

	var root = get_tree().current_scene
	if not root:
		return
	var trans_scene = load("res://Scenes/CombatTransition.tscn").instantiate()
	root.add_child(trans_scene)
	trans_scene.start(Callable(self, "_spawn_combat_with_parent"))

func _on_combat_ended(_winner: Node) -> void:
	# restore the locked player and remove the combat scene
	if _locked_player:
		_locked_player.set_physics_process(true)
		_locked_player = null
	# optionally remove combat scene if still present
	if _spawned_combat_scene:
		_spawned_combat_scene.queue_free()
		_spawned_combat_scene = null
