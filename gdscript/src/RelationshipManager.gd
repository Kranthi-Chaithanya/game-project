# RelationshipManager.gd
# Central system managing all character relationships
class_name RelationshipManager

var _characters: Dictionary  # id -> Character
var _relationships: Dictionary  # key -> Relationship
var _event_system: EventSystem

func _init() -> void:
	_characters = {}
	_relationships = {}
	_event_system = EventSystem.new()

func _make_key(char_a: Character, char_b: Character) -> String:
	var ids = [char_a.id, char_b.id]
	ids.sort()
	return ids[0] + "|" + ids[1]

func add_character(character: Character) -> void:
	character.set_manager(self)
	_characters[character.id] = character

func create_relationship(char_a: Character, char_b: Character, type_a: RelationshipType.Type = RelationshipType.Type.NEUTRAL, type_b: RelationshipType.Type = RelationshipType.Type.NEUTRAL, initial_intensity: int = 0) -> Relationship:
	if char_a.id == char_b.id:
		push_error("Cannot create a relationship between a character and themselves.")
		return null
	var key = _make_key(char_a, char_b)
	if _relationships.has(key):
		return _relationships[key]
	var rel = Relationship.new(char_a, char_b, type_a, type_b, initial_intensity)
	_relationships[key] = rel
	return rel

func get_relationship(char_a: Character, char_b: Character) -> Relationship:
	var key = _make_key(char_a, char_b)
	if _relationships.has(key):
		return _relationships[key]
	return null

func get_relationships_for(character: Character) -> Array:
	var result: Array = []
	for rel in _relationships.values():
		if rel.involves(character):
			result.append(rel)
	return result

func get_characters_by_type(character: Character, rel_type: RelationshipType.Type) -> Array:
	var result: Array = []
	for rel in _relationships.values():
		if rel.involves(character):
			if rel.get_perspective(character) == rel_type:
				result.append(rel.get_other(character))
	return result

func update_intensity(char_a: Character, char_b: Character, delta: int) -> Relationship:
	var rel = get_relationship(char_a, char_b)
	if rel == null:
		push_error("Relationship not found.")
		return null
	rel.update_intensity(delta)
	return rel

func change_type(char_a: Character, char_b: Character, type_from_a: RelationshipType.Type, type_from_b = null) -> void:
	var rel = get_relationship(char_a, char_b)
	if rel == null:
		push_error("Relationship not found.")
		return
	rel.set_perspective(char_a, type_from_a)
	if type_from_b != null:
		rel.set_perspective(char_b, type_from_b)

func remove_relationship(char_a: Character, char_b: Character) -> void:
	var key = _make_key(char_a, char_b)
	_relationships.erase(key)

func process_event(event: RelationshipEvent) -> void:
	_event_system.process_event(event, self)

func get_event_system() -> EventSystem:
	return _event_system
