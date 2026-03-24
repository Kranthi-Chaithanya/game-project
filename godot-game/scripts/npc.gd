# npc.gd
# NPC character node for Realm of Rivals
# Handles rendering, stats, dialogue, and relationship integration
extends Node2D
class_name NPCCharacter

# NPC roles
enum Role {
	WARRIOR,
	MERCHANT,
	SCHOLAR,
	ASSASSIN,
	LEADER,
	HEALER,
	SCOUT,
	BANDIT
}

const ROLE_NAMES: Dictionary = {
	Role.WARRIOR:  "Warrior",
	Role.MERCHANT: "Merchant",
	Role.SCHOLAR:  "Scholar",
	Role.ASSASSIN: "Assassin",
	Role.LEADER:   "Leader",
	Role.HEALER:   "Healer",
	Role.SCOUT:    "Scout",
	Role.BANDIT:   "Bandit"
}

# Role colors (used for NPC sprite tint)
const ROLE_COLORS: Dictionary = {
	Role.WARRIOR:  Color(0.85, 0.20, 0.20),
	Role.MERCHANT: Color(0.90, 0.75, 0.15),
	Role.SCHOLAR:  Color(0.55, 0.20, 0.85),
	Role.ASSASSIN: Color(0.15, 0.15, 0.15),
	Role.LEADER:   Color(0.90, 0.50, 0.10),
	Role.HEALER:   Color(0.15, 0.80, 0.40),
	Role.SCOUT:    Color(0.20, 0.65, 0.50),
	Role.BANDIT:   Color(0.60, 0.25, 0.10)
}

# Role and faction mapping (function to avoid cross-class const reference issues)
func get_faction_type() -> int:
	match npc_role:
		Role.WARRIOR:  return FactionManager.FactionType.WARRIORS_LODGE
		Role.MERCHANT: return FactionManager.FactionType.MERCHANTS_GUILD
		Role.SCHOLAR:  return FactionManager.FactionType.SCHOLARS_ORDER
		Role.ASSASSIN: return FactionManager.FactionType.SHADOW_BROTHERHOOD
		Role.LEADER:   return FactionManager.FactionType.INDEPENDENT
		Role.HEALER:   return FactionManager.FactionType.SCHOLARS_ORDER
		Role.SCOUT:    return FactionManager.FactionType.WARRIORS_LODGE
		Role.BANDIT:   return FactionManager.FactionType.INDEPENDENT
	return FactionManager.FactionType.INDEPENDENT

# Stats
var hp: int = 80
var max_hp: int = 80
var attack: int = 10
var defense: int = 8
var charisma: int = 10
var gold: int = 0

# Role and identity
var npc_role: int = Role.WARRIOR  # Role enum value
var tile_pos: Vector2i            # Current tile position on map
var is_in_party: bool = false
var is_alive: bool = true
var is_legacy_nemesis: bool = false  # From a previous run

# Relationship system reference
var character: Character  # The relationship system Character object

# Dialogue lines per relationship type
var dialogue_templates: Dictionary = {
	RelationshipType.Type.ALLY:     ["You have proven yourself worthy, friend.", "Together we are unstoppable!", "What do you need from me?"],
	RelationshipType.Type.FRIEND:   ["Good to see you again!", "I'd fight beside you any day.", "Need any help?"],
	RelationshipType.Type.NEUTRAL:  ["Hmm. What do you want?", "State your business.", "I'm watching you."],
	RelationshipType.Type.RIVAL:    ["You again? I haven't forgotten our last encounter.", "Don't push me.", "We have unfinished business."],
	RelationshipType.Type.NEMESIS:  ["YOU! I have waited for this day!", "I will not rest until you fall!", "This ends NOW!"],
	RelationshipType.Type.BETRAYER: ["After everything I did for you... HOW DARE YOU.", "You will regret betraying me.", "I trusted you!"],
	RelationshipType.Type.MENTOR:   ["Ah, my student. What have you learned?", "I see you've grown stronger.", "Remember what I taught you."]
}

signal npc_interacted(npc: NPCCharacter)
signal npc_defeated(npc: NPCCharacter)

# --- Initialization ---

func setup(char_obj: Character, role: int, tile_position: Vector2i,
		   base_hp: int = 80, base_attack: int = 10, base_defense: int = 8) -> void:
	character = char_obj
	npc_role = role
	tile_pos = tile_position
	max_hp = base_hp
	hp = max_hp
	attack = base_attack
	defense = base_defense
	gold = 10 + randi() % 40

	# Set position in world space
	position = Vector2(tile_pos.x * MapGenerator.TILE_SIZE + MapGenerator.TILE_SIZE / 2.0,
					   tile_pos.y * MapGenerator.TILE_SIZE + MapGenerator.TILE_SIZE / 2.0)
	queue_redraw()

func apply_legacy_bonus(bonus_attack: int, bonus_defense: int) -> void:
	is_legacy_nemesis = true
	attack += bonus_attack
	defense += bonus_defense
	max_hp = int(max_hp * 1.25)
	hp = max_hp
	queue_redraw()

