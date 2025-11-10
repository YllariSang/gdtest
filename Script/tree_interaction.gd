extends Area2D

@export var dialogue_lines: Array = [
	"You encounter an ancient tree. Its branches sway gently in the wind.",
	"As you look closer, you notice some interesting features...",
	"What would you like to do?|CHOICE|Examine the leaves|Look for fruit|Check the trunk",
	"BRANCH:Examine the leaves|The leaves are a vibrant green, shimmering with an almost magical quality.|They seem to dance even when there's no breeze.",
	"BRANCH:Look for fruit|You spot some strange, glowing fruit high up in the branches.|They're too high to reach, but they look fascinating.",
	"BRANCH:Check the trunk|The trunk is covered in mysterious markings.|They could be ancient runes or perhaps just natural patterns in the bark."
]

var _player_nearby: bool = false
var _current_branch: String = ""

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
				# Only start a new dialogue if one is not already active
				if not dlg.active:
					dlg.start_dialogue(dialogue_lines)
				else:
					print("[TreeInteraction] dialogue already active; ignoring start request")
