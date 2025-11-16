extends CanvasLayer

signal choice_made(choice: String)
signal dialogue_finished()

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/VBoxContainer/Label
@onready var prompt: Label = $Prompt
@onready var choice_container: VBoxContainer = $Panel/VBoxContainer/Choices

var _lines: Array = []
var _index: int = 0
var active: bool = false
var _player: Node = null
var _typing: bool = false
var _target_text: String = ""
var _char_index: int = 0
var _char_timer: float = 0.0
var _choices: Array = []
var _branches: Dictionary = {}
var _current_branch: String = ""
@export var typing_speed: float = 0.02 # seconds per character
var _input_block_time: float = 0.08 # seconds to block repeated input
var _input_block_timer: float = 0.0

func _ready() -> void:
	# No global pause; we'll disable player physics while dialogue is active
	panel.visible = false

func start_dialogue(lines: Array, focus_target: Node = null) -> void:
	
	if lines.size() == 0:
		return
	_lines = []
	_branches.clear()
	
	# Process the lines and set up branches
	for line in lines:
		if line.begins_with("BRANCH:"):
			var parts = line.split("|")
			var branch_name = parts[0].substr(7)  # Remove "BRANCH:" prefix
			_branches[branch_name] = parts.slice(1)
		else:
			_lines.append(line)
	
	_index = 0
	active = true
	panel.visible = true
	_show_current()
	# hide any on-screen prompt while in dialogue
	hide_prompt()
	# Disable the player movement by calling `set_locked(true)` on the player
	var root = get_tree().current_scene
	_player = null
	if root:
		_player = _find_player(root)
	if _player:
		if _player.has_method("set_locked"):
			_player.set_locked(true)
		else:
			_player.set_physics_process(false)
		# If the caller provided a focus target, attempt to make the player face it
		if focus_target and _player.has_method("set_facing_towards") and focus_target is Node2D:
			_player.set_facing_towards(focus_target.global_position)

func _show_current() -> void:
	# Clear previous choices
	for child in choice_container.get_children():
		child.queue_free()
	choice_container.visible = false
	
	if _current_branch != "":
		# Show branch dialogue
		if _branches.has(_current_branch) and _branches[_current_branch].size() > 0:
			_target_text = _branches[_current_branch][0]
			_branches[_current_branch] = _branches[_current_branch].slice(1)
	elif _index >= 0 and _index < _lines.size():
		var line = str(_lines[_index])
		# Check if this is a choice line
		if "|CHOICE|" in line:
			var parts = line.split("|CHOICE|")
			_target_text = parts[0]
			_choices = parts[1].split("|")
		else:
			_target_text = line
	
	# Reset typing state
	_char_index = 0
	_char_timer = 0.0
	_typing = true
	label.text = ""
	print("[Dialogue] _show_current: index=%d current_branch='%s' target_preview='%s' remaining_branch_lines=%d" % [_index, _current_branch, _target_text.substr(0, min(60, _target_text.length())), (_branches[_current_branch].size() if _branches.has(_current_branch) else 0)])

func _unhandled_input(event) -> void:
	if not active:
		return
	# ignore input when we're debouncing (prevents double-processing when keys are spammed)
	if _input_block_timer > 0.0:
		return
	# Accept both the new dedicated "interact" action and the legacy "ui_accept" as fallback
	# Ignore key-repeat echoes
	if event is InputEventKey and event.echo:
		return
	# Only handle mouse button events here. Keyboard/gamepad actions are handled in _process
	if event is InputEventMouseButton and event.pressed:
		print("[Dialogue] _unhandled_input: mouse click; typing=%s index=%d current_branch='%s'" % [str(_typing), _index, _current_branch])
		# Don't allow advancing if choices are visible
		if choice_container.visible:
			return
		# block further input for a short time to avoid double-firing
		_input_block_timer = _input_block_time
		if _typing:
			# finish typing instantly
			label.text = _target_text
			_typing = false
			# Check if we should show choices after skipping typing
			if _choices.size() > 0:
				_show_choices()
		else:
			_advance()

func show_prompt(text: String) -> void:
	if not panel.visible:
		prompt.text = text
		prompt.visible = true

func hide_prompt() -> void:
	prompt.visible = false

func _advance() -> void:
	print("[Dialogue] _advance: before index=%d current_branch='%s'" % [_index, _current_branch])
	# If we're in a branch, prefer to show the next branch line if available
	if _current_branch != "":
		if _branches.has(_current_branch) and _branches[_current_branch].size() > 0:
			_show_current()
		else:
			# Branch finished: clear branch and resume main dialogue
			_current_branch = ""
			_index += 1
			if _index >= _lines.size():
				_end_dialogue()
			else:
				_show_current()
		return

	# Normal dialogue progression (not in branch)
	_index += 1
	if _index >= _lines.size():
		_end_dialogue()
	else:
		_show_current()

func _process(delta: float) -> void:
	# decrement input block timer (debounce)
	if _input_block_timer > 0.0:
		_input_block_timer = max(0.0, _input_block_timer - delta)

	# Handle keyboard/gamepad action presses using just_pressed to avoid repeats
	if active:
		# Accept both the new dedicated "interact" action and the legacy "ui_accept" as fallback
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			print("[Dialogue] _process: action just pressed; typing=%s index=%d current_branch='%s'" % [str(_typing), _index, _current_branch])
			# Don't allow advancing if choices are visible
			if choice_container.visible:
				return
			# block further input briefly (protect against very fast repeated frames)
			_input_block_timer = _input_block_time
			if _typing:
				label.text = _target_text
				_typing = false
				# Check if we should show choices after skipping typing
				if _choices.size() > 0:
					_show_choices()
			else:
				_advance()

	# Handle typing effect
	if _typing:
		_char_timer += delta
		while _char_timer >= typing_speed and _typing:
			_char_timer -= typing_speed
			if _char_index < _target_text.length():
				label.text += _target_text[_char_index]
				_char_index += 1
			else:
				_typing = false
				if _choices.size() > 0:
					_show_choices()
				break

func _show_choices() -> void:
	choice_container.visible = true
	for choice in _choices:
		var button = Button.new()
		button.text = choice
		button.connect("pressed", Callable(self, "_on_choice_selected").bind(choice))
		choice_container.add_child(button)
	_choices.clear()

func _on_choice_selected(choice: String) -> void:
	choice_container.visible = false
	for child in choice_container.get_children():
		child.queue_free()

	# Record the choice and move main dialogue index past the choice line
	_current_branch = choice
	emit_signal("choice_made", choice)
	_index += 1
	print("[Dialogue] _on_choice_selected: choice='%s' index_after_choice=%d" % [choice, _index])
	# Immediately show the first branch line (if any)
	_show_current()

func _end_dialogue() -> void:
	active = false
	panel.visible = false
	_lines.clear()
	_index = 0
	_current_branch = ""
	_choices.clear()
	_branches.clear()
	# Re-enable player movement (unlock)
	if _player:
		if _player.has_method("set_locked"):
			_player.set_locked(false)
		else:
			_player.set_physics_process(true)
		_player = null

	# Notify listeners that dialogue finished
	emit_signal("dialogue_finished")

func _find_player(root: Node) -> Node:
	if not root:
		return null
	if root is CharacterBody2D:
		return root
	for child in root.get_children():
		if child is Node:
			var found = _find_player(child)
			if found:
				return found
	return null
