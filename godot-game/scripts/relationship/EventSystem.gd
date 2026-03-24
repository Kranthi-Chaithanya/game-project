# EventSystem.gd
# Processes relationship events and applies changes
class_name EventSystem

var _rules: Dictionary  # EventType.Type -> int delta
var _callbacks: Array  # Array of Callables

func _init() -> void:
	_callbacks = []
	_rules = {
		EventType.Type.BETRAYAL: -40,
		EventType.Type.MURDER: -50,
		EventType.Type.THEFT: -20,
		EventType.Type.COMBAT: -10,
		EventType.Type.DEFEAT: -15,
		EventType.Type.VICTORY: 10,
		EventType.Type.ASSISTANCE: 20,
		EventType.Type.RESCUE: 30,
		EventType.Type.GIFT: 15,
		EventType.Type.TRADE: 5,
		EventType.Type.DIALOGUE: 5,
		EventType.Type.QUEST: 10
	}

func set_rule(event_type: EventType.Type, delta: int) -> void:
	_rules[event_type] = delta

func add_callback(callback: Callable) -> void:
	_callbacks.append(callback)

func _determine_type(intensity: int, current_type: RelationshipType.Type, delta: int) -> RelationshipType.Type:
	# Betrayer transition: if source had Ally/Friend and event is negative
	if delta < 0 and (current_type == RelationshipType.Type.ALLY or current_type == RelationshipType.Type.FRIEND):
		return RelationshipType.Type.BETRAYER
	# Threshold-based transitions
	if intensity <= -80:
		return RelationshipType.Type.NEMESIS
	elif intensity <= -30:
		return RelationshipType.Type.RIVAL
	elif intensity <= 30:
		return RelationshipType.Type.NEUTRAL
	elif intensity <= 60:
		return RelationshipType.Type.FRIEND
	else:
		return RelationshipType.Type.ALLY

func process_event(event: RelationshipEvent, manager) -> void:
	# Get or create relationship
	var relationship = manager.get_relationship(event.source, event.target)
	if relationship == null:
		relationship = manager.create_relationship(event.source, event.target)

	# Get delta
	var delta: int = 0
	if _rules.has(event.event_type):
		delta = _rules[event.event_type]

	# Apply intensity
	relationship.update_intensity(delta)

	# Determine new types for both perspectives
	var source_current = relationship.get_perspective(event.source)
	var target_current = relationship.get_perspective(event.target)

	var new_source_type = _determine_type(relationship.intensity, source_current, -delta)  # source affected by target's action
	var new_target_type = _determine_type(relationship.intensity, target_current, delta)

	relationship.set_perspective(event.source, new_source_type)
	relationship.set_perspective(event.target, new_target_type)

	# Add to history
	var entry = HistoryEntry.new(
		"[" + event.timestamp + "] " + event.source.name + " -> " + event.target.name + ": " + event.description + " (delta: " + str(delta) + ")",
		delta
	)
	relationship.add_history(entry)

	# Fire callbacks
	for callback in _callbacks:
		callback.call(relationship, event)
