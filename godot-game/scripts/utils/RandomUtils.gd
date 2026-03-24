# RandomUtils.gd
# Utility functions for random number generation and array operations
class_name RandomUtils

# Pick a random element from an array
static func random_choice(arr: Array, rng: RandomNumberGenerator = null) -> Variant:
	if arr.is_empty():
		return null
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return arr[rng.randi() % arr.size()]

# Shuffle an array in place (Fisher-Yates)
static func shuffle(arr: Array, rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

# Return a random int in [low, high] inclusive
static func rand_range_int(low: int, high: int, rng: RandomNumberGenerator = null) -> int:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return low + (rng.randi() % (high - low + 1))

# Weighted random choice: weights is an Array of floats matching arr
static func weighted_choice(arr: Array, weights: Array, rng: RandomNumberGenerator = null) -> Variant:
	if arr.is_empty() or weights.is_empty():
		return null
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var total: float = 0.0
	for w in weights:
		total += float(w)
	var roll: float = rng.randf() * total
	var cumulative: float = 0.0
	for i in range(arr.size()):
		cumulative += float(weights[i])
		if roll <= cumulative:
			return arr[i]
	return arr[arr.size() - 1]

# Clamp an integer
static func clamp_int(value: int, lo: int, hi: int) -> int:
	return clampi(value, lo, hi)

# Return true with a given probability (0.0 - 1.0)
static func chance(probability: float, rng: RandomNumberGenerator = null) -> bool:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return rng.randf() < probability
