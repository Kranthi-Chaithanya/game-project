# Relationship.gd
# Represents a bidirectional relationship between two characters
class_name Relationship

var character_a: Character
var character_b: Character
var perspectives: Dictionary  # {character_id: RelationshipType.Type}
var intensity: int  # -100 to 100
var history: Array  # Array of HistoryEntry
var created_at: String
var updated_at: String

func _init(char_a: Character, char_b: Character, type_a: RelationshipType.Type = RelationshipType.Type.NEUTRAL, type_b: RelationshipType.Type = RelationshipType.Type.NEUTRAL, initial_intensity: int = 0) -> void:
	character_a = char_a
	character_b = char_b
	perspectives = {
		char_a.id: type_a,
		char_b.id: type_b
	}
	intensity = clampi(initial_intensity, -100, 100)
	history = []
	created_at = Time.get_datetime_string_from_system()
	updated_at = created_at

func get_perspective(character: Character) -> RelationshipType.Type:
	if perspectives.has(character.id):
		return perspectives[character.id]
	return RelationshipType.Type.NEUTRAL

func set_perspective(character: Character, rel_type: RelationshipType.Type) -> void:
	perspectives[character.id] = rel_type
	updated_at = Time.get_datetime_string_from_system()

func add_history(entry: HistoryEntry) -> void:
	history.append(entry)
	updated_at = Time.get_datetime_string_from_system()

func update_intensity(delta: int) -> void:
	intensity = clampi(intensity + delta, -100, 100)
	updated_at = Time.get_datetime_string_from_system()

func involves(character: Character) -> bool:
	return character.id == character_a.id or character.id == character_b.id

func get_other(character: Character) -> Character:
	if character.id == character_a.id:
		return character_b
	return character_a
