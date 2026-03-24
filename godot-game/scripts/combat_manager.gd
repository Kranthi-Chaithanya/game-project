# combat_manager.gd
# Manages turn-based combat encounters in Realm of Rivals
# Relationships affect combat bonuses, post-combat choices affect relationships
extends Node
class_name CombatManager

enum CombatState { IDLE, PLAYER_TURN, ENEMY_TURN, VICTORY, DEFEAT, FLED }

enum PlayerAction { ATTACK, DEFEND, SPECIAL, FLEE, MERCY }

var state: int = CombatState.IDLE
var player: PlayerCharacter
var enemy: NPCCharacter
var relationship_manager: RelationshipManager
var faction_manager: FactionManager

var player_defending: bool = false
var round_count: int = 0
var combat_log: Array = []  # Array of String messages

signal combat_started(player: PlayerCharacter, enemy: NPCCharacter)
signal combat_log_updated(message: String)
signal player_turn_started()
signal enemy_turn_started()
signal combat_ended(outcome: int, enemy: NPCCharacter)
signal relationship_event_occurred(event: RelationshipEvent)

# --- Start combat ---

func start_combat(p: PlayerCharacter, e: NPCCharacter,
				  rel_mgr: RelationshipManager, fac_mgr: FactionManager) -> void:
	player = p
	enemy = e
	relationship_manager = rel_mgr
	faction_manager = fac_mgr
	state = CombatState.PLAYER_TURN
	round_count = 0
	combat_log = []
	player_defending = false

	var greeting: String = _get_combat_intro()
	_log(greeting)
	emit_signal("combat_started", player, enemy)
	emit_signal("player_turn_started")

func _get_combat_intro() -> String:
	if relationship_manager == null:
		return "%s engages you in combat!" % enemy.character.name
	var rel = relationship_manager.get_relationship(player.character, enemy.character)
	if rel == null:
		return "%s blocks your path!" % enemy.character.name
	var rel_type: int = rel.get_perspective(enemy.character)
	match rel_type:
		RelationshipType.Type.NEMESIS:
			return "⚔ YOUR NEMESIS %s confronts you with burning hatred!" % enemy.character.name
		RelationshipType.Type.RIVAL:
			return "⚔ Your rival %s steps forward: \"We settle this NOW!\"" % enemy.character.name
		RelationshipType.Type.BETRAYER:
			return "⚔ The betrayer %s draws their weapon!" % enemy.character.name
		_:
			return "⚔ %s (the %s) challenges you!" % [enemy.character.name, NPCCharacter.ROLE_NAMES.get(enemy.npc_role, "?")]

# --- Player actions ---

func player_attack() -> void:
	if state != CombatState.PLAYER_TURN:
		return
	player_defending = false
	round_count += 1

	# Calculate damage
	var rel_bonus: int = _get_player_rel_bonus()
	var dmg_roll: int = player.get_combat_attack() + rel_bonus + randi() % 6
	var actual_dmg: int = enemy.take_damage(dmg_roll)
	_log("You attack %s for %d damage! (HP: %d/%d)" % [
		enemy.character.name, actual_dmg, enemy.hp, enemy.max_hp
	])

	# Fire combat event
	_fire_event(EventType.Type.COMBAT, player.character, enemy.character,
				"Player attacked %s in combat" % enemy.character.name)

	if enemy.is_dead():
		_on_enemy_defeated()
	else:
		state = CombatState.ENEMY_TURN
		emit_signal("enemy_turn_started")
		_enemy_act()

func player_defend() -> void:
	if state != CombatState.PLAYER_TURN:
		return
	player_defending = true
	round_count += 1
	_log("You take a defensive stance. (+50% defense this round)")
	state = CombatState.ENEMY_TURN
	emit_signal("enemy_turn_started")
	_enemy_act()

func player_special() -> void:
	if state != CombatState.PLAYER_TURN:
		return
	player_defending = false
	round_count += 1

	# Special: powerful attack but costs HP
	var cost: int = 8
	if player.hp <= cost + 5:
		_log("You don't have enough HP for a power strike!")
		return

	player.take_damage(cost)
	var dmg_roll: int = int(player.get_combat_attack() * 1.8) + randi() % 10
	var actual_dmg: int = enemy.take_damage(dmg_roll)
	_log("⚡ POWER STRIKE! You deal %d damage at cost of %d HP!" % [actual_dmg, cost])

	if enemy.is_dead():
		_on_enemy_defeated()
	else:
		state = CombatState.ENEMY_TURN
		emit_signal("enemy_turn_started")
		_enemy_act()

func player_flee() -> void:
	if state != CombatState.PLAYER_TURN:
		return
	# Flee success depends on relationship and stats
	var flee_chance: float = 0.6
	var rel_type: int = _get_enemy_rel_type_toward_player()
	if rel_type == RelationshipType.Type.NEMESIS:
		flee_chance = 0.3  # Hard to escape nemesis
	elif rel_type == RelationshipType.Type.RIVAL:
		flee_chance = 0.5

	if randf() < flee_chance:
		_log("You manage to escape!")
		state = CombatState.FLED
		emit_signal("combat_ended", CombatState.FLED, enemy)
	else:
		_log("You failed to flee!")
		state = CombatState.ENEMY_TURN
		emit_signal("enemy_turn_started")
		_enemy_act()

