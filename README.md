GODOT GAME ENGINE TEST RUN

## Turn-based combat prototype

Files added:
- `Script/combatant.gd`   lightweight combatant component (HP, attack, damage, signals).
- `Script/combat_manager.gd`   turn manager (turn order, simple AI, UI wiring).
- `Scenes/Combat.tscn`   test scene with `Player`, `Enemy`, `CombatManager`, and simple UI.

Quick test steps (Godot):

1. Open `Scenes/Combat.tscn` in the Godot editor.
2. Press the `Start Combat` button to begin. The UI labels show HP and `Info` updates.
3. When it's the player's turn press `Attack` to attack the enemy. The enemy will act on its turn.

Integration notes:

- To use your existing character scenes, attach `Script/combatant.gd` to them (or add it as a child node) so the manager can call `take_damage()`/`perform_attack()` and read `hp`.
- You can call `start_combat([player_node, enemy_node])` on the `CombatManager` to begin combat with any nodes.
- Expand the manager to support more actions (skills, items), turn order by stats, or a dedicated combat scene transition.

--SPRITES

--MOVEMENT

--DIALOGUE SYSTEM
