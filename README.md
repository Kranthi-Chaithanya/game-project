# game-project — Universal Nemesis & Relationship System

A fully extensible, bidirectional, event-driven relationship/nemesis system for games. Implemented in **Python**, **C# (Unity-style)**, **TypeScript/JavaScript**, and **GDScript (Godot 4.x)**.

Any character — player, NPC, ally, villain, merchant, rival, or mentor — can form and evolve relationships with any other character. Relationships are shaped by in-game events and tracked with a full history log.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        RelationshipManager                          │
│  ┌──────────┐   creates/queries   ┌─────────────────────────────┐  │
│  │ Character│ ─────────────────── │        Relationship          │  │
│  │  (any)   │                     │  ┌──────────────────────┐   │  │
│  └──────────┘                     │  │ Perspective A (type) │   │  │
│       ↑                           │  │ Perspective B (type) │   │  │
│  CharacterType                    │  │ Intensity [-100,100] │   │  │
│  (Player, NPC,                    │  │ History [ entries ]  │   │  │
│   Villain, Ally,                  │  └──────────────────────┘   │  │
│   Neutral, Merchant,              └─────────────────────────────┘  │
│   Mentor, Rival)                                                    │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                       EventSystem                            │   │
│  │  RelationshipEvent ──► apply delta ──► threshold transition  │   │
│  │  (Combat, Betrayal,    to intensity    (Nemesis/Rival/…)     │   │
│  │   Assistance, Rescue,                  fire callbacks        │   │
│  │   Gift, Trade, …)                      log to history        │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Core Classes

| Class | Responsibility |
|---|---|
| `Character` | Base for all characters; holds id, name, type, and a manager reference |
| `CharacterType` | Enum: `Player`, `NPC`, `Villain`, `Ally`, `Neutral`, `Merchant`, `Mentor`, `Rival` |
| `RelationshipType` | Enum: `Nemesis`, `Rival`, `Ally`, `Mentor`, `Neutral`, `Friend`, `Betrayer` |
| `Relationship` | Bidirectional link: dual perspectives, intensity, history, timestamps |
| `RelationshipEvent` | An event that happened between two characters (type, source, target, description) |
| `EventType` | Enum: `Combat`, `Betrayal`, `Assistance`, `Dialogue`, `Quest`, `Trade`, `Defeat`, `Victory`, `Gift`, `Theft`, `Murder`, `Rescue` |
| `EventSystem` | Processes events, applies intensity deltas, transitions relationship types, fires callbacks |
| `RelationshipManager` | Central registry — CRUD for characters/relationships + event dispatch |

### Relationship Intensity Thresholds

| Intensity | Relationship Type |
|---|---|
| ≤ −80 | Nemesis |
| −80 to −30 | Rival |
| −30 to +30 | Neutral |
| +30 to +60 | Friend |
| > +60 | Ally |

Special case: if an Ally or Friend relationship receives a large negative event (e.g. Betrayal), the type transitions to **Betrayer** rather than Rival.

### Default Event Deltas

| Event | Delta |
|---|---|
| Murder | −50 |
| Betrayal | −40 |
| Theft | −20 |
| Defeat | −15 |
| Combat | −10 |
| Dialogue / Trade | +5 |
| Quest / Victory | +10 |
| Gift | +15 |
| Assistance | +20 |
| Rescue | +30 |

---

## Language Implementations

### Python

**Location:** `python/`

**Requirements:** Python 3.10+, pytest

```bash
cd python
pip install pytest
python -m pytest tests/ -v
```

**Usage example:**
```python
from character import Character, CharacterType
from relationship_manager import RelationshipManager
from event import RelationshipEvent, EventType

manager = RelationshipManager()

player  = Character("p1", "Hero",      CharacterType.PLAYER)
villain = Character("v1", "Dark Lord", CharacterType.VILLAIN)
ally    = Character("a1", "Companion", CharacterType.ALLY)

manager.add_character(player)
manager.add_character(villain)
manager.add_character(ally)

# Create initial relationships
manager.create_relationship(player, villain)
manager.create_relationship(player, ally, initial_intensity=50)

# Process an event
evt = RelationshipEvent(EventType.BETRAYAL, villain, player, "Dark Lord betrayed the Hero")
manager.process_event(evt)

# Query
rel = manager.get_relationship(player, villain)
print(rel.intensity)                          # -40
print(rel.get_perspective(player).value)      # Rival

nemeses = manager.get_characters_by_type(player, RelationshipType.NEMESIS)
```

---

### C# (Unity-compatible)

**Location:** `csharp/`

**Requirements:** .NET 8 SDK

```bash
cd csharp
dotnet test --verbosity normal
```

**Usage example:**
```csharp
using NemesisSystem;

var manager = new RelationshipManager();

var player  = new Character("p1", "Hero",      CharacterType.Player);
var villain = new Character("v1", "Dark Lord", CharacterType.Villain);

manager.AddCharacter(player);
manager.AddCharacter(villain);
manager.CreateRelationship(player, villain);

// React to relationship changes
manager.EventSystem.OnRelationshipChanged += (rel, evt) =>
    Console.WriteLine($"Relationship changed! Intensity: {rel.Intensity}");

var evt = new RelationshipEvent(EventType.Betrayal, villain, player, "Betrayal!");
manager.ProcessEvent(evt);

var rel = manager.GetRelationship(player, villain);
Console.WriteLine(rel.GetPerspective(player));  // Rival
```

---

### TypeScript / JavaScript

**Location:** `javascript/`

**Requirements:** Node.js 18+, npm

