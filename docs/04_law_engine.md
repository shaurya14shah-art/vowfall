# 04. Law Engine technical specification

Status: **implemented and tested headless**, and since M1 connected to a
character, an enemy and a HUD through `CombatBridge`. Only two laws (the
Writs on the sealed post) are met in play so far; the player cannot impose
one until M2.

Code: `game/core/law/` (four files). Data: `game/data/`. Tests:
`game/tests/`.

## 1. What it is

A deterministic simulation that holds entities, the laws imposed on them and
a queue of deferred consequences. Gameplay code never changes health,
position or laws directly. It **proposes an event** and receives a **record**
of what happened and why.

```gdscript
var world := LawWorld.new(registry)
world.add_entity({...})
var rec := world.impose(owner, "threshold.gatekeeper", {"line": [x1, y1, x2, y2]})
rec = world.strike(source, target, amount, ["from_front"], {"act": "light", "combo_index": 2})
rec = world.move(entity, [x, y])
world.advance(1)   # once per physics tick
world.add_resonance(id, 4)   # earned by the hands; reported by the combat layer
world.restore(id)            # rest: full health, back on their feet
world.set_form(id, "UNVEILED")   # the next law this entity imposes uses that form
world.retire(id)             # gone from the field; its laws end
world.would_breach(id, [x, y])   # a question, not an act: would this step end one of my own laws?
```

An `INVERT` returns `max(amount, data.weight)`. A parried blow reaches the
engine with no harm left in it; `weight` is what it was thrown with, so the
Answer returns the whole blow.

In play these calls are made by one node, `CombatBridge`
(`game/gameplay/combat/combat_bridge.gd`). Nothing else may.

## 2. Invariants (do not break these)

1. No nodes, no floats, no wall clock, no unseeded randomness in `core/law/`.
   Positions are integer centimetres on the ground plane.
2. `law_world.gd` names no law. Behaviour comes from data.
3. Every event goes through the same pipeline in the same order.
4. Every clause that fires writes a reason in plain language.
5. Iteration order is defined: laws in order of imposition, clauses in file
   order, entities by id.
6. The world serialises to JSON and back with no change in behaviour.

## 3. Data model

**Entity:** id, name, team, tags (with optional expiry tick), hp, hp_max,
resonance, mastery, form (`DORMANT` or `UNVEILED`), pos, alive, last_act.

**Event:** id, kind (`STRIKE`, `HARM`, `HEAL`, `MOVE`, `IMPOSE`), source,
target, amount, tags, data, from, to, depth.

**Law instance:** id, def_id, form, owner, team, args (line, pair, centre),
authority, ticks_left, events_left.

**Held entry:** a deferred consequence: which law holds it, the event it
will become, its amount, and either a due tick with interest or a lapse tick.

**Record:** kind, source, target, tags, amount in and out, a verdict
(`APPLIED`, `REJECTED`, `CONVERTED`, `HELD`), a list of outcomes, and the
records of every consequence, nested.

## 4. The pipeline

For each proposed event:

1. **Validate.** Does the source exist and can it act; is there a target; for
   an `IMPOSE`, can the price be paid, is the scope well formed, do the
   conditions hold. Failure is a `REJECTION` with the reason, and nothing is
   spent.
2. **NOTICE.** Laws that observe an attempt regardless of how it ends
   (recognition, counting acts).
3. **DENY.** Laws that forbid it. Conflicts with laws that require it are
   settled here.
4. **REDIRECT.** Laws that turn it around.
5. **MODIFY.** Laws that change its amount.
6. **HOLD.** Laws that take it out of the present (deferral).
7. **Commit.** A `STRIKE` becomes a `HARM`. A `HARM` changes health. A `MOVE`
   changes position and may breach the mover's own laws. An `IMPOSE` takes
   the price and establishes the law.
8. **REACT.** Laws that respond to what just happened: copy it, mirror it,
   record it as a loan, pay a debt forward.
9. **Consequences.** Every event produced along the way is resolved through
   the same pipeline, one level deeper. Past eight levels a chain is cut off
   and logged as a `CANCELLATION`.

After each top-level event, and once per tick, breaches are checked (author
down, pair parted, pair member down) and ended laws are removed.

## 5. Conflict of laws

A clause takes a **stance** toward an event: `FORBID` (DENY, DIVIDE), `TAKE`
(INVERT, a DEFER that moves the harm) or `REQUIRE` (PRESERVE). When a
FORBID or TAKE meets an opposing team's REQUIRE on the same event, three
questions are asked in order.

