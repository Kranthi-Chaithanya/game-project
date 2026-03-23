# example_usage.gd
# Demonstrates the nemesis/relationship system
extends Node

func _ready() -> void:
	# Create characters
	var manager = RelationshipManager.new()

	var player = Character.new("p1", "Hero", CharacterType.Type.PLAYER)
	var villain = Character.new("v1", "Dark Lord", CharacterType.Type.VILLAIN)
	var merchant = Character.new("m1", "Trader", CharacterType.Type.MERCHANT)
	var ally = Character.new("a1", "Companion", CharacterType.Type.ALLY)

	manager.add_character(player)
	manager.add_character(villain)
	manager.add_character(merchant)
	manager.add_character(ally)

	# Create initial relationships
	manager.create_relationship(player, villain, RelationshipType.Type.NEUTRAL, RelationshipType.Type.NEUTRAL, 0)
	manager.create_relationship(player, ally, RelationshipType.Type.FRIEND, RelationshipType.Type.FRIEND, 50)
	manager.create_relationship(player, merchant, RelationshipType.Type.NEUTRAL, RelationshipType.Type.NEUTRAL, 10)

	# Add callback for relationship changes
	manager.get_event_system().add_callback(func(rel, evt):
		print("Relationship changed! Intensity: " + str(rel.intensity))
	)

	# Process events
	var betrayal = RelationshipEvent.new(EventType.Type.BETRAYAL, villain, player, "Dark Lord betrayed the Hero")
	manager.process_event(betrayal)

	var rescue = RelationshipEvent.new(EventType.Type.RESCUE, ally, player, "Companion rescued the Hero")
	manager.process_event(rescue)

	# Query relationships
	var player_rels = manager.get_relationships_for(player)
	print("Player has " + str(player_rels.size()) + " relationships")

	var nemeses = manager.get_characters_by_type(player, RelationshipType.Type.NEMESIS)
	print("Player's nemeses: " + str(nemeses.size()))
