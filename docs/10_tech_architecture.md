# 10. Technical architecture

## Engine

Godot 4.7.2, typed GDScript, Forward+ renderer on Metal. Reasons: D-001 and
D-002 in `DECISIONS.md`.

## Three layers, one direction of dependency

```
presentation   scenes, animation, VFX, audio, UI          reads records
     |
gameplay       controller, combat, AI, quests, world      proposes events
     |
core           LawWorld, LawRegistry, LawValidator        knows nothing above it
```

* **core** is pure: `RefCounted` classes, integers, no nodes. It runs
  headless and is the only layer with authority over health, position and
  laws.
* **gameplay** owns nodes and input. It turns a button press and a hitbox
  overlap into `world.strike(...)` and turns the record into state changes
  on nodes.
* **presentation** never decides anything. It plays what the record says.

A rule for reviewers: if a script in `core/` mentions `Node`, `float`,
`randf` or `Time`, it is a bug.

## Folder structure

```
Vowfall/
  README.md  AGENTS.md
  docs/                      the development bible (this folder)
  design/references/         prompts and, later, generated concept images
  game/                      the Godot project
    project.godot
    core/law/                Law Engine                      IMPLEMENTED
    core/combat/             action machine (pure)           IMPLEMENTED
    core/chronicle/          save, Codex, awakening          planned
    data/roots.json          the eighteen Roots              IMPLEMENTED
    data/laws/*.json         law definitions                 IMPLEMENTED (12)
    data/instruments/        movesets                        two placeholders
    data/encounters/         enemy groups, boss phases       planned
    gameplay/combat/         CombatBridge                    IMPLEMENTED
    gameplay/actors/         Actor, Player, Bailiff, Post    IMPLEMENTED (M1)
    gameplay/world/          the practice yard               IMPLEMENTED (M1)
    presentation/            hud, camera, sfx, look, shaders IMPLEMENTED (M1)
    scenes/                  Arena.tscn, tools/TestM1.tscn
    assets/                  production assets
    assets/placeholder/      CC0 and retargeted, with licences
    tests/                   run_tests.gd, bench.gd, scenarios/
```

## The seventeen systems

| # | System | Layer | Status | Notes |
|---|---|---|---|---|
| 1 | Character controller | gameplay | **Tested** headless, unplayed | `Actor`, `Player`, `FollowCamera` |
| 2 | Combat framework | core + gameplay | **Tested** headless, untuned | `ActionMachine` (pure), `CombatBridge`, movesets as data |
| 3 | Axiom registry | core | **Tested** | `LawRegistry` |
| 4 | Root generation (awakening) | core | Designed | `core/chronicle/awakening.gd` |
| 5 | Assertion interpreter | core | **Tested** | The clause pipeline in `LawWorld` |
| 6 | Law Engine | core | **Tested** | `LawWorld` |
| 7 | Instrument system | gameplay + data | **Tested** headless | `data/instruments/index.json` binds Root to Instrument: moveset, verb, what is held in each form. In `Player`. No fittings yet |
| 8 | Transformation manager | core + gameplay | **Tested** headless (Unveiling only) | `Recognition` (pure) counts trials from engine notes; `Player` runs the rite; `CombatBridge.unveil` changes form. No sequence, no Sovereignty, no Paradox |
| 9 | Enemy AI | gameplay | Prototyped | `Enemy`, data-driven (`data/enemies/`): approach, circle, strike, guard, riposte, take turns, keep its laws standing when its data says to. Seeded |
| 10 | Boss framework | gameplay | Prototyped | Voss's laws exist; no phases, no AI |
| 11 | World state manager | core | Designed | Flags and faction standing, same save path |
| 12 | Chronicle system | core | Designed | |
| 13 | Codex | core | Prototyped | Knowledge counters exist and are saved; the bridge keeps a text verdict log (the "Record" page); no persistence across runs |
| 14 | Save system | core | Prototyped | `LawWorld.to_dict` and `from_dict` are tested; no file, no slots |
| 15 | UI framework | presentation | Prototyped | One immediate-mode HUD canvas. No menus |
| 16 | Audio and VFX | presentation | Prototyped | Placeholder sound pool, hit flash, contact ring, `LawFx` for standing laws |
| 17 | Testing and validation | tests | **Implemented** | 238 checks, scripted-input harness, policy bots, benchmark |