1. **Rank.** If one law is two or more tiers above the other, it prevails.
   The lower law survives but does not apply. *Outcome: OVERRIDE.*
2. **Specificity.** Otherwise the narrower scope prevails for this event:
   SELF and TARGET (4) over PAIR and LINE (3) over RING and ZONE (2) over
   FIELD (1). *Outcome: OVERRIDE.* "The narrower law carves its exception
   from the broader."
3. **Authority.** Otherwise compare authority (tier x 10 + Resonance
   committed at imposition, up to 10 + mastery). A lead of more than 2
   prevails and **the loser is broken**. *Outcome: CONTEST.* Within 2, both
   laws end and the event proceeds. *Outcome: CANCELLATION.*

Rank is asked before specificity only at a gap of two tiers, on purpose. A
Technique cannot excuse anyone from an Edict. A Manifestation, one tier
below, can carve a narrow exception out of one. That is the intended
late-game answer to Edicts.

### The five outcomes, as implemented

| Outcome | When the engine writes it | Tested by |
|---|---|---|
| REJECTION | An event or imposition is denied by a law, or cannot meet its own price, scope or condition | 20 scenarios |
| OVERRIDE | Rank or specificity settles a conflict; both laws persist | Warrant vs Gatekeeper; The Hearing vs Warrant |
| CONTEST | Authority settles it; the loser is broken | Gatekeeper with committed Resonance vs Escort |
| CANCELLATION | Authority is matched; both end. Also a runaway chain | Gatekeeper vs Escort; loop guard |
| CONVERSION | A law changes what an event *is*: a harm into a debt, a debt into a strike, a blow into its return | Creditor, Debtor, Answer |

Two further record types are bookkeeping, not interactions: `EFFECT` (a law
simply did its work) and `BREACH` (a law ended by its own terms).

Most interesting matchups need no conflict rule at all. They fall out of
stage order and tags. A Divide between two twins stops the copy because the
copy is an event with a path and the path crosses the line. A deferred harm
is not copied to a twin until it comes due, because HOLD runs before REACT.
None of that is written anywhere as a special case.

## 6. Knowledge

Each time a law's clause fires on an event, the teams of the source and
target each witness it once. One sighting: the law is **sensed** (its name
shows). Three: it is **read** (its clauses and answers show). An Edict is
spoken aloud and is read by everyone at once. This counter is what the Codex
persists across Chronicles.

## 7. Adding a law

1. Write the definition in `game/data/laws/<root>.json`.
2. Add at least one scenario in `game/tests/scenarios/` that states what it
   does and one that states how it is answered.
3. Run the tests. The validator runs first.

Adding a new **parameter** to an existing operation means editing
`law_world.gd` (`_transfer`, `_defer` or `_apply`). Adding a new operation
means that plus the validator's tables. Twelve laws currently run on eight
clause operations (BIND is the PAIR scope), with four TRANSFER modes and two
DEFER modes.

## 8. Measured cost

M4, GDScript, release editor binary, headless:

| Operation | Cost |
|---|---|
| One strike judged by four standing laws, with its consequences | 134 us |
| One idle tick | 3 us |
| Save to dictionary and hash | 28 us |

At 60 Hz a frame is 16,667 us. The engine's budget is 500. A heavy fight
(ten strikes landing in one frame) uses about a twelfth of a frame.

## 9. Multiplayer readiness

The engine is already the authoritative form: integer state, ordered
resolution, serialisable, replayable from inputs, hashable for desync
checks. A server would run the same `LawWorld` and clients would propose
events. No networking is implemented and none should be until the slice is
fun alone.

## 10. Known limits

* Scopes are 2D. Height is ignored. Fine for the slice's flat arenas; a
  vertical encounter needs a height band on LINE and RING.
* `IMPOSE` checks its path to the first of a pair only.
* PRESERVE protects acts, not states. "This cannot change" is not built.
* BIND exists only as the PAIR scope, not as a clause operation.
* ZONE scope and TARGET scope are accepted by the validator and have no
  shipped law using them.
* Doctrine tenets, player Edicts and Paradox forms are not implemented.
* Vows are (2026-11-13): tier `VOW`, breach type `EVENT` (checked just
  before an event stands, so a denied act breaks nothing), a `forfeit`, a
  `reward`, `LawWorld.keep`, and `standing` on an entity, added to the
  authority of what it imposes. See `03_axiom_system.md` section 8.
* No law definition migration between versions.
