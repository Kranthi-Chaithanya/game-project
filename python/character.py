from enum import Enum
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .relationship_manager import RelationshipManager


class CharacterType(Enum):
    PLAYER = "Player"
    NPC = "NPC"
    VILLAIN = "Villain"
    ALLY = "Ally"
    NEUTRAL = "Neutral"
    MERCHANT = "Merchant"
    MENTOR = "Mentor"
    RIVAL = "Rival"


class Character:
    def __init__(self, character_id: str, name: str, character_type: CharacterType):
        self.id = character_id
        self.name = name
        self.character_type = character_type
        self._manager: "RelationshipManager | None" = None

    def set_manager(self, manager: "RelationshipManager") -> None:
        self._manager = manager

    def get_relationships(self):
        if self._manager is None:
            return []
        return self._manager.get_relationships_for(self)

    def __repr__(self) -> str:
        return f"Character(id={self.id!r}, name={self.name!r}, type={self.character_type.value})"
