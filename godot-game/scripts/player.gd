# player.gd
# Player character for Realm of Rivals
# Handles movement, stats, rendering, and input
extends Node2D
class_name PlayerCharacter

# Stats
var hp: int = 100
var max_hp: int = 100
var attack: int = 15
var defense: int = 10
var charisma: int = 12
var gold: int = 50
var reputation: int = 0
var turn_count: int = 0
var kills: int = 0

# Movement
var tile_pos: Vector2i
var is_moving: bool = false

# Relationship system character object
var character: Character

# Color
const PLAYER_COLOR: Color = Color(0.2, 0.6, 1.0)
const PLAYER_BORDER: Color = Color(0.0, 0.3, 0.8)

# Reference to map (injected)
var map_ref: MapGenerator

signal player_moved(new_tile: Vector2i)
signal player_stats_changed()
signal player_died()
signal adjacent_to_npc(npc: NPCCharacter)

func _ready() -> void:
	# Label for "P"
	var label := Label.new()
	label.text = "P"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(32, 32)
	label.position = Vector2(-16, -16)
	add_child(label)

func setup(char_obj: Character, spawn_tile: Vector2i, map: MapGenerator) -> void:
	character = char_obj
	tile_pos = spawn_tile
	map_ref = map
	_update_world_position()

func _update_world_position() -> void:
	position = Vector2(
		tile_pos.x * MapGenerator.TILE_SIZE + MapGenerator.TILE_SIZE / 2.0,
		tile_pos.y * MapGenerator.TILE_SIZE + MapGenerator.TILE_SIZE / 2.0
	)

func _draw() -> void:
	var size: float = MapGenerator.TILE_SIZE * 0.85
	var half: float = size / 2.0
	# Draw player as a distinct diamond/square
	draw_rect(Rect2(-half, -half, size, size), PLAYER_COLOR)
	draw_rect(Rect2(-half, -half, size, size), PLAYER_BORDER, false, 2.5)
	# Direction indicator (small dot at top)
	draw_circle(Vector2(0, -half + 4), 4, Color.WHITE)

# --- Movement ---

func try_move(direction: Vector2i, npcs: Array) -> bool:
	# Check if the move is valid (no wall, no NPC)
	var new_tile: Vector2i = tile_pos + direction
	if map_ref == null or not map_ref.is_walkable(new_tile.x, new_tile.y):
		return false

	# Check for NPC collision
	for npc in npcs:
		if npc is NPCCharacter and npc.is_alive and npc.tile_pos == new_tile:
			emit_signal("adjacent_to_npc", npc)
			return false

	tile_pos = new_tile
	_update_world_position()
	turn_count += 1
	emit_signal("player_moved", tile_pos)
	return true

func check_adjacency(npcs: Array) -> void:
	# Emit signal if player is adjacent to any NPC (not on same tile)
	var adjacent_dirs: Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for npc in npcs:
		if not (npc is NPCCharacter) or not npc.is_alive:
			continue
		for d in adjacent_dirs:
			if tile_pos + d == npc.tile_pos:
				# NPC is adjacent
				break

# --- Combat ---

func take_damage(amount: int) -> int:
	var actual: int = max(1, amount - defense / 3)
	hp = max(0, hp - actual)
	emit_signal("player_stats_changed")
	if hp <= 0:
		emit_signal("player_died")
	return actual

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	emit_signal("player_stats_changed")

func gain_gold(amount: int) -> void:
	gold += amount
	emit_signal("player_stats_changed")

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	emit_signal("player_stats_changed")
	return true

func gain_reputation(amount: int) -> void:
	reputation += amount
	emit_signal("player_stats_changed")

func is_dead() -> bool:
	return hp <= 0

# --- Stat queries ---

func get_combat_attack() -> int:
	# Charisma bonus at high levels
	var cha_bonus: int = (charisma - 10) / 4
	return attack + cha_bonus

func get_diplomacy_chance(base_chance: float) -> float:
	# Charisma improves dialogue success rates
	var cha_mod: float = (charisma - 10) * 0.03
	return clampf(base_chance + cha_mod, 0.05, 0.95)

# --- Level up / progression ---

func gain_experience_from_encounter(won: bool, rel_type: int) -> void:
	if won:
		kills += 1
		# Stat gains based on enemy type
		if kills % 3 == 0:
			attack += 1
		if kills % 5 == 0:
			max_hp += 10
			hp = mini(hp + 10, max_hp)
		emit_signal("player_stats_changed")