```bash
cd javascript
npm install
npm test
```

**Usage example:**
```typescript
import { Character, CharacterType, RelationshipManager,
         RelationshipEvent, EventType } from './src';

const manager = new RelationshipManager();

const player  = new Character("p1", "Hero",      CharacterType.Player);
const villain = new Character("v1", "Dark Lord", CharacterType.Villain);

manager.addCharacter(player);
manager.addCharacter(villain);
manager.createRelationship(player, villain);

manager.eventSystem.addCallback((rel, evt) =>
  console.log(`Intensity: ${rel.intensity}`)
);

const evt = new RelationshipEvent(EventType.Betrayal, villain, player, "Betrayal!");
manager.processEvent(evt);

const rel = manager.getRelationship(player, villain)!;
console.log(rel.getPerspective(player));  // Rival
```

---

### GDScript (Godot 4.x)

**Location:** `gdscript/`

Copy the `gdscript/src/` folder into your Godot project. No external dependencies required.

```gdscript
var manager = RelationshipManager.new()

var player  = Character.new("p1", "Hero",      CharacterType.Type.PLAYER)
var villain = Character.new("v1", "Dark Lord", CharacterType.Type.VILLAIN)

manager.add_character(player)
manager.add_character(villain)
manager.create_relationship(player, villain)

# React to relationship changes
manager.get_event_system().add_callback(func(rel, evt):
    print("Intensity: " + str(rel.intensity))
)

var evt = RelationshipEvent.new(EventType.Type.BETRAYAL, villain, player, "Betrayal!")
manager.process_event(evt)

var rel = manager.get_relationship(player, villain)
print(rel.get_perspective(player))  # RIVAL
```

See `gdscript/README.md` for more details and `gdscript/examples/example_usage.gd` for a full runnable example.

---

## 🎮 Playable Demo Game — "Realm of Rivals"

The `godot-game/` directory contains a fully playable **2D Strategy/Roguelike** demo built in **Godot 4.x (GDScript)** that integrates the relationship system into real gameplay.

### Features
- **Procedural tile-based maps** with settlements, dungeons, markets, and wilderness
- **10+ NPCs** with unique names, roles, and personalities
- **Turn-based combat** where relationships affect attack power, mercy chances, and flee success
- **Dialogue & diplomacy** — trade, recruit, form alliances, betray, negotiate
- **Faction management** — party of up to 4, morale affected by inter-member rivalries
- **Roguelike legacy** — nemeses from previous runs return stronger and angrier
- **Live relationship panel** — color-coded view of all relationships (press `R`)
- **Event log** — every relationship change shown in real-time

### How to Run
1. Install [Godot 4.2+](https://godotengine.org/download)
2. Open `godot-game/project.godot` in Godot
3. Press **F5** to play

See [`godot-game/README.md`](godot-game/README.md) for full documentation, controls, and gameplay mechanics.

---

## Design Principles

- **Universal** — Any character type can form relationships with any other; not limited to player↔villain.
- **Bidirectional** — Each side of a relationship tracks its own perspective independently (Character A can see B as a Nemesis while B sees A as a Rival).
- **Dynamic** — Relationships evolve over time as events are processed.
- **Historical** — Every interaction that shaped a relationship is preserved in a history log.
- **Extensible** — Add new `RelationshipType` or `EventType` values and configure custom intensity rules without changing core logic.

## Project Structure

```
game-project/
├── README.md
├── python/
│   ├── character.py
│   ├── relationship.py
│   ├── event.py
│   ├── event_system.py
│   ├── relationship_manager.py
│   ├── __init__.py
│   ├── requirements.txt
│   ├── pytest.ini
│   └── tests/
│       ├── test_character.py
│       ├── test_relationship.py
│       ├── test_relationship_manager.py
│       └── test_event_system.py
├── csharp/
│   ├── NemesisSystem.sln
│   ├── NemesisSystem/
│   │   ├── Character.cs
│   │   ├── Relationship.cs
│   │   ├── RelationshipManager.cs
│   │   ├── EventSystem.cs
│   │   └── ...
│   └── NemesisSystem.Tests/
│       ├── CharacterTests.cs
│       ├── RelationshipTests.cs
│       ├── RelationshipManagerTests.cs
│       └── EventSystemTests.cs
├── javascript/
│   ├── src/
│   │   ├── Character.ts
│   │   ├── Relationship.ts
│   │   ├── RelationshipManager.ts
│   │   ├── EventSystem.ts
│   │   └── ...
│   ├── tests/
│   │   ├── character.test.ts
│   │   ├── relationship.test.ts
│   │   ├── relationshipManager.test.ts
│   │   └── eventSystem.test.ts
│   ├── package.json
│   └── tsconfig.json
├── gdscript/
│   ├── README.md
│   ├── src/
│   │   ├── Character.gd
│   │   ├── Relationship.gd
│   │   ├── RelationshipManager.gd
│   │   ├── EventSystem.gd
│   │   └── ...
│   └── examples/
│       └── example_usage.gd
└── godot-game/                    # 🎮 Playable demo game
    ├── project.godot
    ├── scenes/
    │   └── main.tscn
    ├── scripts/
    │   ├── main.gd
    │   ├── player.gd
    │   ├── npc.gd
    │   ├── combat_manager.gd
    │   ├── dialogue_manager.gd
    │   ├── map_generator.gd
    │   ├── hud.gd
    │   ├── faction_manager.gd
    │   ├── legacy_manager.gd
    │   └── relationship/          # Integrated from gdscript/src/
    └── README.md
```