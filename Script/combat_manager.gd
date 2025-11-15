extends Node

signal turn_started(current)
signal combat_ended(winner)

var combatants: Array = []
var turn_index: int = 0
var in_combat: bool = false

func _ready() -> void:
    # Try to wire UI if present
    var root = get_parent()
    if not root:
        return
    if root.has_node("UI/AttackButton"):
        root.get_node("UI/AttackButton").connect("pressed", Callable(self, "_on_attack_pressed"))
    if root.has_node("UI/StartButton"):
        root.get_node("UI/StartButton").connect("pressed", Callable(self, "_on_start_pressed"))

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
    if current.unit_name == "Enemy":
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

func _advance_turn() -> void:
    if not in_combat:
        return
    if combatants.size() == 0:
        return
    turn_index = (turn_index + 1) % combatants.size()
    _start_current_turn()

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
