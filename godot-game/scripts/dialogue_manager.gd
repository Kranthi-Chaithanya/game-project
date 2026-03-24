# dialogue_manager.gd
# Manages dialogue trees and diplomacy interactions
# Dialogue choices affect relationships through the RelationshipManager
extends Node
class_name DialogueManager

var relationship_manager: RelationshipManager
var faction_manager: FactionManager
var player: PlayerCharacter
var current_npc: NPCCharacter

signal dialogue_started(npc: NPCCharacter, greeting: String, options: Array)
signal dialogue_option_chosen(option: Dictionary)
signal dialogue_ended(npc: NPCCharacter)
signal relationship_notification(text: String, color: Color)
signal gold_transferred(amount: int, to_player: bool)
signal combat_requested(npc: NPCCharacter)

func setup(rel_mgr: RelationshipManager, fac_mgr: FactionManager, p: PlayerCharacter) -> void:
	relationship_manager = rel_mgr
	faction_manager = fac_mgr
	player = p

# --- Start dialogue ---

func start_dialogue(npc: NPCCharacter) -> void:
	current_npc = npc
	var greeting: String = npc.get_greeting(player.character, relationship_manager)
	var options: Array = npc.get_dialogue_options(player.character, relationship_manager)
	emit_signal("dialogue_started", npc, greeting, options)

# --- Process player choice ---

func choose_option(option: Dictionary) -> void:
	if current_npc == null:
		return
	emit_signal("dialogue_option_chosen", option)
	var action: String = option.get("action", "leave")

	match action:
		"combat":
			emit_signal("dialogue_ended", current_npc)
			emit_signal("combat_requested", current_npc)
		"leave":
			_fire_event(EventType.Type.DIALOGUE, player.character, current_npc.character,
						"Peaceful departure from %s" % current_npc.character.name)
			emit_signal("dialogue_ended", current_npc)
		"recruit":
			_try_recruit()
		"gift":
			_try_gift()
		"trade":
			_try_trade()
		"alliance":
			_try_alliance()
		"truce":
			_try_truce()
		"assistance":
			_try_assistance()
		"dialogue_pos":
			_positive_dialogue()
		_:
			emit_signal("dialogue_ended", current_npc)

# --- Action handlers ---

func _try_recruit() -> bool:
	if faction_manager == null:
		return false
	if faction_manager.party_members.size() >= 4:
		_notify("Your party is full! (max 4)", Color(0.9, 0.6, 0.2))
		emit_signal("dialogue_ended", current_npc)
		return false

	var success_chance: float = player.get_diplomacy_chance(0.5)
	var rel = relationship_manager.get_relationship(player.character, current_npc.character) if relationship_manager else null
	if rel != null:
		match rel.get_perspective(current_npc.character):
			RelationshipType.Type.ALLY:   success_chance = 0.95
			RelationshipType.Type.FRIEND: success_chance = 0.80
			RelationshipType.Type.NEUTRAL: success_chance = 0.45
			RelationshipType.Type.RIVAL:  success_chance = 0.15
			RelationshipType.Type.NEMESIS: success_chance = 0.02

	if randf() < success_chance:
		faction_manager.add_to_party(current_npc)
		_fire_event(EventType.Type.QUEST, player.character, current_npc.character,
					"%s joined the player's party" % current_npc.character.name)
		_notify("✅ %s joins your party!" % current_npc.character.name, Color(0.2, 0.9, 0.3))
	else:
		_fire_event(EventType.Type.DIALOGUE, player.character, current_npc.character,
					"Failed to recruit %s" % current_npc.character.name)
		_notify("❌ %s refuses to join you." % current_npc.character.name, Color(0.8, 0.3, 0.2))
	emit_signal("dialogue_ended", current_npc)
	return true

func _try_gift() -> void:
	var cost: int = 15
	if not player.spend_gold(cost):
		_notify("Not enough gold! (need %d)" % cost, Color(0.9, 0.6, 0.1))
		emit_signal("dialogue_ended", current_npc)
		return
	_fire_event(EventType.Type.GIFT, player.character, current_npc.character,
				"Player gifted %s (%dg)" % [current_npc.character.name, cost])
	_notify("🎁 You gift %d gold to %s. They seem pleased." % [cost, current_npc.character.name],
			Color(0.3, 0.8, 0.9))
	emit_signal("dialogue_ended", current_npc)

func _try_trade() -> void:
	# Simple trade: pay gold, get small positive relationship
	var cost: int = 10
	if not player.spend_gold(cost):
		_notify("Not enough gold to trade! (need %d)" % cost, Color(0.9, 0.6, 0.1))
		emit_signal("dialogue_ended", current_npc)
		return
	# Trade gives player back some gold and health
	var gold_return: int = 5 + randi() % 15
	player.gain_gold(gold_return)
	_fire_event(EventType.Type.TRADE, player.character, current_npc.character,
				"Trade with %s" % current_npc.character.name)
	_notify("🛒 Trade with %s! Profit: %dg" % [current_npc.character.name, gold_return - cost],
			Color(0.9, 0.8, 0.2))
	emit_signal("dialogue_ended", current_npc)

