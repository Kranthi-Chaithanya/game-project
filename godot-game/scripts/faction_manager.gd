# faction_manager.gd
# Manages factions, party members, and inter-faction relationships
extends Node
class_name FactionManager

enum FactionType {
	PLAYER_FACTION,
	MERCHANTS_GUILD,
	WARRIORS_LODGE,
	SCHOLARS_ORDER,
	SHADOW_BROTHERHOOD,
	INDEPENDENT
}

const FACTION_NAMES: Dictionary = {
	FactionType.PLAYER_FACTION:     "The Vanguard",
	FactionType.MERCHANTS_GUILD:    "Merchant's Guild",
	FactionType.WARRIORS_LODGE:     "Warrior's Lodge",
	FactionType.SCHOLARS_ORDER:     "Scholar's Order",
	FactionType.SHADOW_BROTHERHOOD: "Shadow Brotherhood",
	FactionType.INDEPENDENT:        "Independent"
}

# faction_id -> { name, reputation, members: Array[char_id], morale: int }
var factions: Dictionary = {}
var party_members: Array = []  # Array of NPC character IDs in player's party
var party_morale: int = 100    # 0-100

var relationship_manager: RelationshipManager  # injected by Main

signal party_member_added(npc_name: String)
signal party_member_removed(npc_name: String, reason: String)
signal morale_changed(new_morale: int)
signal faction_reputation_changed(faction: int, delta: int)

func _ready() -> void:
	_init_factions()

func set_relationship_manager(rm: RelationshipManager) -> void:
	relationship_manager = rm

func _init_factions() -> void:
	for faction_type in FactionType.values():
		factions[faction_type] = {
			"name": FACTION_NAMES.get(faction_type, "Unknown"),
			"reputation": 0,
			"members": [],
			"morale": 100
		}

# --- Party management ---

func add_to_party(npc) -> bool:
	if party_members.size() >= 4:
		return false
	var char_id: String = npc.character.id
	if party_members.has(char_id):
		return false
	party_members.append(char_id)
	npc.is_in_party = true
	emit_signal("party_member_added", npc.character.name)
	_recalculate_morale()
	return true

func remove_from_party(npc, reason: String = "left") -> void:
	var char_id: String = npc.character.id
	if party_members.has(char_id):
		party_members.erase(char_id)
		npc.is_in_party = false
		emit_signal("party_member_removed", npc.character.name, reason)
		_recalculate_morale()

func get_party_size() -> int:
	return party_members.size()

func is_in_party(char_id: String) -> bool:
	return party_members.has(char_id)

# --- Morale system ---

func _recalculate_morale() -> void:
	if relationship_manager == null or party_members.is_empty():
		party_morale = 100
		emit_signal("morale_changed", party_morale)
		return

	# Morale starts at 100 and decreases for rival pairings in party
	var morale: int = 100
	for i in range(party_members.size()):
		for j in range(i + 1, party_members.size()):
			var char_a = _get_char_by_id(party_members[i])
			var char_b = _get_char_by_id(party_members[j])
			if char_a == null or char_b == null:
				continue
			var rel = relationship_manager.get_relationship(char_a, char_b)
			if rel == null:
				continue
			var perspective_a = rel.get_perspective(char_a)
			match perspective_a:
				RelationshipType.Type.NEMESIS:  morale -= 25
				RelationshipType.Type.RIVAL:    morale -= 15
				RelationshipType.Type.BETRAYER: morale -= 20
				RelationshipType.Type.FRIEND:   morale += 5
				RelationshipType.Type.ALLY:     morale += 10

	party_morale = clampi(morale, 0, 100)
	emit_signal("morale_changed", party_morale)

func _get_char_by_id(char_id: String) -> Character:
	# This is resolved at runtime via the relationship manager
	if relationship_manager == null:
		return null
	for char_obj in relationship_manager._characters.values():
		if char_obj.id == char_id:
			return char_obj
	return null

# --- Faction reputation ---

func change_faction_reputation(faction_type: int, delta: int) -> void:
	if factions.has(faction_type):
		factions[faction_type]["reputation"] = clampi(
			factions[faction_type]["reputation"] + delta, -100, 100
		)
		emit_signal("faction_reputation_changed", faction_type, delta)

func get_faction_reputation(faction_type: int) -> int:
	if factions.has(faction_type):
		return factions[faction_type].get("reputation", 0)
	return 0

func get_faction_name(faction_type: int) -> String:
	return FACTION_NAMES.get(faction_type, "Unknown")

func get_faction_status(faction_type: int) -> String:
	var rep: int = get_faction_reputation(faction_type)
	if rep >= 60:   return "Revered"
	elif rep >= 30: return "Friendly"
	elif rep >= -10: return "Neutral"
	elif rep >= -40: return "Hostile"
	else:            return "Hated"

# --- Assign role in faction ---

func assign_role(char_id: String, role: String) -> void:
	# Role assignment affects morale and relationship modifiers (could be extended)
	pass

# --- Morale effects ---

func get_morale_combat_bonus() -> int:
	# High morale gives attack bonus, low gives penalty
	if party_morale >= 80:
		return 3
	elif party_morale >= 50:
		return 0
	elif party_morale >= 25:
		return -3
	else:
		return -7
