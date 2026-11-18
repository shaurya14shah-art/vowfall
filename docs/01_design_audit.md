# 01. Design audit

An independent read of the Master Directive and "The Definitive Axiom System"
v1.0. Every change proposed here is logged in `DECISIONS.md` with its reasons.

## The strongest ideas (keep, build everything around these)

1. **Power as a personal law with a Condition and a Price.** Identity, balance
   and counterplay come from one sentence. This is the game.
2. **The Law Engine.** Matchups decided by what the rules say, not by a chart
   of which element beats which. It is also the part that can be proven with
   tests before a single animation exists. It now has been (40 scenarios).
3. **Paradox as reinterpretation.** A late-game upgrade that changes what the
   character is, not how big the number is.
4. **Knowledge persists across characters, power does not.** The right kind of
   meta-progression for a game about understanding rules.
5. **No monetised awakenings.** Correct, and worth stating on the store page.

## The weakest systems

### 1. "Individually generated" Axioms and Instruments
The documents ask for procedurally generated powers and weapons that also
have unique silhouettes, idle animations, movesets and three forms. Those two
demands cannot both be met. Animation is the most expensive asset in an action
game; nobody generates it to a shippable standard. A grammar that combines
parts freely produces mostly dull or broken abilities, and the documents
already half admit this ("select and combine designer-authored components").

**Change (D-004):** Axioms are authored. The grammar is a *validator and a
description language*, not a slot machine. Variety comes from authored
Assertions x Doctrine x Instrument frame, and from what the Law Engine does
when two of them meet. The generator's job is to choose which authored
candidates to offer a player, and why.

### 2. Eighteen Roots with overlapping mechanics
* Continuity (Cael records and replays states), Memory (Nyxara recalls
  recorded events) and the Reflection example (reproduce a recorded action)
  are the same mechanic three times.
* Absence and Silence both suppress. Permission and Threshold both gate.
  "The Uninvited" is filed under Threshold but is a Permission power.
* The Debt example is about momentum, which is Velocity's subject.
* Possibility cannot be done honestly in a deterministic action game without
  either invisible dice or branching timelines.

**Change (D-003):** Each Root is defined by the one thing it governs in the
Law Engine (a boundary, a ledger, a correspondence, a tag), so two Roots
cannot be the same mechanic. The world teaches **Twelve**; **six were struck
from the Canon**. Each family is taught as a pair, and the struck third is
the term that breaks the pair. This cuts launch scope by a third, gives
"forbidden Roots" a reason to exist, and ties straight into the central
mystery. Details in `03_axiom_system.md`.

### 3. Doctrines
Dominion, Custody, Guile and Convergence read as aggressive, defensive,
tricky and combo. Every action game has those. "Convergence" is a skill
level, not a philosophy.

**Change (D-006):** Each Doctrine now owns one property of the Law Engine:
Authority (win contests), Persistence (last and resist), Trigger (alternate
conditions), Chain (laws that feed each other). Same names, real mechanics.

### 4. Edicts
"Temporarily impose your rule on the battlefield" is a familiar shape from
other fiction and risks being a win button.

**Change (D-007):** Two rules make an Edict VOWFALL's own. **An Edict binds
its author**, and **an Edict's term is counted in acts, not seconds** ("for
the next nine acts"). Both are enforced by the validator and demonstrated by
Voss's Edict in the test suite.

### 5. The awakening formula
Sampling a Root from a weighted distribution is randomness the player cannot
see, so it reads as arbitrary. Scoring "protected an NPC" is noisy.

**Change (D-012):** The awakening is deterministic from the Chronicle seed
and shows its evidence: each candidate lists the moments that produced it.
The prologue is built from dilemmas where every option is a legitimate way to
play. Later Chronicles may choose a Root already recorded in the Codex.

### 6. Seven regions
Seven bespoke open-world regions is a large-studio scope.

**Change (D-009):** Six Severances, one per struck Root, with the Hanging
Kingdom folded into Veyr as its upper city. Launch target is Veyr plus three,
with the Unwritten as endgame. The slice is one district of Veyr.

## Contradictions found, and how each is resolved

| Contradiction | Resolution |
|---|---|
| "Fully customisable protagonist, limited authored dialogue" vs "a meaningful personal story driven by psychology" | The protagonist has a fixed *role* (a sworn Witness) and a free *person*. Story hangs on the role; choices define the person |
| "Individually generated Instruments" vs "unique animations and silhouette" | Three authored movesets ("frames") in the slice; generated cosmetic fittings on top |
| "Interconnected open world" vs "a smaller world is preferable" | Interconnected districts, not an open map. No filler activities |
| Preferred engine UE5 vs the machine and its owner | Godot 4.7 (D-001) |
| "Extremely powerful late game" vs "skill still matters" | Laws are symmetric, priced and budgeted. Power grows in reach and rank, never into immunity (the validator refuses it) |
| Five instrument archetypes, one of which is "anything else" | Four frames. "Singular" is reserved for bosses |
| Aerial combos "where appropriate" vs slice cost | Not in the slice. Plunge attacks only. Revisit after the slice |
| Schedule: 19 to 30 weeks for the slice | Unrealistic for one person at the stated content. See `11_roadmap.md` |
| The concept art embedded in the design doc | Scraped from other games, AI galleries and unrelated pages (one is a fantasy football article). Treated as mood only, never stored, never shipped |

## Scope and technical risks

| Risk | Severity | Mitigation |
|---|---|---|
| Animation volume | High | Three frames, about 18 clips each, retargeted from CC0 and Mixamo sets first |
| Rules too clever to read in a fight | High | Every clause carries a plain-language reason; verdict line on the HUD; Codex reveals a law after three sightings |
| Combinatorial balance | Medium | Validator, power budget, automated bot matches (planned) |
| Solo production of a "commercial open-world RPG" | High | The slice is the product. It is scoped to stand alone |
| Performance on a 16 GB laptop | Medium | Stylised rendering, measured budgets, MetalFX upscaling as in Crownfall |
| Law Engine in GDScript | Low | 134 microseconds per fully judged strike measured; budget is 500 |

## Open questions that are the owner's to answer

1. Confirm Godot (or say what should change to make Unreal possible).
2. The Canon Twelve and the Struck Six: accept, or keep all eighteen taught?
3. Is the slice allowed to be a standalone short game with its own release?
4. Art direction "Illuminated Law" (`08_art_direction.md`): accept?
