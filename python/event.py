from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .character import Character


class EventType(Enum):
    COMBAT = "Combat"
    BETRAYAL = "Betrayal"
    ASSISTANCE = "Assistance"
    DIALOGUE = "Dialogue"
    QUEST = "Quest"
    TRADE = "Trade"
    DEFEAT = "Defeat"
    VICTORY = "Victory"
    GIFT = "Gift"
    THEFT = "Theft"
    MURDER = "Murder"
    RESCUE = "Rescue"


@dataclass
class RelationshipEvent:
    event_id: str
    event_type: EventType
    source_character: "Character"
    target_character: "Character"
    description: str
    timestamp: datetime | None = None

    def __post_init__(self) -> None:
        if self.timestamp is None:
            self.timestamp = datetime.now(timezone.utc)
