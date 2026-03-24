# NameGenerator.gd
# Generates random fantasy names for NPCs and places
class_name NameGenerator

const PREFIXES: Array = [
	"Aer", "Bor", "Cal", "Dar", "Eld", "Fer", "Gar", "Hel",
	"Ira", "Jor", "Kel", "Lor", "Mor", "Nar", "Orin", "Por",
	"Ral", "Sar", "Tar", "Ur", "Val", "Wor", "Xal", "Yar", "Zor"
]

const SUFFIXES: Array = [
	"an", "en", "on", "in", "ar", "el", "is", "os",
	"ath", "eth", "ith", "oth", "ax", "ex", "ix", "ox",
	"wyn", "dor", "nor", "mal", "ric", "gar", "ald", "ard"
]

const PLACE_PREFIXES: Array = [
	"Iron", "Stone", "Dark", "Storm", "Silver", "Gold", "Black",
	"White", "Red", "Shadow", "Sun", "Moon", "Wolf", "Eagle", "Bear"
]

const PLACE_SUFFIXES: Array = [
	"haven", "ford", "burg", "holm", "vale", "moor", "keep",
	"gate", "bridge", "well", "wood", "ridge", "cliff", "peak", "reach"
]

# Generate a random character name
static func generate_name(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var prefix = PREFIXES[rng.randi() % PREFIXES.size()]
	var suffix = SUFFIXES[rng.randi() % SUFFIXES.size()]
	return prefix + suffix

# Generate a random place name
static func generate_place_name(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var prefix = PLACE_PREFIXES[rng.randi() % PLACE_PREFIXES.size()]
	var suffix = PLACE_SUFFIXES[rng.randi() % PLACE_SUFFIXES.size()]
	return prefix + suffix

# Generate a list of unique names
static func generate_unique_names(count: int, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var names: Array = []
	var attempts: int = 0
	while names.size() < count and attempts < count * 10:
		var new_name = generate_name(rng)
		if not names.has(new_name):
			names.append(new_name)
		attempts += 1
	return names
