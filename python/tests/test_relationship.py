from datetime import datetime, timezone

import pytest
from python.character import Character, CharacterType
from python.relationship import HistoryEntry, Relationship, RelationshipType


def make_pair():
    a = Character("a", "Alice", CharacterType.PLAYER)
    b = Character("b", "Bob", CharacterType.VILLAIN)
    return a, b


def test_relationship_creation():
    a, b = make_pair()
    rel = Relationship(a, b)
    assert rel.char_a is a
    assert rel.char_b is b
    assert rel.intensity == 0.0


def test_relationship_default_types_are_neutral():
    a, b = make_pair()
    rel = Relationship(a, b)
    assert rel.get_perspective(a) == RelationshipType.NEUTRAL
    assert rel.get_perspective(b) == RelationshipType.NEUTRAL


def test_relationship_bidirectional_perspectives():
    a, b = make_pair()
    rel = Relationship(a, b, RelationshipType.ALLY, RelationshipType.NEMESIS)
    assert rel.get_perspective(a) == RelationshipType.ALLY
    assert rel.get_perspective(b) == RelationshipType.NEMESIS


def test_relationship_update_perspective():
    a, b = make_pair()
    rel = Relationship(a, b)
    rel.update_perspective(a, RelationshipType.RIVAL)
    assert rel.get_perspective(a) == RelationshipType.RIVAL
    assert rel.get_perspective(b) == RelationshipType.NEUTRAL


def test_relationship_get_perspective_invalid_character():
    a, b = make_pair()
    c = Character("c", "Carol", CharacterType.NPC)
    rel = Relationship(a, b)
    with pytest.raises(ValueError):
        rel.get_perspective(c)


def test_relationship_update_perspective_invalid_character():
    a, b = make_pair()
    c = Character("c", "Carol", CharacterType.NPC)
    rel = Relationship(a, b)
    with pytest.raises(ValueError):
        rel.update_perspective(c, RelationshipType.ALLY)


def test_relationship_initial_intensity():
    a, b = make_pair()
    rel = Relationship(a, b, initial_intensity=42.0)
    assert rel.intensity == 42.0


def test_relationship_add_to_history():
    a, b = make_pair()
    rel = Relationship(a, b)
    entry = HistoryEntry(
        timestamp=datetime.now(timezone.utc),
        description="They fought",
        intensity_before=0.0,
        intensity_after=-10.0,
        type_before=RelationshipType.NEUTRAL,
        type_after=RelationshipType.RIVAL,
    )
    rel.add_to_history(entry)
    assert len(rel.history) == 1
    assert rel.history[0].description == "They fought"


def test_relationship_timestamps_set_on_creation():
    a, b = make_pair()
    before = datetime.now(timezone.utc)
    rel = Relationship(a, b)
    after = datetime.now(timezone.utc)
    assert before <= rel.created_at <= after
    assert before <= rel.updated_at <= after


def test_relationship_updated_at_changes_on_perspective_update():
    a, b = make_pair()
    rel = Relationship(a, b)
    old_updated = rel.updated_at
    rel.update_perspective(a, RelationshipType.MENTOR)
    assert rel.updated_at >= old_updated


def test_relationship_repr():
    a, b = make_pair()
    rel = Relationship(a, b, RelationshipType.NEMESIS, RelationshipType.NEUTRAL)
    r = repr(rel)
    assert "Alice" in r
    assert "Bob" in r
    assert "Nemesis" in r
