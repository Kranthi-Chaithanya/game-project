from __future__ import annotations

from typing import Optional

from .character import Character
from .event import RelationshipEvent
from .event_system import EventSystem
from .relationship import Relationship, RelationshipType


class RelationshipManager:
    def __init__(self) -> None:
        self._characters: dict[str, Character] = {}
        # Key: frozenset of two character ids → Relationship
        self._relationships: dict[frozenset[str], Relationship] = {}
        self._event_system: EventSystem = EventSystem()

    # ------------------------------------------------------------------
    # Character management
    # ------------------------------------------------------------------

    def add_character(self, character: Character) -> None:
        """Register a character and bind this manager to it."""
        self._characters[character.id] = character
        character.set_manager(self)

    # ------------------------------------------------------------------
    # Relationship CRUD
    # ------------------------------------------------------------------

    def create_relationship(
        self,
        char_a: Character,
        char_b: Character,
        type_a: RelationshipType = RelationshipType.NEUTRAL,
        type_b: RelationshipType = RelationshipType.NEUTRAL,
        initial_intensity: float = 0.0,
    ) -> Relationship:
        """Create (or return existing) relationship between char_a and char_b."""
        key = frozenset({char_a.id, char_b.id})
        if key in self._relationships:
            return self._relationships[key]
        if char_a.id == char_b.id:
            raise ValueError("Cannot create a relationship between a character and itself.")
        rel = Relationship(char_a, char_b, type_a, type_b, initial_intensity)
        self._relationships[key] = rel
        # Ensure both characters are registered
        if char_a.id not in self._characters:
            self.add_character(char_a)
        if char_b.id not in self._characters:
            self.add_character(char_b)
        return rel

    def get_relationship(self, char_a: Character, char_b: Character) -> Optional[Relationship]:
        """Return the relationship between two characters, or None."""
        key = frozenset({char_a.id, char_b.id})
        return self._relationships.get(key)

    def get_relationships_for(self, character: Character) -> list[Relationship]:
        """Return all relationships involving *character*."""
        return [
            rel
            for key, rel in self._relationships.items()
            if character.id in key
        ]

    def get_characters_by_type(
        self, character: Character, rel_type: RelationshipType
    ) -> list[Character]:
        """
        Return all characters that *character* views with *rel_type*
        (i.e., from character's perspective).
        """
        result: list[Character] = []
        for rel in self.get_relationships_for(character):
            try:
                perspective = rel.get_perspective(character)
            except ValueError:
                continue
            if perspective == rel_type:
                other = rel.char_b if rel.char_a.id == character.id else rel.char_a
                result.append(other)
        return result

    def update_intensity(
        self, char_a: Character, char_b: Character, delta: float
    ) -> Relationship:
        """Adjust the intensity of the relationship by *delta* (clamped to [-100, 100])."""
        rel = self.get_relationship(char_a, char_b)
        if rel is None:
            rel = self.create_relationship(char_a, char_b)
        from datetime import datetime, timezone

        rel.intensity = max(-100.0, min(100.0, rel.intensity + delta))
        rel.updated_at = datetime.now(timezone.utc)
        return rel

    def change_type(
        self,
        char_a: Character,
        char_b: Character,
        new_type_from_a: RelationshipType,
        new_type_from_b: Optional[RelationshipType] = None,
    ) -> None:
        """Change the relationship type from char_a's perspective (and optionally char_b's)."""
        rel = self.get_relationship(char_a, char_b)
        if rel is None:
            raise KeyError(f"No relationship between {char_a.id!r} and {char_b.id!r}.")
        rel.update_perspective(char_a, new_type_from_a)
        if new_type_from_b is not None:
            rel.update_perspective(char_b, new_type_from_b)

    def remove_relationship(self, char_a: Character, char_b: Character) -> None:
        """Remove the relationship between char_a and char_b."""
        key = frozenset({char_a.id, char_b.id})
        self._relationships.pop(key, None)

    # ------------------------------------------------------------------
    # Event processing
    # ------------------------------------------------------------------

    def process_event(self, event: RelationshipEvent) -> Relationship:
        """Process an event through the EventSystem."""
        return self._event_system.process_event(event, self)

    @property
    def event_system(self) -> EventSystem:
        return self._event_system
