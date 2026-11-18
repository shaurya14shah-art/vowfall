# VOWFALL

A third-person action RPG in which power is a personal law. Godot 4.7.

**What can be played today is a practice yard and one district** (milestones
M1 to M5): move, strike, dodge, guard, parry and lock on; impose any of six
laws with one of three Instruments; fight a Bailiff, a Bailiff with a
Warrant, a Bailiff and his Ward, four Clerks, or the boss, Aurel Voss; and
walk the Assize Quarter, where all of them keep posts between you and his
Hall. The HUD names the law behind every denied strike. It passes 502
headless checks. Nobody has played it yet, and the Quarter has not yet been
seen on a screen. The figures, weapons, posts and columns
are the game's own models, built by scripts in `tools/blender/`; their
motion, the sounds and the fonts are still borrowed.

## Play the yard

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path game
```

This opens a game window. WASD to move, mouse to look, left and right mouse
for light and heavy, Space to dodge, Shift to guard (tap just before a blow
to parry), Tab to lock on, Esc to free the mouse, Backspace to reset. A
gamepad works too. The left post is for hitting. The right post is sealed
with two Writs: find what they forbid.

Your Instrument (M3) follows your law: the Lintel (long, slow) for 1 and 2,
the Tally (short, quick, a strong guard) for 3 and 4, the Counterpart for 5
and 6. Each law has a trial shown on its panel; when it reads RECOGNISED,
hold Q and Shift together, unstruck, to Unveil.

Your law (M2): keys 1 to 6 choose one of the six. **Q** imposes it: tap to
bar the way in front of you, or hold and walk to draw a line; holding
longer commits more Resonance. Hold Q while striking to inscribe the strike
(the Creditor's call-in). R rests (full health and Resonance), U switches to
the Unveiled form, N brings the next opponents, L saves the verdict log.
You need Resonance to impose: land hits, or press R.

**The Assize Quarter** (M5): press **T** in the yard, or T again to come
back. You start in the Oath-Market with the gate sealed behind you. **E**
reads what can be read, opens what opens, and at a vow-stone offers a
choice: 1 rests (whole again; you stand there if you fall; everyone you put
down returns), 2 to 5 swear a **Vow**. A Vow is a promise with a stake:
clear the next post without the named thing happening and it is kept (your
Resonance is made whole and your laws carry more weight until you next
rest); let it happen and the vow falls, and you pay on the spot. R, U and
N do nothing here. The Stair leads up to the Hall. There is another way
round. A plan is in [docs/assize_quarter_map.png](docs/assize_quarter_map.png).

The fifth opponent (M4) is Aurel Voss. He says each rule before he enforces
it: do not strike him from behind, do not strike him a third time
unanswered, do not impose a law until a perfect parry has earned his
recognition. Below a third of his health he speaks an Edict that binds him
too: no one may make the same strike twice running. He yields; when he
offers his licence, 1 takes it and 2 refuses.

## Start here

| Read | For |
|---|---|
| [docs/STATUS.md](docs/STATUS.md) | What is done, what is not, what is blocked, what needs a decision |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Every change to the original concept, and why |
| [docs/02_game_design.md](docs/02_game_design.md) | The game in five pages |
| [docs/04_law_engine.md](docs/04_law_engine.md) | How laws meet |

## The development bible

| # | Document |
|---|---|
| 00 | [Environment audit](docs/00_environment_audit.md) |
| 01 | [Design audit](docs/01_design_audit.md) |
| 02 | [Master game design](docs/02_game_design.md) |
| 03 | [Axiom system specification](docs/03_axiom_system.md) |
| 04 | [Law Engine technical specification](docs/04_law_engine.md) |
| 05 | [Combat design](docs/05_combat.md) |
| 06 | [Characters and Instruments](docs/06_characters_instruments.md) |
| 07 | [Narrative and world bible](docs/07_world_narrative.md) (spoilers) |
| 08 | [Art direction bible](docs/08_art_direction.md) |
| 09 | [UI and UX specification](docs/09_ui_ux.md) |
| 10 | [Technical architecture](docs/10_tech_architecture.md) |
| 11 | [Production roadmap](docs/11_roadmap.md) |
| 12 | [Testing strategy](docs/12_testing.md) |

Visual reference prompts: [design/references/PROMPTS.md](design/references/PROMPTS.md).

## Run the tests

```bash
./tools/test.sh
```

No window opens. It takes several minutes. Expect `90 passed`, `82 passed`,
`91 passed`, `54 passed`, `50 passed`, `135 passed`, `ALL TESTS PASSED`. Three example
fights are logged in `docs/m2_logs/` and six against Voss in `docs/m4_logs/`.

## What a law looks like (abridged)

```json
{
  "id": "threshold.gatekeeper",
  "thesis": "Nothing may cross without permission.",
  "tier": "TECHNIQUE",
  "scope": {"shape": "LINE", "max_length": 600},
  "term": {"ticks": 480, "events": 3},
  "price": {"resonance": 30},
  "breach": [{"type": "OWNER_CROSSES"}],
  "counterplay": ["GO_AROUND", "EXHAUST", "BAIT_OWNER"],
  "clauses": [{
    "on": ["STRIKE", "MOVE"], "stage": "DENY", "op": "DENY", "counts": true,
    "where": {"source": {"rel": "HOSTILE", "none": ["admitted"]}, "path": "CROSSES"},
    "reason": "it crossed a line it was not admitted through"
  }]
}
```

The engine names no law in code. Twelve of these exist in `game/data/laws/`.
