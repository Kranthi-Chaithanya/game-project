# legacy_manager.gd
# Persists relationship and nemesis data between runs (roguelike legacy system)
# Data is saved to user://legacy_data.json
extends Node
class_name LegacyManager

const SAVE_PATH: String = "user://realm_of_rivals_legacy.json"
const MAX_LEGACY_NEMESES: int = 5

# Persistent data structure
var legacy_data: Dictionary = {
	"run_count": 0,
	"nemeses": [],        # Array of NemesisRecord dicts
	"reputation": 0,      # Cumulative reputation across runs
	"total_kills": 0,
	"best_run_turns": 0,
	"unlocked_faction_bonuses": []
}

signal legacy_loaded(data: Dictionary)
signal legacy_saved()

func _ready() -> void:
	load_legacy()

# --- Save/Load ---

func save_legacy() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(legacy_data, "\t"))
		file.close()
		emit_signal("legacy_saved")

func load_legacy() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content: String = file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(content)
		if parsed is Dictionary:
			legacy_data = parsed
			emit_signal("legacy_loaded", legacy_data)

func reset_legacy() -> void:
	legacy_data = {
		"run_count": 0,
		"nemeses": [],
		"reputation": 0,
		"total_kills": 0,
		"best_run_turns": 0,
		"unlocked_faction_bonuses": []
	}
	save_legacy()

# --- Run completion ---

func complete_run(survived: bool, turns_lasted: int, kills: int, reputation_gained: int) -> void:
	legacy_data["run_count"] = legacy_data.get("run_count", 0) + 1
	legacy_data["total_kills"] = legacy_data.get("total_kills", 0) + kills
	legacy_data["reputation"] = legacy_data.get("reputation", 0) + reputation_gained
	if survived or legacy_data.get("best_run_turns", 0) < turns_lasted:
		legacy_data["best_run_turns"] = turns_lasted
	save_legacy()

# --- Nemesis system ---

# Record a character as a nemesis for the next run
func record_nemesis(char_id: String, char_name: String, role: String,
					kill_count: int, intensity: int) -> void:
	var nemeses: Array = legacy_data.get("nemeses", [])

	# Check if already recorded
	for n in nemeses:
		if n.get("id") == char_id:
			n["kill_count"] = n.get("kill_count", 0) + kill_count
			n["intensity"] = clampi(n.get("intensity", intensity) - 10, -100, -30)
			n["times_encountered"] = n.get("times_encountered", 0) + 1
			save_legacy()
			return

	# Add new nemesis record
	var record: Dictionary = {
		"id": char_id,
		"name": char_name,
		"role": role,
		"kill_count": kill_count,
		"intensity": clampi(intensity - 20, -100, -30),
		"times_encountered": 1,
		"evolved": false
	}
	nemeses.append(record)

	# Cap nemesis list — keep the strongest (most negative intensity = most hostile)
	while nemeses.size() > MAX_LEGACY_NEMESES:
		nemeses.sort_custom(func(a, b): return a.get("intensity", 0) < b.get("intensity", 0))
		nemeses.pop_back()

	legacy_data["nemeses"] = nemeses
	save_legacy()

# Remove a nemesis (e.g., player defeated them permanently)
func remove_nemesis(char_id: String) -> void:
	var nemeses: Array = legacy_data.get("nemeses", [])
	legacy_data["nemeses"] = nemeses.filter(func(n): return n.get("id") != char_id)
	save_legacy()

# Get all legacy nemeses, evolved with increased stats
func get_legacy_nemeses() -> Array:
	var nemeses: Array = legacy_data.get("nemeses", [])
	var result: Array = []
	for n in nemeses:
		var evolved: Dictionary = n.duplicate()
		# Nemeses grow stronger each run they persist
		var runs: int = legacy_data.get("run_count", 1)
		evolved["bonus_attack"] = mini(runs * 2, 20)
		evolved["bonus_defense"] = mini(runs, 10)
		evolved["evolved"] = runs >= 2
		result.append(evolved)
	return result

# --- Queries ---

func get_run_count() -> int:
	return legacy_data.get("run_count", 0)

func get_total_reputation() -> int:
	return legacy_data.get("reputation", 0)

func has_nemesis(char_id: String) -> bool:
	for n in legacy_data.get("nemeses", []):
		if n.get("id") == char_id:
			return true
	return false

func get_nemesis_count() -> int:
	return legacy_data.get("nemeses", []).size()
