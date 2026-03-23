import pytest
from python.character import Character, CharacterType
from python.event import EventType, RelationshipEvent
from python.event_system import EventSystem
from python.relationship import RelationshipType
from python.relationship_manager import RelationshipManager


def make_manager():
    manager = RelationshipManager()
    hero = Character("hero", "Hero", CharacterType.PLAYER)
    villain = Character("villain", "Villain", CharacterType.VILLAIN)
    manager.add_character(hero)
    manager.add_character(villain)
    return manager, hero, villain


def make_event(source, target, event_type: EventType, eid: str = "e1", desc: str = "event") -> RelationshipEvent:
    return RelationshipEvent(
        event_id=eid,
        event_type=event_type,
        source_character=source,
        target_character=target,
        description=desc,
    )


def test_process_combat_decreases_intensity():
    manager, hero, villain = make_manager()
    manager.create_relationship(hero, villain, initial_intensity=0.0)
    event = make_event(hero, villain, EventType.COMBAT)
    rel = manager.process_event(event)
    assert rel.intensity < 0.0


def test_process_rescue_increases_intensity():
    manager, hero, villain = make_manager()
    manager.create_relationship(hero, villain, initial_intensity=0.0)
    event = make_event(hero, villain, EventType.RESCUE)
    rel = manager.process_event(event)
    assert rel.intensity > 0.0


def test_process_event_creates_relationship_if_absent():
    manager, hero, villain = make_manager()
    assert manager.get_relationship(hero, villain) is None
    event = make_event(hero, villain, EventType.DIALOGUE)
    rel = manager.process_event(event)
    assert rel is not None
    assert manager.get_relationship(hero, villain) is not None


def test_intensity_clamped_at_min():
    manager, hero, villain = make_manager()
    manager.create_relationship(hero, villain, initial_intensity=-95.0)
    event = make_event(hero, villain, EventType.MURDER)
    rel = manager.process_event(event)
    assert rel.intensity == -100.0


def test_intensity_clamped_at_max():
    manager, hero, villain = make_manager()
    manager.create_relationship(hero, villain, initial_intensity=90.0)
    event = make_event(hero, villain, EventType.RESCUE)
    rel = manager.process_event(event)
    assert rel.intensity == 100.0


def test_type_transition_to_nemesis():
    manager, hero, villain = make_manager()
    manager.create_relationship(hero, villain, initial_intensity=-85.0)
    event = make_event(hero, villain, EventType.COMBAT, "e2")
    rel = manager.process_event(event)
    assert rel.get_perspective(hero) == RelationshipType.NEMESIS


def test_type_transition_to_ally():
    manager, hero, villain = make_manager()
    manager.create_relationship(hero, villain, initial_intensity=55.0)
    event = make_event(hero, villain, EventType.RESCUE, "e3")
    rel = manager.process_event(event)
    assert rel.get_perspective(hero) == RelationshipType.ALLY


def test_betrayal_sets_betrayer_on_target_perspective():
    manager, hero, villain = make_manager()
    manager.create_relationship(hero, villain, initial_intensity=0.0)
    event = make_event(hero, villain, EventType.BETRAYAL)
    rel = manager.process_event(event)
    assert rel.get_perspective(villain) == RelationshipType.BETRAYER


def test_callback_is_fired():
    manager, hero, villain = make_manager()
    manager.create_relationship(hero, villain)
    fired = []

    def cb(event, relationship):
        fired.append((event, relationship))

    manager.event_system.register_callback(cb)
    event = make_event(hero, villain, EventType.GIFT)
    manager.process_event(event)
    assert len(fired) == 1
    assert fired[0][0] is event


def test_multiple_callbacks_all_fired():
    manager, hero, villain = make_manager()
    manager.create_relationship(hero, villain)
    calls = []
    manager.event_system.register_callback(lambda e, r: calls.append(1))
    manager.event_system.register_callback(lambda e, r: calls.append(2))
    manager.process_event(make_event(hero, villain, EventType.TRADE))
    assert calls == [1, 2]


def test_history_logged_after_event():
    manager, hero, villain = make_manager()
    manager.create_relationship(hero, villain)
    manager.process_event(make_event(hero, villain, EventType.COMBAT, desc="Epic battle"))
    rel = manager.get_relationship(hero, villain)
    assert len(rel.history) == 1
    assert rel.history[0].description == "Epic battle"


def test_multiple_events_accumulate_history():
    manager, hero, villain = make_manager()
    manager.create_relationship(hero, villain)
    for i in range(3):
        manager.process_event(make_event(hero, villain, EventType.COMBAT, eid=str(i), desc=f"fight {i}"))
    rel = manager.get_relationship(hero, villain)
    assert len(rel.history) == 3


def test_custom_rule_overrides_default():
    manager, hero, villain = make_manager()
    manager.create_relationship(hero, villain, initial_intensity=0.0)
    manager.event_system.register_rule(EventType.COMBAT, 50.0)
    manager.process_event(make_event(hero, villain, EventType.COMBAT))
    rel = manager.get_relationship(hero, villain)
    assert rel.intensity == 50.0


def test_ally_betrayer_nemesis_chain():
    """Simulate friendship → betrayal → nemesis arc."""
    manager, hero, villain = make_manager()
    # Start as allies (type set explicitly to match the intensity level)
    manager.create_relationship(
        hero, villain,
        type_a=RelationshipType.ALLY, type_b=RelationshipType.ALLY,
        initial_intensity=65.0,
    )
    rel = manager.get_relationship(hero, villain)
    assert rel.get_perspective(hero) == RelationshipType.ALLY

    # Betrayal knocks intensity down
    manager.process_event(make_event(hero, villain, EventType.BETRAYAL, "b1", "Backstab"))
    rel = manager.get_relationship(hero, villain)
    assert rel.get_perspective(villain) == RelationshipType.BETRAYER

    # Repeated combat drives to nemesis (need enough hits to cross -80 threshold)
    for i in range(12):
        manager.process_event(make_event(hero, villain, EventType.COMBAT, str(i), "fight"))
    rel = manager.get_relationship(hero, villain)
    assert rel.get_perspective(hero) == RelationshipType.NEMESIS
