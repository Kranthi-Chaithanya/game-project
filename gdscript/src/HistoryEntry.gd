# HistoryEntry.gd
# Records a single event in a relationship's history
class_name HistoryEntry

var event_description: String
var timestamp: String  # ISO string since Godot lacks proper DateTime
var intensity_delta: int

func _init(desc: String, delta: int) -> void:
	event_description = desc
	intensity_delta = delta
	timestamp = Time.get_datetime_string_from_system()

func to_dict() -> Dictionary:
	return {
		"event_description": event_description,
		"timestamp": timestamp,
		"intensity_delta": intensity_delta
	}
