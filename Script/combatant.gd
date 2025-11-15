extends Node2D

signal hp_changed(new_hp)
signal died()

@export var unit_name: String = "Combatant"
@export var max_hp: int = 100
@export var attack_power: int = 10

var hp: int = 0

func _ready() -> void:
    hp = max_hp
    emit_signal("hp_changed", hp)

func is_alive() -> bool:
    return hp > 0

func take_damage(amount: int) -> void:
    hp = max(0, hp - amount)
    emit_signal("hp_changed", hp)
    if hp == 0:
        emit_signal("died")

func perform_attack(target: Node) -> void:
    if not is_alive():
        return
    if target and target.has_method("take_damage"):
        target.take_damage(attack_power)
