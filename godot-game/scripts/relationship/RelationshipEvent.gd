# RelationshipEvent.gd
# An event that affects relationship between two characters
class_name RelationshipEvent

var event_id: String
var event_type: EventType.Type
var source: Character
var target: Character
var description: String
var timestamp: String

func _init(evt_type: EventType.Type, src: Character, tgt: Character, desc: String) -> void:
	event_id = str(randi()) + "_" + str(Time.get_ticks_msec())
	event_type = evt_type
	source = src
	target = tgt
	description = desc
	timestamp = Time.get_datetime_string_from_system()
