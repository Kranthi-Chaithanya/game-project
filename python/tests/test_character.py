import pytest
from python.character import Character, CharacterType
from python.relationship_manager import RelationshipManager


def make_character(cid: str = "c1", name: str = "Alice", ctype: CharacterType = CharacterType.PLAYER) -> Character:
    return Character(cid, name, ctype)


def test_character_creation():
    c = make_character()
    assert c.id == "c1"
    assert c.name == "Alice"
    assert c.character_type == CharacterType.PLAYER


def test_character_repr():
    c = make_character()
    r = repr(c)
    assert "c1" in r
    assert "Alice" in r
    assert "Player" in r


def test_character_no_manager_returns_empty_relationships():
    c = make_character()
    assert c.get_relationships() == []


def test_character_set_manager():
    c = make_character()
    manager = RelationshipManager()
    manager.add_character(c)
    assert c._manager is manager


def test_character_get_relationships_via_manager():
    c1 = Character("c1", "Alice", CharacterType.PLAYER)
    c2 = Character("c2", "Bob", CharacterType.NPC)
    manager = RelationshipManager()
    manager.add_character(c1)
    manager.add_character(c2)
    manager.create_relationship(c1, c2)
    rels = c1.get_relationships()
    assert len(rels) == 1


def test_character_types():
    for ct in CharacterType:
        c = Character(ct.value, ct.name, ct)
        assert c.character_type == ct
