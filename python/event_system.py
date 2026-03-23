from __future__ import annotations

from datetime import datetime, timezone
from typing import Callable, TYPE_CHECKING

from .event import EventType, RelationshipEvent
from .relationship import HistoryEntry, Relationship, RelationshipType

if TYPE_CHECKING:
    from .relationship_manager import RelationshipManager

# Default intensity deltas per event type
_DEFAULT_RULES: dict[EventType, float] = {
    EventType.COMBAT: -10.0,
    EventType.BETRAYAL: -30.0,
    EventType.ASSISTANCE: 15.0,
    EventType.DIALOGUE: 5.0,
    EventType.QUEST: 10.0,
    EventType.TRADE: 8.0,
    EventType.DEFEAT: -20.0,
    EventType.VICTORY: 10.0,
    EventType.GIFT: 20.0,
    EventType.THEFT: -25.0,
    EventType.MURDER: -50.0,
    EventType.RESCUE: 30.0,
}


def _intensity_to_type(intensity: float, character_is_mentor: bool = False) -> RelationshipType:
    """Map an intensity value to a RelationshipType."""
    if intensity < -80:
        return RelationshipType.NEMESIS
    if intensity < -30:
        return RelationshipType.RIVAL
    if intensity < 30:
        return RelationshipType.NEUTRAL
    if intensity < 60:
        return RelationshipType.FRIEND
    # intensity >= 60
    return RelationshipType.ALLY


class EventSystem:
    def __init__(self) -> None:
        self._rules: dict[EventType, float] = dict(_DEFAULT_RULES)
        self._callbacks: list[Callable[[RelationshipEvent, Relationship], None]] = []

    def register_rule(self, event_type: EventType, delta: float) -> None:
        """Override the intensity delta for a given event type."""
        self._rules[event_type] = delta

    def register_callback(
        self, callback: Callable[[RelationshipEvent, Relationship], None]
    ) -> None:
        """Register a hook called after each event is processed."""
        self._callbacks.append(callback)

    def process_event(
        self, event: RelationshipEvent, relationship_manager: "RelationshipManager"
    ) -> Relationship:
        """
        Apply intensity change from *event* to the relationship between
        source and target, transition types as needed, log history, and
        fire callbacks. Creates the relationship if it does not yet exist.
        """
        source = event.source_character
        target = event.target_character

        rel = relationship_manager.get_relationship(source, target)
        if rel is None:
            rel = relationship_manager.create_relationship(source, target)

        delta = self._rules.get(event.event_type, 0.0)

        old_intensity = rel.intensity
        old_type_source = rel.get_perspective(source)
        old_type_target = rel.get_perspective(target)

        # Clamp intensity to [-100, 100]
        new_intensity = max(-100.0, min(100.0, old_intensity + delta))
        rel.intensity = new_intensity
        rel.updated_at = datetime.now(timezone.utc)

        # Transition types based on new intensity
        new_type_source = _intensity_to_type(new_intensity)
        new_type_target = _intensity_to_type(new_intensity)

        # Special case: if event is BETRAYAL the source becomes a BETRAYER
        # from the target's perspective
        if event.event_type == EventType.BETRAYAL:
            new_type_target = RelationshipType.BETRAYER

        rel.update_perspective(source, new_type_source)
        rel.update_perspective(target, new_type_target)

        # Record history entry
        entry = HistoryEntry(
            timestamp=event.timestamp,
            description=event.description,
            intensity_before=old_intensity,
            intensity_after=new_intensity,
            type_before=old_type_source,
            type_after=new_type_source,
        )
        rel.add_to_history(entry)

        # Fire callbacks
        for cb in self._callbacks:
            cb(event, rel)

        return rel
