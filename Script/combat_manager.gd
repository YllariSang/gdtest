extends Node

signal turn_started(current)
signal combat_ended(winner)
signal combat_started()

var combatants: Array = []
var turn_index: int = 0
var in_combat: bool = false
var _skill_used = {}

func _ready() -> void:
	# Try to wire UI if present
	var root = get_parent()
	if not root:
		return
	if root.has_node("UI/AttackButton"):
		root.get_node("UI/AttackButton").connect("pressed", Callable(self, "_on_attack_pressed"))
	if root.has_node("UI/SkillButton"):
		root.get_node("UI/SkillButton").connect("pressed", Callable(self, "_on_skill_pressed"))
	if root.has_node("UI/StartButton"):
		root.get_node("UI/StartButton").connect("pressed", Callable(self, "_on_start_pressed"))
	if root.has_node("UI/EndTurn"):
		root.get_node("UI/EndTurn").connect("pressed", Callable(self, "end_turn"))

	# connect HP signals if the nodes exist
	if root.has_node("Player") and root.has_node("Enemy"):
		var p = root.get_node("Player")
		var e = root.get_node("Enemy")
		p.connect("hp_changed", Callable(self, "_on_hp_changed"))
		e.connect("hp_changed", Callable(self, "_on_hp_changed"))
		p.connect("died", Callable(self, "_on_died"))
		e.connect("died", Callable(self, "_on_died"))
		# initialize UI labels
		_update_ui()

func start_combat(list_of_combatants: Array) -> void:
	combatants = list_of_combatants
	turn_index = 0
	in_combat = true
	emit_signal("combat_started")
	# reset skill usage tracking
	_skill_used.clear()
	for c in combatants:
		_skill_used[c.get_instance_id()] = false
	_start_current_turn()

func _start_current_turn() -> void:
	if not in_combat:
		return
	if combatants.size() == 0:
		return
	var current = combatants[turn_index]
	if not current.is_alive():
		_advance_turn()
		return
	emit_signal("turn_started", current)
	_update_ui()
	# if enemy, let AI act
	# if not the player, treat as AI-controlled
	if current.unit_name != "Player":
		await get_tree().create_timer(0.4).timeout
		enemy_take_turn(current)

func player_attack_target(target: Node) -> void:
	if not in_combat:
		return
	var current = combatants[turn_index]
	if current.unit_name != "Player":
		return
	current.perform_attack(target)
	_update_ui()
	_check_end_conditions()
	_advance_turn()

func player_use_skill(target: Node) -> void:
	if not in_combat:
		return
	var current = combatants[turn_index]
	if current.unit_name != "Player":
		return
	var id = current.get_instance_id()
	if _skill_used.has(id) and _skill_used[id]:
		# skill already used
		var root = get_parent()
		if root and root.has_node("UI/Info"):
			root.get_node("UI/Info").text = "Skill not ready"
		return
	# skill: heavy strike (double attack)
	if target and target.has_method("take_damage"):
		target.take_damage(current.attack_power * 2)
	_skill_used[id] = true
	_update_ui()
	_check_end_conditions()
	_advance_turn()

func _on_attack_pressed() -> void:
	# called from UI button; attack first alive non-player
	if not in_combat:
		return
	var current = combatants[turn_index]
	if current.unit_name != "Player":
		return
	var target: Node = null
	for c in combatants:
		if c != current and c.is_alive():
			target = c
			break
	if target:
		player_attack_target(target)

func _on_start_pressed() -> void:
	# UI start button pressed: start combat if scene has Player/Enemy
	var root = get_parent()
	if not root:
		return
	if root.has_node("Player") and root.has_node("Enemy"):
		start_combat([root.get_node("Player"), root.get_node("Enemy")])

func enemy_take_turn(enemy: Node) -> void:
	if not enemy.is_alive():
		_advance_turn()
		return
	for c in combatants:
		if c != enemy and c.is_alive():
			enemy.perform_attack(c)
			break
	_update_ui()
	_check_end_conditions()
	_advance_turn()

func _on_skill_pressed() -> void:
	if not in_combat:
		return
	var current = combatants[turn_index]
	if current.unit_name != "Player":
		return
	var target: Node = null
	for c in combatants:
		if c != current and c.is_alive():
			target = c
			break
	if target:
		player_use_skill(target)

func _advance_turn() -> void:
	if not in_combat:
		return
	if combatants.size() == 0:
		return
	turn_index = (turn_index + 1) % combatants.size()
	_start_current_turn()

func end_turn() -> void:
	# UI can call this to force advancing turn (e.g., End Turn button)
	if not in_combat:
		return
	_advance_turn()

func _check_end_conditions() -> void:
	var alive := []
	for c in combatants:
		if c.is_alive():
			alive.append(c)
	if alive.size() <= 1:
		in_combat = false
		var winner = alive[0] if alive.size() == 1 else null
		emit_signal("combat_ended", winner)
		var root = get_parent()
		if root and root.has_node("UI/Info"):
			if alive.size() == 1:
				root.get_node("UI/Info").text = "%s wins!" % [alive[0].unit_name]
			else:
				root.get_node("UI/Info").text = "Draw"

func _on_hp_changed(_new_hp) -> void:
	_update_ui()

func _on_died() -> void:
	_update_ui()

func _update_ui() -> void:
	var root = get_parent()
	if not root:
		return
	if root.has_node("UI/PlayerHP") and root.has_node("Player"):
		root.get_node("UI/PlayerHP").text = "Player HP: %d" % [root.get_node("Player").hp]
	if root.has_node("UI/EnemyHP") and root.has_node("Enemy"):
		root.get_node("UI/EnemyHP").text = "Enemy HP: %d" % [root.get_node("Enemy").hp]
	# enable/disable buttons and show turn/skill status
	var attack_btn = null
	var skill_btn = null
	var start_btn = null
	var end_btn = null
	if root.has_node("UI/AttackButton"):
		attack_btn = root.get_node("UI/AttackButton")
	if root.has_node("UI/SkillButton"):
		skill_btn = root.get_node("UI/SkillButton")
	if root.has_node("UI/StartButton"):
		start_btn = root.get_node("UI/StartButton")
	if root.has_node("UI/EndTurn"):
		end_btn = root.get_node("UI/EndTurn")

	var is_player_turn := false
	if in_combat and combatants.size() > 0:
		var cur = combatants[turn_index]
		is_player_turn = cur.unit_name == "Player"

	# Attack/Skill/EndTurn only active on player's turn
	if attack_btn:
		attack_btn.disabled = not (in_combat and is_player_turn)
	if skill_btn:
		var skill_ready = false
		if in_combat and combatants.size() > 0:
			var c = combatants[turn_index]
			if _skill_used.has(c.get_instance_id()):
				skill_ready = not _skill_used[c.get_instance_id()]
		skill_btn.disabled = not (in_combat and is_player_turn and skill_ready)
	if end_btn:
		end_btn.disabled = not (in_combat and is_player_turn)
	if start_btn:
		start_btn.visible = not in_combat

	if root.has_node("UI/Info"):
		var info = root.get_node("UI/Info")
		if in_combat and combatants.size() > 0:
			var cur2 = combatants[turn_index]
			var skill_ready2 = false
			if _skill_used.has(cur2.get_instance_id()):
				skill_ready2 = not _skill_used[cur2.get_instance_id()]
			info.text = "%s's turn. Skill ready: %s" % [cur2.unit_name, str(skill_ready2)]
		else:
			# leave existing info text
			pass
