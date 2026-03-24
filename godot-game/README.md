# Realm of Rivals — Godot 4.x Demo Game

**"Realm of Rivals"** is a playable 2D top-down Strategy/Simulation + Roguelike built in **Godot 4.x (GDScript)**. It integrates the universal nemesis/relationship system from the `gdscript/` directory, turning abstract relationship data into lived, emergent gameplay.

Every NPC remembers what you did. Betray an ally and they become a nemesis. Help a stranger and they join your faction. Die, and your enemies grow stronger for the next run.

---

## How to Open and Run

### Prerequisites
- **Godot Engine 4.2+** — Download from [godotengine.org](https://godotengine.org/download)
- No additional plugins or assets required

### Steps
1. Open Godot 4.x
2. Click **"Import"** on the Project Manager screen
3. Navigate to `godot-game/` in this repository and select `project.godot`
4. Click **"Import & Edit"**
5. Press **F5** (or the Play button ▶) to run the game

> The game is fully self-contained — all characters are rendered as colored geometric shapes, and all UI is built programmatically. No external assets are required.

---

## Game Controls

| Key | Action |
|-----|--------|
| `W / ↑` | Move up |
| `S / ↓` | Move down |
| `A / ←` | Move left |
| `D / →` | Move right |
| `E` | Interact with adjacent NPC |
| `R` | Toggle Relationship Panel |
| `F` | Toggle Faction Panel |

### Character Visual Guide

| Color | Character Type |
|-------|---------------|
| 🟦 Blue | You (The Wanderer) |
| 🟥 Red | Warrior |
| 🟨 Yellow-Gold | Merchant |
| 🟪 Purple | Scholar |
| ⬛ Dark | Assassin |
| 🟧 Orange | Leader |
| 🟩 Green | Healer |
| 🟤 Teal | Scout |
| 🔲 Brown | Bandit |
| 🔴 Red border | Legacy Nemesis (from a previous run) |

---

## Gameplay Mechanics

### Core Loop
1. **Explore** the procedurally generated map (WASD movement)
2. **Approach** an NPC (character stops you when adjacent)
3. **Interact** (`E`) to open the dialogue/interaction menu
4. **Choose** your action (talk, trade, recruit, fight, gift, etc.)
5. **Every action updates relationships** — shown instantly in the Relationship Panel

### Relationship System
Relationships between the player and NPCs (and NPCs with each other) evolve based on events:

| Action | Relationship Effect |
|--------|-------------------|
| Attack / Combat | -10 intensity |
| Betray | -40 intensity (may trigger Betrayer type) |
| Gift | +15 intensity |
| Trade | +5 intensity |
| Rescue / Spare | +30 intensity |
| Execute | -50 intensity with nearby witnesses |
| Assist / Help | +20 intensity |

**Intensity thresholds:**
- `≤ -80` → **NEMESIS** (fights you harder, refuses mercy)
- `≤ -30` → **Rival** (harder to flee, more aggressive)
- `-30 to 30` → **Neutral**
- `30 to 60` → **Friend** (may join your party)
- `≥ 60` → **Ally** (joins your party, fights alongside you)

### Relationship Panel (`R`)
A color-coded panel showing all known characters and their relationship to you:
- 🔴 **NEMESIS** — Hunting you
- 🟠 **Rival** — Competing against you
- 🟡 **Neutral** — Indifferent
- 🟢 **Friend** — Helpful and friendly
- 🟩 **Ally** — Fully committed to your cause
- 🔵 **Mentor** — Teaching and guiding

### Combat (Turn-Based)
When you choose to fight (or are forced into combat):
- **Attack** — Standard attack
- **Defend** — Halve incoming damage this round
- **Power Strike** — 1.8× damage, costs HP
- **Flee** — Attempt to escape (harder vs. Nemesis)
- **Show Mercy** — Spare weakened enemies (changes relationship)

Relationships affect combat:
- **Nemeses** deal +8 bonus damage
- **Rivals** deal +4 bonus damage
- **Post-combat**: Choose to **Spare** (goodwill) or **Execute** (removes threat, breeds hatred)

### Faction System (`F`)
- Recruit up to 4 NPCs to your party
- Party members who are **rivals of each other** reduce morale
- Morale affects your attack bonus/penalty
- Each NPC belongs to a faction (Warriors Lodge, Merchant Guild, etc.)
- Diplomacy actions affect faction-wide reputation

### Roguelike Legacy System
When you die:
1. All **Nemeses and Rivals** are saved to `user://realm_of_rivals_legacy.json`
2. On the **next run**, they return — same names, stronger stats (+attack, +HP)
3. They start with the **NEMESIS** relationship pre-set
4. Defeat them permanently to remove them from your legacy
5. Legacy accumulates across runs: run count, total kills, total reputation

---

## Project Structure

```
godot-game/
├── project.godot                  # Godot 4.x project file
├── scenes/
│   └── main.tscn                  # Root scene (everything built programmatically)
├── scripts/
│   ├── main.gd                    # Game controller + state machine
│   ├── player.gd                  # Player character (movement, stats, rendering)
│   ├── npc.gd                     # NPC character (behaviour, dialogue, rendering)
│   ├── combat_manager.gd          # Turn-based combat system
│   ├── dialogue_manager.gd        # Dialogue trees + diplomacy
│   ├── map_generator.gd           # Procedural tile-based map generation
│   ├── hud.gd                     # HUD overlay (health, log, relationship panel)
│   ├── faction_manager.gd         # Party + faction reputation system
│   ├── legacy_manager.gd          # Persistent data between runs
│   ├── relationship/              # Relationship system (from gdscript/src/)
│   │   ├── Character.gd
│   │   ├── CharacterType.gd
│   │   ├── Relationship.gd
│   │   ├── RelationshipManager.gd
│   │   ├── RelationshipEvent.gd
│   │   ├── RelationshipType.gd
│   │   ├── EventSystem.gd
│   │   ├── EventType.gd
│   │   └── HistoryEntry.gd
│   └── utils/
│       ├── NameGenerator.gd       # Random fantasy name generation
│       └── RandomUtils.gd         # RNG helper utilities
└── assets/
    ├── sprites/
    │   └── icon.svg               # Game icon
    ├── tiles/                     # (placeholder — tiles drawn procedurally)
    └── audio/                     # (placeholder — no audio in this demo)
```

---

## How the Relationship System is Integrated

The relationship system from `gdscript/src/` is copied into `scripts/relationship/` and used throughout the game:

### 1. Character Registration
Every NPC and the player is registered with `RelationshipManager` at game start:
```gdscript
var player_char = Character.new("player_0", "The Wanderer", CharacterType.Type.PLAYER)
relationship_manager.add_character(player_char)
```

### 2. Event Processing
Every player action fires a `RelationshipEvent`:
```gdscript
var event = RelationshipEvent.new(EventType.Type.BETRAYAL, player.character, npc.character, "...")
relationship_manager.process_event(event)
```

### 3. Reactive Callbacks
The `EventSystem` callback updates the HUD and shows notifications:
```gdscript
relationship_manager.get_event_system().add_callback(
    func(rel: Relationship, evt: RelationshipEvent):
        hud.show_notification("Relationship changed to: " + rel_name)
)
```

### 4. Gameplay Effects
Relationship state affects every system:
- **Combat**: Nemeses deal more damage; Allies may refuse to fight
- **Dialogue**: NPCs greet you differently; Charisma modifies success rates
- **Recruitment**: Allies are easy to recruit; Nemeses are impossible
- **Faction morale**: Rivals in the same party reduce morale

### 5. Legacy Persistence
At game over, nemesis data is serialized to JSON and reloaded on the next run:
```gdscript
legacy_manager.record_nemesis(char_id, char_name, role, kill_count, intensity)
# On next run:
var nemeses = legacy_manager.get_legacy_nemeses()  # Returns evolved nemesis data
```

---

## Screenshots

> *Screenshots pending — run the game in Godot 4.x to see it in action!*

---

## Design Notes

- **No external assets required** — all characters and tiles use procedurally drawn colored geometry
- **Fully data-driven relationships** — no hard-coded relationship logic in gameplay code; all transitions flow through `EventSystem`
- **Emergent storytelling** — interesting narratives arise naturally from the relationship system: a merchant you robbed becomes a rival, a warrior you spared becomes your most loyal ally

---

## License

MIT — see root `LICENSE` file (if present).
