# GDScript Nemesis / Relationship System

A data-driven, event-based relationship system for **Godot 4.x** written in pure GDScript. Track how every character in your game feels about every other character, with a full event history and automatic type transitions (Friend → Betrayer, Neutral → Nemesis, etc.).

---

## Project Structure

```
gdscript/
  src/
    CharacterType.gd       – Enum of character roles (PLAYER, VILLAIN, MERCHANT …)
    RelationshipType.gd    – Enum of relationship kinds (NEMESIS, ALLY, BETRAYER …)
    EventType.gd           – Enum of game events that drive relationship changes
    HistoryEntry.gd        – Immutable record of one event stored in relationship history
    Character.gd           – Base character data class
    Relationship.gd        – Bidirectional link between two characters
    RelationshipEvent.gd   – A timestamped event connecting a source and a target
    EventSystem.gd         – Rule engine: maps EventType → intensity delta, fires callbacks
    RelationshipManager.gd – Central registry for characters, relationships, and events
  examples/
    example_usage.gd       – Runnable Node scene demonstrating the full API
  README.md
```

---

## Setup in Godot 4.x

1. Copy the `gdscript/src/` folder anywhere inside your Godot project (e.g. `res://systems/relationships/src/`).
2. Because every file uses `class_name`, Godot's auto-loader registers them globally — **no imports needed**.
3. Attach `example_usage.gd` to any Node in a scene to see it run, or integrate the classes directly into your own scripts.

> **Load order note:** Godot resolves `class_name` dependencies automatically, but all source files must be inside the project directory so the editor can index them.

---

## Classes at a Glance

| Class | Role |
|---|---|
| `CharacterType` | Namespace for the `Type` enum (`PLAYER`, `NPC`, `VILLAIN`, `ALLY`, `NEUTRAL`, `MERCHANT`, `MENTOR`, `RIVAL`) |
| `RelationshipType` | Namespace for the `Type` enum (`NEMESIS`, `RIVAL`, `ALLY`, `MENTOR`, `NEUTRAL`, `FRIEND`, `BETRAYER`) |
| `EventType` | Namespace for the `Type` enum (`COMBAT`, `BETRAYAL`, `ASSISTANCE`, `DIALOGUE`, `QUEST`, `TRADE`, `DEFEAT`, `VICTORY`, `GIFT`, `THEFT`, `MURDER`, `RESCUE`) |
| `HistoryEntry` | Stores `event_description`, `timestamp`, and `intensity_delta`; exposes `to_dict()` |
| `Character` | Holds `id`, `name`, `character_type`; calls back into the manager via `get_relationships()` |
| `Relationship` | Stores dual perspectives, `intensity` (−100 … 100), and a `history` array |
| `RelationshipEvent` | One-shot value object: `event_type`, `source`, `target`, `description`, auto-generated `event_id` |
| `EventSystem` | Applies delta rules, auto-transitions relationship types, and invokes registered `Callable` callbacks |
| `RelationshipManager` | CRUD for characters and relationships; routes events through `EventSystem` |

---

## Intensity Thresholds → Relationship Type

| Intensity range | Auto-assigned type |
|---|---|
| ≤ −80 | `NEMESIS` |
| −79 … −31 | `RIVAL` |
| −30 … 30 | `NEUTRAL` |
| 31 … 60 | `FRIEND` |
| > 60 | `ALLY` |

Special rule: if the current type is `ALLY` or `FRIEND` and an event carries a **negative** delta, the perspective flips to `BETRAYER` instead of following the numeric threshold.

---

## Quick-Start Example

```gdscript
extends Node

func _ready() -> void:
    var manager := RelationshipManager.new()

    var hero    := Character.new("p1", "Hero",      CharacterType.Type.PLAYER)
    var villain := Character.new("v1", "Dark Lord", CharacterType.Type.VILLAIN)
    var ally    := Character.new("a1", "Companion", CharacterType.Type.ALLY)

    manager.add_character(hero)
    manager.add_character(villain)
    manager.add_character(ally)

    # Pre-seed a relationship with a starting intensity
    manager.create_relationship(hero, ally, RelationshipType.Type.FRIEND, RelationshipType.Type.FRIEND, 50)

    # Listen for any change
    manager.get_event_system().add_callback(func(rel: Relationship, evt: RelationshipEvent) -> void:
        print("%s ↔ %s  intensity=%d" % [rel.character_a.name, rel.character_b.name, rel.intensity])
    )

    # Fire events — the system handles everything else
    manager.process_event(
        RelationshipEvent.new(EventType.Type.BETRAYAL, villain, hero, "Villain betrayed the Hero")
    )
    manager.process_event(
        RelationshipEvent.new(EventType.Type.RESCUE, ally, hero, "Companion saved the Hero")
    )

    # Query
    var nemeses := manager.get_characters_by_type(hero, RelationshipType.Type.NEMESIS)
    print("Hero has %d nemesis(es)" % nemeses.size())
```

---

## Customising Rules

Override any event's intensity delta before processing events:

```gdscript
# Make TRADE twice as impactful
manager.get_event_system().set_rule(EventType.Type.TRADE, 10)
```

---

## API Reference

### `RelationshipManager`

| Method | Description |
|---|---|
| `add_character(character)` | Register a character and inject the manager back-reference |
| `create_relationship(a, b, type_a, type_b, intensity)` | Create (or return existing) relationship |
| `get_relationship(a, b)` | Look up a relationship; returns `null` if none |
| `get_relationships_for(character)` | All relationships involving a character |
| `get_characters_by_type(character, rel_type)` | Filter relationship partners by type from the character's perspective |
| `update_intensity(a, b, delta)` | Manually nudge intensity |
| `change_type(a, b, type_a, type_b?)` | Manually override perspective(s) |
| `remove_relationship(a, b)` | Delete a relationship |
| `process_event(event)` | Route a `RelationshipEvent` through the `EventSystem` |
| `get_event_system()` | Access the underlying `EventSystem` |

### `EventSystem`

| Method | Description |
|---|---|
| `set_rule(event_type, delta)` | Override the intensity delta for an event type |
| `add_callback(callable)` | Register `func(rel: Relationship, evt: RelationshipEvent)` |

---

## License

MIT — use freely in personal and commercial Godot projects.
