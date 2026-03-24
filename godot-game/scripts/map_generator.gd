# map_generator.gd
# Procedural tile-based map generator for Realm of Rivals
# Generates rooms, corridors, and NPC spawn points
extends Node2D
class_name MapGenerator

# --- Tile constants ---
const TILE_SIZE: int = 32
const MAP_WIDTH: int = 60
const MAP_HEIGHT: int = 40

enum TileType {
	WALL       = 0,
	FLOOR      = 1,
	CORRIDOR   = 2,
	WATER      = 3,
	DUNGEON    = 4,
	MARKET     = 5,
	SETTLEMENT = 6,
	GRASS      = 7
}

enum RoomType {
	SETTLEMENT,
	DUNGEON,
	MARKET,
	WILDERNESS,
	THRONE_ROOM
}

# --- Tile colors for rendering ---
const TILE_COLORS: Dictionary = {
	TileType.WALL:       Color(0.12, 0.12, 0.16),
	TileType.FLOOR:      Color(0.35, 0.30, 0.25),
	TileType.CORRIDOR:   Color(0.28, 0.25, 0.22),
	TileType.WATER:      Color(0.15, 0.30, 0.55),
	TileType.DUNGEON:    Color(0.22, 0.16, 0.16),
	TileType.MARKET:     Color(0.50, 0.44, 0.32),
	TileType.SETTLEMENT: Color(0.42, 0.48, 0.32),
	TileType.GRASS:      Color(0.20, 0.38, 0.16)
}

# --- Room data ---
class Room:
	var x: int
	var y: int
	var w: int
	var h: int
	var room_type: int  # RoomType
	var center: Vector2i

	func _init(rx: int, ry: int, rw: int, rh: int, rtype: int = RoomType.WILDERNESS) -> void:
		x = rx
		y = ry
		w = rw
		h = rh
		room_type = rtype
		center = Vector2i(x + w / 2, y + h / 2)

	func intersects(other: Room) -> bool:
		return (x - 1 < other.x + other.w and x + w + 1 > other.x and
				y - 1 < other.y + other.h and y + h + 1 > other.y)

# --- State ---
var grid: Array = []           # 2D array of TileType
var rooms: Array = []          # Array of Room
var player_spawn: Vector2i     # Tile coords for player start
var npc_spawn_points: Array = [] # Array of {pos: Vector2i, room_type: RoomType}
var rng: RandomNumberGenerator

signal map_generated(player_spawn: Vector2i, npc_spawns: Array)

func _ready() -> void:
	rng = RandomNumberGenerator.new()

# --- Public API ---

func generate(seed: int = 0) -> void:
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()

	_init_grid()
	_generate_rooms()
	_connect_rooms()
	_add_water_features()
	queue_redraw()
	emit_signal("map_generated", player_spawn, npc_spawn_points)

func get_tile(tx: int, ty: int) -> int:
	if tx < 0 or tx >= MAP_WIDTH or ty < 0 or ty >= MAP_HEIGHT:
		return TileType.WALL
	return grid[ty][tx]

func is_walkable(tx: int, ty: int) -> bool:
	var t: int = get_tile(tx, ty)
	return t != TileType.WALL and t != TileType.WATER

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE)

func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos.x * TILE_SIZE + TILE_SIZE / 2.0,
				   tile_pos.y * TILE_SIZE + TILE_SIZE / 2.0)

func get_room_type_at(tile_pos: Vector2i) -> int:
	for room in rooms:
		if tile_pos.x >= room.x and tile_pos.x < room.x + room.w and \
		   tile_pos.y >= room.y and tile_pos.y < room.y + room.h:
			return room.room_type
	return RoomType.WILDERNESS

# --- Private generation methods ---

func _init_grid() -> void:
	grid = []
	for _y in range(MAP_HEIGHT):
		var row: Array = []
		for _x in range(MAP_WIDTH):
			row.append(TileType.WALL)
		grid.append(row)

