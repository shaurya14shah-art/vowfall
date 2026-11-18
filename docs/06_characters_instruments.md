# 06. Characters and Instruments

Status: the three Instruments are **built and tested headless** (M3): each
has a model in two forms, a moveset fitted to borrowed motion clips, and its
verb. The Witness, Bailiff, Ward, Clerk and Voss have models. Voss is a
fight in the practice yard, **built and tested headless** (M4), unseen and
unplayed. The tables below are the design; where the build differs it says so in
`STATUS.md`. Running numbers live in `game/data/instruments/`.

## The protagonist: a Witness

In Veyr a vow spoken before a witness binds, so witnessing is a trade.
The player is a sworn Witness: paid to stand present while others promise,
and bound never to lie about what was seen.

* **Fixed:** the role, the inciting event, the fact that your testimony
  matters to three factions.
* **Free:** appearance, voice, name, origin (one of four, each seeding
  history resonance), and every choice.
* **Arc:** you are asked throughout to say what you saw. What you saw
  becomes less certain the more you learn. Your Paradox is the moment you
  understand what your own Thesis left out.

Silhouette rule: a long witness-coat cut asymmetrically (one sleeve bound
for the Instrument arm), a collar that reads at distance, no armour plates.
The Instrument is always the brightest, sharpest shape on the character.

## Instruments

An Instrument is a **frame** (a moveset and rig), an **Instrument verb**
(the thing it physically does for the Assertion) and **fittings** (cosmetic
parts chosen from the Chronicle seed). It is never an item with stats and
never swapped.

Frames: **Edge**, **Reach**, **Vessel** in the slice. **Array** after the
slice. "Singular" is not a player frame: it is the label for bespoke boss
Instruments (D-014).

### The Lintel (Threshold, Reach frame)

A surveyor's stave as tall as its bearer, with a folding crossbar at the
head. It looks like half a doorframe carried on the shoulder.

| Form | Appearance | Function |
|---|---|---|
| Dormant | Crossbar folded, brass rule markings along the haft | Planted to anchor one end of a line. While planted you fight with the short half: faster, shorter reach |
| Awakened | Crossbar open; the stave stands on its own when released | The line no longer needs you beside it. The standing stave is a second strike origin |
| Transcendent | The crossbar is carried on the shoulders; there is no stave | You are the threshold (Paradox: the line moves with you) |

Verb: **plant**. Moveset: long thrusts, a sweeping crossbar hook that pulls a
target toward the line, a vault. Idle: the bearer leans on it as on a
doorpost. Movement language: measured, pivoting, always squaring up.

### The Tally (Debt, Vessel frame)

A heavy reliquary gauntlet on the off hand and a cord of counting-beads
wound up the forearm. Beads slide and lock as debt is recorded.

| Form | Appearance | Function |
|---|---|---|
| Dormant | Dull beads, closed fist | Guarding with the gauntlet records harm at full value. Beads show what is owed, by whom |
| Awakened | The cord unwinds and trails; beads glow in the debtor's colour | The cord can be thrown to mark a debtor at range; call-ins travel along it |
| Transcendent | The beads are gone; the cord is tied to the bearer's own wrist | Paradox: a debt forgiven binds harder than a debt collected |

Verb: **catch**. Moveset: short hooks, a body check, a rising palm heavy,
a catching guard. Idle: thumb counting beads. Movement language: forward,
weight low, takes ground by taking hits.

### The Counterpart (Reflection, Edge frame)

A single-edged blade carried with a second, empty hilt at the hip. The
flat of the blade is polished and shows what is behind the bearer.

| Form | Appearance | Function |
|---|---|---|
| Dormant | One blade, one empty hilt | The polished flat is the eye of the law: twins are marked by being caught in it |
| Awakened | The empty hilt carries a blade seen only as a reversed image | Mirrored strikes are visibly struck by the second blade from the far side |
| Transcendent | Neither blade is the original | Paradox: the reflection was never the copy. You and your image may change places |