Status words are the Directive's: Designed, Prototyped, Implemented, Tested,
Polished, Complete. Nothing is Polished or Complete.

## Core interfaces

```gdscript
# core/law/law_world.gd
func add_entity(spec: Dictionary) -> int
func strike(source: int, target: int, amount: int, tags := [], data := {}) -> Dictionary
func heal(source: int, target: int, amount: int) -> Dictionary
func move(id: int, to: Array) -> Dictionary
func impose(owner: int, def_id: String, args := {}) -> Dictionary
func advance(ticks: int) -> void
func find_law(owner: int, def_id: String) -> Dictionary
func held_total(owner: int, def_id: String) -> int
func knowledge_level(team: int, def_id: String) -> int
func to_dict() -> Dictionary
static func from_dict(reg: LawRegistry, data: Dictionary) -> LawWorld
func state_hash() -> String
```

The gameplay layer has one bridge, `CombatBridge`, which:

1. owns the `LawWorld` for the current area;
2. maps nodes to entity ids and proposes a `MOVE` whenever an actor's
   position changes by a centimetre; a refused step puts the actor back and
   knocks it off the line, so one attempt is one refusal;
3. tags each strike (`from_front`, `from_behind`, `guarded`,
   `perfect_parry`, with `act` and `combo_index` as data);
4. tells the two actors what happened and emits `struck` and `verdict` for
   the HUD, effects and sound.

Each actor is: `_think()` (the player's input, or an AI, filling the same
intent fields) then `ActionMachine.tick()` then movement then a reach-and-arc
test on active ticks. An AI presses the same buttons a player does.
Physics interpolation is on, so the 60 Hz simulation renders smoothly on a
120 Hz display; the camera follows interpolated positions.

## Data schemas

Law definition: see `03_axiom_system.md` section 3 and any file in
`game/data/laws/`. Root: `game/data/roots.json`. Scenario:
`game/tests/scenarios/*.json` (a cast, a list of steps, expectations).

Planned schemas, to be written when their systems are built: instrument
frame (strings, frame data, act names), encounter (entities, laws imposed
on entry, phase triggers), chronicle (seed, awakening evidence, flags,
standing), codex (knowledge counters, discoveries).

## Save format

JSON, versioned at the top level. A save is the Chronicle, the world state
manager's flags, and the current `LawWorld.to_dict()`. The Codex is a
separate file shared across Chronicles. The test suite already proves that
a `LawWorld` saved and reloaded between every step of every scenario ends in
the identical state.

## Determinism and future multiplayer

Fixed 60 Hz tick, integer state, ordered iteration, no hidden randomness,
state hashing. Any randomness added later (AI choice, fittings) must draw
from a seeded generator stored in the saved state. With that, a session is
replayable from its inputs and a server can be authoritative. No networking
is to be written before the slice ships.

## Performance budget

Target hardware: this machine. Apple M4, 16 GB, 60 frames per second at the
display's native size through MetalFX upscaling from roughly 50% (the
approach that worked in Crownfall).

| Budget per frame (16.7 ms) | Limit |
|---|---|
| Law Engine | 0.5 ms (measured 0.13 ms per fully judged strike) |
| Gameplay scripts and AI | 2.0 ms |
| Animation | 2.0 ms |
| Rendering | 10.0 ms |
| Headroom | 2.2 ms |

| Scene limits | Limit |
|---|---|
| Draw calls | 1,500 |
| Triangles on screen | 1.5 million |
| Shadow-casting lights | 2 |
| Particles | 20,000 |
| Active AI agents | 12 |
| Memory | 6 GB |

Rule: measure before and after every visual change with a bench scene, as
in Crownfall. No optimisation without a number.

## Risks in the architecture

* GDScript speed in the gameplay layer with many agents. Mitigation: AI
  thinks at 10 Hz, not 60; the core is already cheap.
* Sync between physics positions (floats, metres) and core positions
  (integers, centimetres). The bridge rounds once per tick, in one place.
* Law definition changes after saves exist. Versions are stored; migration
  is not designed yet.