func player_mercy() -> void:
	if state != CombatState.PLAYER_TURN:
		return
	# Mercy: offer to spare the enemy (requires some damage dealt)
	if enemy.hp > enemy.max_hp * 0.5:
		_log("You haven't weakened %s enough to negotiate mercy." % enemy.character.name)
		return

	var accept_chance: float = _get_mercy_accept_chance()
	if randf() < accept_chance:
		_log("💛 %s accepts your mercy! They lower their weapon." % enemy.character.name)
		_fire_event(EventType.Type.DIALOGUE, player.character, enemy.character,
					"Player showed mercy to %s" % enemy.character.name)
		# Mercy shifts relationship toward neutral/friend
		_fire_event(EventType.Type.ASSISTANCE, player.character, enemy.character,
					"Mercy extended to %s" % enemy.character.name)
		state = CombatState.VICTORY
		emit_signal("combat_ended", CombatState.VICTORY, enemy)
	else:
		_log("💢 %s refuses your mercy and attacks!" % enemy.character.name)
		state = CombatState.ENEMY_TURN
		emit_signal("enemy_turn_started")
		_enemy_act()

# --- Enemy AI ---

func _enemy_act() -> void:
	if state != CombatState.ENEMY_TURN:
		return
	await get_tree().process_frame  # Small delay for readability

	var rel_type: int = _get_enemy_rel_type_toward_player()
	var dmg_roll: int = enemy.get_effective_attack(rel_type) + randi() % 5

	# Defensive player takes less damage
	if player_defending:
		dmg_roll = int(dmg_roll * 0.5)

	var actual_dmg: int = player.take_damage(dmg_roll)
	_log("%s attacks you for %d damage! (Your HP: %d/%d)" % [
		enemy.character.name, actual_dmg, player.hp, player.max_hp
	])

	if player.is_dead():
		state = CombatState.DEFEAT
		_log("💀 You have been defeated...")
		emit_signal("combat_ended", CombatState.DEFEAT, enemy)
	else:
		state = CombatState.PLAYER_TURN
		emit_signal("player_turn_started")

# --- Post-combat ---

func _on_enemy_defeated() -> void:
	state = CombatState.VICTORY
	_log("✅ %s has been defeated!" % enemy.character.name)
	emit_signal("combat_ended", CombatState.VICTORY, enemy)

# Apply post-combat relationship outcome
func apply_execution(player_char: Character, enemy_char: Character) -> void:
	_fire_event(EventType.Type.MURDER, player_char, enemy_char,
				"Player executed %s" % enemy_char.name)
	_log("You execute %s. Some will remember this cruelty." % enemy_char.name)

func apply_spare(player_char: Character, enemy_char: Character) -> void:
	_fire_event(EventType.Type.RESCUE, player_char, enemy_char,
				"Player spared %s's life" % enemy_char.name)
	_log("You spare %s. They might become a future ally." % enemy_char.name)

# --- Helpers ---

func _get_player_rel_bonus() -> int:
	if relationship_manager == null:
		return 0
	var rel = relationship_manager.get_relationship(player.character, enemy.character)
	if rel == null:
		return 0
	match rel.get_perspective(player.character):
		RelationshipType.Type.NEMESIS: return -3  # Emotional conflict: you fight worse against your own nemesis
		RelationshipType.Type.RIVAL:   return 2   # Rivalry sharpens your combat against a rival
		RelationshipType.Type.ALLY:    return -5   # Hard to attack someone you consider an ally
		_:                              return 0

func _get_enemy_rel_type_toward_player() -> int:
	if relationship_manager == null:
		return RelationshipType.Type.NEUTRAL
	var rel = relationship_manager.get_relationship(player.character, enemy.character)
	if rel == null:
		return RelationshipType.Type.NEUTRAL
	return rel.get_perspective(enemy.character)

func _get_mercy_accept_chance() -> float:
	var rel_type: int = _get_enemy_rel_type_toward_player()
	match rel_type:
		RelationshipType.Type.NEMESIS:  return 0.05
		RelationshipType.Type.RIVAL:    return 0.25
		RelationshipType.Type.NEUTRAL:  return 0.55
		RelationshipType.Type.FRIEND:   return 0.80
		RelationshipType.Type.ALLY:     return 0.90
		_:                               return 0.40

func _fire_event(evt_type: int, source: Character, target: Character, desc: String) -> void:
	if relationship_manager == null:
		return
	var event := RelationshipEvent.new(evt_type, source, target, desc)
	relationship_manager.process_event(event)
	emit_signal("relationship_event_occurred", event)

func _log(msg: String) -> void:
	combat_log.append(msg)
	emit_signal("combat_log_updated", msg)