# --- Rendering ---

func _draw() -> void:
	if not is_alive:
		return
	var color: Color = ROLE_COLORS.get(npc_role, Color.WHITE)

	# Draw character body (circle-ish using a rect with rounded feeling)
	var size: float = MapGenerator.TILE_SIZE * 0.75
	var half: float = size / 2.0
	draw_rect(Rect2(-half, -half, size, size), color)

	# Draw border
	var border_color: Color = color.darkened(0.4) if not is_legacy_nemesis else Color(1, 0.2, 0)
	draw_rect(Rect2(-half, -half, size, size), border_color, false, 2.0)

	# In-party indicator (small green dot)
	if is_in_party:
		draw_circle(Vector2(0, -half - 5), 4, Color(0.1, 0.9, 0.3))

	# Legacy nemesis crown indicator
	if is_legacy_nemesis:
		draw_rect(Rect2(-8, -half - 10, 16, 8), Color(1, 0.8, 0))

	# Role initial
	# (labels are handled by Label child node set up via _setup_label)

func _ready() -> void:
	# Add role label as child
	var label := Label.new()
	label.name = "RoleLabel"
	label.text = _get_role_initial()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(32, 32)
	label.position = Vector2(-16, -16)
	add_child(label)

	# Name label above character
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(64, 14)
	name_label.position = Vector2(-32, -30)
	add_child(name_label)

func update_name_label() -> void:
	var lbl = get_node_or_null("NameLabel")
	if lbl and character:
		lbl.text = character.name

func _get_role_initial() -> String:
	match npc_role:
		Role.WARRIOR:  return "W"
		Role.MERCHANT: return "M"
		Role.SCHOLAR:  return "S"
		Role.ASSASSIN: return "A"
		Role.LEADER:   return "L"
		Role.HEALER:   return "H"
		Role.SCOUT:    return "Sc"
		Role.BANDIT:   return "B"
	return "?"

# --- Dialogue ---

func get_greeting(player_char: Character, rel_manager: RelationshipManager) -> String:
	if character == null or rel_manager == null:
		return "..."
	var rel = rel_manager.get_relationship(player_char, character)
	var rel_type: int = RelationshipType.Type.NEUTRAL
	if rel != null:
		rel_type = rel.get_perspective(character)

	var lines: Array = dialogue_templates.get(rel_type, ["..."])
	return lines[randi() % lines.size()]

func get_dialogue_options(player_char: Character, rel_manager: RelationshipManager) -> Array:
	# Returns Array of {text, event_type, reputation_delta, gold_delta}
	var rel = rel_manager.get_relationship(player_char, character) if rel_manager else null
	var rel_type: int = RelationshipType.Type.NEUTRAL
	if rel != null:
		rel_type = rel.get_perspective(player_char)

	var options: Array = []

	# Always available
	options.append({"text": "Attack!", "action": "combat", "event_type": -1})

	match rel_type:
		RelationshipType.Type.ALLY, RelationshipType.Type.FRIEND, RelationshipType.Type.MENTOR:
			options.append({"text": "Ask to join your party", "action": "recruit", "event_type": EventType.Type.DIALOGUE})
			options.append({"text": "Trade (Offer Gift)", "action": "gift", "event_type": EventType.Type.GIFT})
			options.append({"text": "Share information", "action": "dialogue_pos", "event_type": EventType.Type.DIALOGUE})
		RelationshipType.Type.NEUTRAL:
			options.append({"text": "Offer trade", "action": "trade", "event_type": EventType.Type.TRADE})
			options.append({"text": "Negotiate alliance", "action": "alliance", "event_type": EventType.Type.DIALOGUE})
			options.append({"text": "Ask for help", "action": "assistance", "event_type": EventType.Type.ASSISTANCE})
		RelationshipType.Type.RIVAL, RelationshipType.Type.BETRAYER:
			options.append({"text": "Try to negotiate truce", "action": "truce", "event_type": EventType.Type.DIALOGUE})
			options.append({"text": "Offer a gift (apologize)", "action": "gift", "event_type": EventType.Type.GIFT})
		RelationshipType.Type.NEMESIS:
			options.append({"text": "Demand surrender", "action": "combat", "event_type": -1})

	options.append({"text": "Leave", "action": "leave", "event_type": -1})
	return options

# --- Combat stats ---

func get_effective_attack(rel_type: int) -> int:
	var bonus: int = 0
	match rel_type:
		RelationshipType.Type.NEMESIS: bonus = 8   # Nemeses fight harder
		RelationshipType.Type.RIVAL:   bonus = 4
	return attack + bonus

func get_effective_defense(rel_type: int) -> int:
	var bonus: int = 0
	match rel_type:
		RelationshipType.Type.NEMESIS: bonus = 4
	return defense + bonus

func take_damage(amount: int) -> int:
	var actual: int = max(1, amount - defense / 3)
	hp = max(0, hp - actual)
	if hp <= 0:
		is_alive = false
		emit_signal("npc_defeated", self)
	return actual

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)

func is_dead() -> bool:
	return hp <= 0