Verb: **show**. Moveset: fast paired cuts, a turning draw cut, a reversed
grip parry. Idle: checking the flat like a mirror. Movement language:
symmetrical, turning, never the same side twice.

### Animation budget per frame

Idle, locomotion overlay, 4 lights, 2 heavies, 1 charged, 3 directionals,
dodge attack, guard, parry, impose, inscribe, hit reactions (3), unveil.
About 18 authored clips per frame, 54 for the slice, on a shared humanoid
rig. Greybox uses retargeted CC0 and Mixamo clips; bespoke animation replaces
them only once feel is locked.

## Aurel Voss, the Last Arbiter

**Root:** Permission. **Doctrine:** Custody. **Instrument:** the Imprimatur,
a long-hafted seal-press (a Singular). Its head is a seal matrix; where it
lands it leaves a Writ stamped into the floor.

**Who he is.** The last Arbiter who believes the Canon is true and that
licensing Sovereigns is mercy. He does not want you dead. He wants you
recognised, recorded and bound, because the alternative he has seen is
worse. He is courteous, tired, and explains every rule before he enforces
it. The fight is a hearing and he conducts it as one.

**Silhouette:** tall, narrow, a judicial stole to the floor, the Imprimatur
held upright like a staff of office. No armour.

| Law | Tier | What it says | Status |
|---|---|---|---|
| Writ of Standing | Technique | No one may strike the Arbiter unseen. From behind, by hand: denied, sanction 8 | Tested |
| Writ of Order | Technique | None may strike thrice unanswered. Third in a string: denied, sanction 6 | Tested |
| Writ of Licence | Technique | No law without licence. Unrecognised: imposition denied. A perfect parry earns recognition for 10 s | Tested |
| The Hearing | Edict | For the next nine acts by hand, no one may repeat their own last act. Binds him too | Tested |

**Phases** (built as data in `game/data/enemies/voss.json`; tested headless):

1. *Arraignment.* One Writ at a time, each stamped with a spoken line so it
   can be read. Slow, heavy, generous windows. Teaches that Writs exist.
2. *Cross-examination.* Two Writs stand together. He begins to bait the acts
   his own Writs forbid: turning his back, leaving a third hit open.
3. *The Hearing.* He speaks his Edict. Because it binds him, his own pattern
   becomes a strict alternation that a reading player can predict and
   punish. The phase rewards the player who noticed that.

**Hidden answers:** his seal marks on the floor are constructs and can be
bound as a twin (built; it is one of the six tested lines); the Imprimatur,
once stamped, is briefly planted and can be cut off behind a Divide (not
built); a Creditor can provoke sanctions on purpose (possible, not tested).

**Ending the fight.** He yields at low health (8%); he is not killed. The
player then accepts his licence (Court line) or refuses it (Crownless line).
Both continue the story. Built: the yield, the offer and the answer. The
answer is recorded and nothing reads it yet.

**Variants** (designed only): rematch with all three Writs standing; mastery challenge under
a Vow; extreme variant in which he carries a Warrant.

## Other characters in the slice

| Name | Role | Law | Purpose |
|---|---|---|---|
| Maren Thole, "the Unpaid" | Crownless cell leader in the Assize Quarter | Debt, a Debtor carrying a mortal wound deferred for eleven years | Faction line. Shows the player what their own Root costs if they awaken to Debt, and what a default is |
| Tove Hallam | Copyist, Pale Archive | None | Found a line struck from the Canon. Gives the personal discovery quest |
| Ysolde Karr | Senior Bailiff of the Court | Warrant | Recurring elite; the first enemy who contests the player's law |

## Later Sovereigns (direction only)

* **Nyxara, the Unremembered.** Memory, a struck Root. The arena replays
  what happened in it earlier in the fight. The answer is knowing which blows
  are now and which are then.
* **The Zero Witness.** Absence, a struck Root. Removes relationships from
  the fight: lock-on, debts, bonds, lines. The answer is finding which still
  hold. Its name is deliberately the protagonist's trade.