func _generate_rooms() -> void:
	rooms = []
	npc_spawn_points = []
	var max_attempts: int = 200
	var room_count: int = 12 + rng.randi() % 8  # 12-19 rooms

	# Always have at least one of each important type
	var required_types: Array = [RoomType.SETTLEMENT, RoomType.MARKET, RoomType.DUNGEON]
	var type_index: int = 0

	for _attempt in range(max_attempts):
		if rooms.size() >= room_count:
			break

		var rw: int = 6 + rng.randi() % 8   # 6-13
		var rh: int = 5 + rng.randi() % 7   # 5-11
		var rx: int = 1 + rng.randi() % (MAP_WIDTH - rw - 2)
		var ry: int = 1 + rng.randi() % (MAP_HEIGHT - rh - 2)

		var new_room := Room.new(rx, ry, rw, rh)

		# Check no overlap
		var overlaps: bool = false
		for existing in rooms:
			if new_room.intersects(existing):
				overlaps = true
				break
		if overlaps:
			continue

		# Assign room type
		if type_index < required_types.size():
			new_room.room_type = required_types[type_index]
			type_index += 1
		else:
			var types: Array = [RoomType.WILDERNESS, RoomType.WILDERNESS, RoomType.DUNGEON,
								RoomType.SETTLEMENT, RoomType.MARKET, RoomType.WILDERNESS]
			new_room.room_type = types[rng.randi() % types.size()]

		_carve_room(new_room)
		rooms.append(new_room)

		# Track NPC spawn points
		var num_spawns: int = 1 + rng.randi() % 3
		for i in range(num_spawns):
			var sx: int = new_room.x + 1 + rng.randi() % max(1, new_room.w - 2)
			var sy: int = new_room.y + 1 + rng.randi() % max(1, new_room.h - 2)
			npc_spawn_points.append({"pos": Vector2i(sx, sy), "room_type": new_room.room_type})

	# First room = player start
	if rooms.size() > 0:
		player_spawn = rooms[0].center
		# Remove any NPC spawns too close to player
		npc_spawn_points = npc_spawn_points.filter(func(sp):
			return sp["pos"].distance_to(player_spawn) > 5
		)

func _carve_room(room: Room) -> void:
	var tile_type: int
	match room.room_type:
		RoomType.DUNGEON:    tile_type = TileType.DUNGEON
		RoomType.MARKET:     tile_type = TileType.MARKET
		RoomType.SETTLEMENT: tile_type = TileType.SETTLEMENT
		_:                   tile_type = TileType.FLOOR

	for y in range(room.y, room.y + room.h):
		for x in range(room.x, room.x + room.w):
			grid[y][x] = tile_type

func _connect_rooms() -> void:
	# Connect each room to the next in list using L-shaped corridors
	for i in range(rooms.size() - 1):
		var a: Vector2i = rooms[i].center
		var b: Vector2i = rooms[i + 1].center
		if rng.randi() % 2 == 0:
			_carve_h_corridor(a.x, b.x, a.y)
			_carve_v_corridor(a.y, b.y, b.x)
		else:
			_carve_v_corridor(a.y, b.y, a.x)
			_carve_h_corridor(a.x, b.x, b.y)

func _carve_h_corridor(x1: int, x2: int, y: int) -> void:
	for x in range(min(x1, x2), max(x1, x2) + 1):
		if y >= 0 and y < MAP_HEIGHT and x >= 0 and x < MAP_WIDTH:
			if grid[y][x] == TileType.WALL:
				grid[y][x] = TileType.CORRIDOR

func _carve_v_corridor(y1: int, y2: int, x: int) -> void:
	for y in range(min(y1, y2), max(y1, y2) + 1):
		if y >= 0 and y < MAP_HEIGHT and x >= 0 and x < MAP_WIDTH:
			if grid[y][x] == TileType.WALL:
				grid[y][x] = TileType.CORRIDOR

func _add_water_features() -> void:
	# Add small pools of water in wilderness areas
	var pool_count: int = 2 + rng.randi() % 4
	for _p in range(pool_count):
		var px: int = 2 + rng.randi() % (MAP_WIDTH - 4)
		var py: int = 2 + rng.randi() % (MAP_HEIGHT - 4)
		# Only place water on walls (open areas outside rooms)
		if grid[py][px] == TileType.WALL:
			var pw: int = 2 + rng.randi() % 4
			var ph: int = 2 + rng.randi() % 3
			for wy in range(py, min(py + ph, MAP_HEIGHT - 1)):
				for wx in range(px, min(px + pw, MAP_WIDTH - 1)):
					if grid[wy][wx] == TileType.WALL:
						grid[wy][wx] = TileType.WATER

# --- Rendering ---

func _draw() -> void:
	# Draw only tiles in a reasonable viewport area (optimized)
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var tile_type: int = grid[y][x]
			var color: Color = TILE_COLORS.get(tile_type, Color(0.5, 0.5, 0.5))
			draw_rect(
				Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE - 1, TILE_SIZE - 1),
				color
			)

	# Draw grid lines for floor tiles (subtle)
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var t: int = grid[y][x]
			if t != TileType.WALL and t != TileType.WATER:
				draw_rect(
					Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE),
					Color(0, 0, 0, 0.15),
					false
				)
