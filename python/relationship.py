from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .character import Character


class RelationshipType(Enum):
    NEMESIS = "Nemesis"
    RIVAL = "Rival"
    ALLY = "Ally"
    MENTOR = "Mentor"
    NEUTRAL = "Neutral"
    FRIEND = "Friend"
    BETRAYER = "Betrayer"


@dataclass
class HistoryEntry:
    timestamp: datetime
    description: str
    intensity_before: float
    intensity_after: float
    type_before: RelationshipType
    type_after: RelationshipType


class Relationship:
    def __init__(
        self,
        char_a: "Character",
        char_b: "Character",
        type_from_a: RelationshipType = RelationshipType.NEUTRAL,
        type_from_b: RelationshipType = RelationshipType.NEUTRAL,
        initial_intensity: float = 0.0,
    ) -> None:
        self.char_a = char_a
        self.char_b = char_b
        self._type_from_a: RelationshipType = type_from_a
        self._type_from_b: RelationshipType = type_from_b
        self.intensity: float = float(initial_intensity)
        self.history: list[HistoryEntry] = []
        now = datetime.now(timezone.utc)
        self.created_at: datetime = now
        self.updated_at: datetime = now

    def get_perspective(self, character: "Character") -> RelationshipType:
        if character.id == self.char_a.id:
            return self._type_from_a
        if character.id == self.char_b.id:
            return self._type_from_b
        raise ValueError(f"Character {character.id!r} is not part of this relationship.")

    def update_perspective(self, character: "Character", new_type: RelationshipType) -> None:
        if character.id == self.char_a.id:
            self._type_from_a = new_type
        elif character.id == self.char_b.id:
            self._type_from_b = new_type
        else:
            raise ValueError(f"Character {character.id!r} is not part of this relationship.")
        self.updated_at = datetime.now(timezone.utc)

    def add_to_history(self, entry: HistoryEntry) -> None:
        self.history.append(entry)
        self.updated_at = datetime.now(timezone.utc)

    def __repr__(self) -> str:
        return (
            f"Relationship(char_a={self.char_a.name!r}, char_b={self.char_b.name!r}, "
            f"intensity={self.intensity}, "
            f"type_a={self._type_from_a.value}, type_b={self._type_from_b.value})"
        )
