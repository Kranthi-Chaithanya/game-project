import pytest
from python.character import Character, CharacterType
from python.relationship import RelationshipType
from python.relationship_manager import RelationshipManager


def make_manager_with_chars():
    manager = RelationshipManager()
    hero = Character("hero", "Hero", CharacterType.PLAYER)
    villain = Character("villain", "Villain", CharacterType.VILLAIN)
    ally = Character("ally", "Ally", CharacterType.ALLY)
    for c in (hero, villain, ally):
        manager.add_character(c)
    return manager, hero, villain, ally


def test_create_relationship():
    manager, hero, villain, _ = make_manager_with_chars()
    rel = manager.create_relationship(hero, villain)
    assert rel is not None
    assert rel.char_a is hero or rel.char_b is hero
    assert rel.char_a is villain or rel.char_b is villain


def test_get_relationship():
    manager, hero, villain, _ = make_manager_with_chars()
    manager.create_relationship(hero, villain)
    rel = manager.get_relationship(hero, villain)
    assert rel is not None


def test_get_relationship_returns_none_if_missing():
    manager, hero, villain, ally = make_manager_with_chars()
    assert manager.get_relationship(hero, villain) is None


def test_get_relationship_is_symmetric():
    manager, hero, villain, _ = make_manager_with_chars()
    manager.create_relationship(hero, villain)
    assert manager.get_relationship(hero, villain) is manager.get_relationship(villain, hero)


def test_get_all_for_character():
    manager, hero, villain, ally = make_manager_with_chars()
    manager.create_relationship(hero, villain)
    manager.create_relationship(hero, ally)
    rels = manager.get_relationships_for(hero)
    assert len(rels) == 2


def test_get_characters_by_type():
    manager, hero, villain, ally = make_manager_with_chars()
    manager.create_relationship(hero, villain, RelationshipType.NEMESIS, RelationshipType.NEUTRAL)
    manager.create_relationship(hero, ally, RelationshipType.ALLY, RelationshipType.ALLY)
    nemeses = manager.get_characters_by_type(hero, RelationshipType.NEMESIS)
    assert villain in nemeses
    assert ally not in nemeses


def test_update_intensity():
    manager, hero, villain, _ = make_manager_with_chars()
    rel = manager.create_relationship(hero, villain, initial_intensity=0.0)
    updated = manager.update_intensity(hero, villain, -20.0)
    assert updated.intensity == -20.0


def test_update_intensity_clamps_at_min():
    manager, hero, villain, _ = make_manager_with_chars()
    manager.create_relationship(hero, villain, initial_intensity=-90.0)
    rel = manager.update_intensity(hero, villain, -50.0)
    assert rel.intensity == -100.0


def test_update_intensity_clamps_at_max():
    manager, hero, villain, _ = make_manager_with_chars()
    manager.create_relationship(hero, villain, initial_intensity=90.0)
    rel = manager.update_intensity(hero, villain, 50.0)
    assert rel.intensity == 100.0


def test_change_type_one_sided():
    manager, hero, villain, _ = make_manager_with_chars()
    manager.create_relationship(hero, villain)
    manager.change_type(hero, villain, RelationshipType.RIVAL)
    rel = manager.get_relationship(hero, villain)
    assert rel.get_perspective(hero) == RelationshipType.RIVAL
    assert rel.get_perspective(villain) == RelationshipType.NEUTRAL


def test_change_type_both_sides():
    manager, hero, villain, _ = make_manager_with_chars()
    manager.create_relationship(hero, villain)
    manager.change_type(hero, villain, RelationshipType.NEMESIS, RelationshipType.NEMESIS)
    rel = manager.get_relationship(hero, villain)
    assert rel.get_perspective(hero) == RelationshipType.NEMESIS
    assert rel.get_perspective(villain) == RelationshipType.NEMESIS


def test_remove_relationship():
    manager, hero, villain, _ = make_manager_with_chars()
    manager.create_relationship(hero, villain)
    manager.remove_relationship(hero, villain)
    assert manager.get_relationship(hero, villain) is None


def test_duplicate_relationship_returns_same():
    manager, hero, villain, _ = make_manager_with_chars()
    rel1 = manager.create_relationship(hero, villain)
    rel2 = manager.create_relationship(hero, villain)
    assert rel1 is rel2


def test_self_relationship_raises():
    manager, hero, _, _ = make_manager_with_chars()
    with pytest.raises(ValueError):
        manager.create_relationship(hero, hero)


def test_change_type_missing_relationship_raises():
    manager, hero, villain, _ = make_manager_with_chars()
    with pytest.raises(KeyError):
        manager.change_type(hero, villain, RelationshipType.RIVAL)
