# Character.gd
# Base class for all characters in the relationship system
class_name Character

var id: String
var name: String
var character_type: CharacterType.Type
var _manager  # RelationshipManager reference (weak)

func _init(char_id: String, char_name: String, char_type: CharacterType.Type) -> void:
	id = char_id
	name = char_name
	character_type = char_type

func set_manager(manager) -> void:
	_manager = manager

func get_relationships() -> Array:
	if _manager == null:
		return []
	return _manager.get_relationships_for(self)

func to_string() -> String:
	return "Character(id=" + id + ", name=" + name + ", type=" + str(character_type) + ")"