func _try_alliance() -> void:
	var success: float = player.get_diplomacy_chance(0.45)
	if randf() < success:
		_fire_event(EventType.Type.QUEST, player.character, current_npc.character,
					"Alliance formed with %s" % current_npc.character.name)
		if relationship_manager:
			relationship_manager.change_type(player.character, current_npc.character,
				RelationshipType.Type.ALLY, RelationshipType.Type.ALLY)
		_notify("🤝 Alliance formed with %s!" % current_npc.character.name, Color(0.2, 0.9, 0.4))
		# Faction rep boost
		if faction_manager:
			faction_manager.change_faction_reputation(current_npc.get_faction_type(), 15)
	else:
		_notify("🤚 %s doesn't trust you enough for an alliance." % current_npc.character.name,
				Color(0.7, 0.5, 0.2))
	emit_signal("dialogue_ended", current_npc)

func _try_truce() -> void:
	var success: float = player.get_diplomacy_chance(0.35)
	if randf() < success:
		_fire_event(EventType.Type.DIALOGUE, player.character, current_npc.character,
					"Truce negotiated with %s" % current_npc.character.name)
		if relationship_manager:
			relationship_manager.change_type(player.character, current_npc.character,
				RelationshipType.Type.NEUTRAL, RelationshipType.Type.NEUTRAL)
		_notify("☮ Truce established with %s." % current_npc.character.name, Color(0.7, 0.9, 0.5))
	else:
		_notify("💢 %s rejects your offer of truce!" % current_npc.character.name, Color(0.9, 0.3, 0.2))
	emit_signal("dialogue_ended", current_npc)

func _try_assistance() -> void:
	_fire_event(EventType.Type.ASSISTANCE, player.character, current_npc.character,
				"Player helped %s" % current_npc.character.name)
	var heal_amount: int = 5 + randi() % 10
	_notify("🙏 You help %s. They may remember this. (+%d HP)" % [current_npc.character.name, heal_amount],
			Color(0.3, 0.9, 0.6))
	player.heal(heal_amount)
	emit_signal("dialogue_ended", current_npc)

func _positive_dialogue() -> void:
	_fire_event(EventType.Type.DIALOGUE, player.character, current_npc.character,
				"Positive conversation with %s" % current_npc.character.name)
	_notify("💬 Good conversation with %s." % current_npc.character.name, Color(0.5, 0.8, 0.9))
	emit_signal("dialogue_ended", current_npc)

# --- Helpers ---

func _fire_event(evt_type: int, source: Character, target: Character, desc: String) -> void:
	if relationship_manager == null:
		return
	var event := RelationshipEvent.new(evt_type, source, target, desc)
	relationship_manager.process_event(event)

	# Get the updated relationship for notification
	var rel = relationship_manager.get_relationship(source, target)
	if rel != null:
		var rel_type: int = rel.get_perspective(source)
		var rel_name: String = _rel_type_name(rel_type)
		var color: Color = _rel_type_color(rel_type)
		_notify("Relationship with %s: %s (intensity: %d)" % [target.name, rel_name, rel.intensity], color)

func _notify(text: String, color: Color) -> void:
	emit_signal("relationship_notification", text, color)

func _rel_type_name(rel_type: int) -> String:
	match rel_type:
		RelationshipType.Type.NEMESIS:  return "NEMESIS"
		RelationshipType.Type.RIVAL:    return "Rival"
		RelationshipType.Type.BETRAYER: return "Betrayer"
		RelationshipType.Type.NEUTRAL:  return "Neutral"
		RelationshipType.Type.FRIEND:   return "Friend"
		RelationshipType.Type.ALLY:     return "Ally"
		RelationshipType.Type.MENTOR:   return "Mentor"
	return "Unknown"

func _rel_type_color(rel_type: int) -> Color:
	match rel_type:
		RelationshipType.Type.NEMESIS:  return Color(0.9, 0.1, 0.1)
		RelationshipType.Type.RIVAL:    return Color(0.9, 0.4, 0.1)
		RelationshipType.Type.BETRAYER: return Color(0.7, 0.1, 0.5)
		RelationshipType.Type.NEUTRAL:  return Color(0.8, 0.8, 0.2)
		RelationshipType.Type.FRIEND:   return Color(0.3, 0.8, 0.3)
		RelationshipType.Type.ALLY:     return Color(0.1, 0.9, 0.5)
		RelationshipType.Type.MENTOR:   return Color(0.5, 0.7, 1.0)
	return Color.WHITE
