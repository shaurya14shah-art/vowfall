# 03. Axiom system specification

Supersedes "The Definitive Axiom System v1.0" where they differ. The data
described here exists in `game/data/` and is validated on every test run.

## 1. The hierarchy

```
ROOT  ->  THESIS  ->  ASSERTION  ->  EXPRESSIONS  ->  EDICT
(concept) (belief)    (the law)      (how you use it)  (your highest law)
```

Condition, Price, Scope, Term and Counterplay are fields of the Assertion.
Instrument and Doctrine are how a particular person carries it.

## 2. The Roots: the Canon Twelve and the Struck Six

Every Root governs exactly one thing in the Law Engine. That is the test for
whether two Roots are really different.

| Family (its question) | Canon pair | Struck third |
|---|---|---|
| Existence: what is a thing? | **Reflection** (correspondence), **Identity** (what a thing counts as) | Absence (whether it can be acted on at all) |
| Relation: what lies between things? | **Debt** (the ledger), **Threshold** (boundaries) | Ownership (whose a thing, an act or a law is) |
| Change: what becomes of a thing? | **Ruin** (integrity), **Continuity** (states that refuse to end) | Adaptation (what it has met before changes how it meets it) |
| Perception: what is known? | **Silence** (whether an act is noticed), **Revelation** (what is read cannot be denied) | Memory (what happened, replayed against the present) |
| Motion: where is it going? | **Gravity** (pull), **Velocity** (momentum kept and spent) | Distance (how far apart two things are treated as being) |
| Potential: what may it do? | **Hunger** (appetite), **Permission** (which acts may complete) | Possibility (what else could have happened) |

The Meridian Court teaches each family as a balanced pair. The third Root of
each family is the one that makes the pair disagree, and each was struck
from the Canon. A player cannot awaken with a struck Root until their Codex
holds the discovery that it exists. Bosses can carry them from the start.

Slice Roots: Threshold, Debt, Reflection (player) and Permission (boss).
Machine-readable list with each Root's permitted operations:
`game/data/roots.json`.

## 3. The grammar

An Assertion is a law definition. A law is a set of **clauses**, each a
sentence of this form:

```
ON     <which events>            STRIKE, HARM, HEAL, MOVE, IMPOSE
AT     <which stage>             NOTICE, DENY, REDIRECT, MODIFY, HOLD, REACT
WHERE  <who, what, which path>   source/target relation and tags, event tags,
                                 path crosses scope, in pair, data, held debt
DO     <operation>               one of nine
BECAUSE <reason>                 a plain sentence the Codex can show
```

and the law as a whole declares:

```
ROOT, THESIS, TIER      FUNDAMENTAL, TECHNIQUE, MANIFESTATION, EDICT
SCOPE                   SELF, TARGET, PAIR, LINE, RING, ZONE, FIELD
TERM                    ticks, and optionally a number of acts
PRICE                   Resonance
CONDITION               what must hold to impose it
BREACH                  what ends it early
COUNTERPLAY             at least two named answers
```

### The nine operations

| Operation | Meaning | In the slice |
|---|---|---|
| ALTER | Change an amount or a tag | Gatekeeper's gate strike, Creditor's garnish, Voss's recognition |
| TRANSFER | Move a quantity: copy to a twin, mirror, debt into a strike, debt onto a target | Twin, Answer, Creditor, Debtor |
| BIND | Establish a relationship (a pair) | Twin |
| DIVIDE | Sever what spans a boundary, for both sides | The Divide |
| PRESERVE | Guarantee an act proceeds | Warrant, Escort |
| REVEAL | Make a law known | The Hearing |
| INVERT | Swap who does and who receives | The Answer's return |
| **DEFER** | Hold a consequence and release it later | Creditor, Debtor |
| **DENY** | Refuse an act | Gatekeeper, every Writ |

DEFER and DENY are additions to the original seven (D-005). Time-shifting and
forbidding are primitives; expressing them through the other seven needed
contortions that hid what a law did.

### Hands and laws (D-013)

Every event is tagged `by_hand` (a person did it) or `by_law` (a law did it:
a copy, a mirror image, a debt coming due, a sanction). Laws say which they
judge. Voss's Writs bind hands. A reflection is not a hand. This one
distinction produces most of the slice's cross-Axiom counterplay, and nothing
about it is special-cased.

## 4. What the validator refuses

`LawValidator` (in `game/core/law/`) rejects a definition for any of these.
Each has a failing example in `game/tests/invalid_laws.json`.

| Code | Rule |
|---|---|
| E_SHAPE | Missing fields, unknown operation, a clause with no stated reason |
| E_ROOT_OP | A Root using an operation it does not own |
| E_STAGE_OP | An operation at a stage where it cannot act |
| E_TERM | No end, or longer than its tier allows |
| E_PRICE | Free, and not a Fundamental |
| E_COUNTERPLAY | Fewer than two named answers |
| E_TOTAL_LOCK | A field or zone that forbids an event with no narrowing at all |
| E_IMMORTAL | Refusing or deferring harm to yourself without a limit and a default |
| E_DEFER_RELEASE | A deferred consequence with no day it ends |
| E_LOOP | A law that can act on its own output |
| E_EDICT_EXEMPT | An Edict that exempts its author |
| E_DIVIDE_SIDED | A Divide that takes a side |
| E_BUDGET | Power (scope + term + operations, less each narrowing) above allowance (tier + price + breaches) |

The budget is a lint. It catches "broad, long and cheap at once". It does not
replace playtests.

## 5. The six slice Assertions

All six are implemented as data and covered by tests. Numbers are first-pass.

### Threshold (Instrument: the Lintel)

**The Gatekeeper.** *Nothing may cross without permission.*
Draw a line up to 6 m. Hostile strikes and steps that cross it are denied.
Three denials or 8 s. Price 30. Ends if you cross it yourself.
Answers: go around; spend its denials on feints; bait the owner across.
Unveiled: four denials, you may cross freely, and your own strikes through
the line deal 130%.

**The Divide.** *Every boundary creates two sides.*
Draw a line up to 9 m. Nothing passes between the sides: strikes, steps,
healing, laws, yours included. Bonds that span it are cut off while it
stands. 6 s. Price 35.
Answers: go around; outlast it; get on the same side as the owner.
Unveiled: the line closes into a 4.5 m ring around where you stood.

### Debt (Instrument: the Tally)

**The Creditor.** *Every harm is a loan.*
For 15 s, harm you take from an enemy you are facing is recorded against
them. A strike inscribed "call in" adds everything they owe to itself.
Price 20. Blows from behind are not witnessed.
Answers: strike from behind; do not strike at all; outlast it.
Unveiled: anyone who owes you strikes you for 75%.

**The Debtor.** *What I owe, I choose when to pay.*
For 15 s, harm you take is not suffered: it is owed and comes due in 8 s at
125%. Each strike you land pays that much of it forward onto the target.
Owe more than 60 and you default: all of it, at 150%, now. Price 25.
Answers: force a default with burst; stay away and let it come due; deny
their strikes so they cannot pay.
Unveiled: what you pay forward lands at 125%.

### Reflection (Instrument: the Counterpart)

**The Twin.** *What is done to one is done to its twin.*
Bind two who stand within 9 m. Harm or healing done to one is done to the
other at 60%. Six echoes or 12 s. Breaks if they are parted by 15 m.
Price 30.
Answers: separate them; spend the echoes; heal one twin to heal both.
Unveiled: 100%, and distance no longer breaks it.

**The Answer.** *Every act has its reflection.*
Each strike you land by hand is struck again from the opposite side at 50%.
A perfect parry returns the blow to its author. Six answers or 10 s.
Price 25.
Answers: spend the answers; guard both sides; feint to draw the parry.
Unveiled: designed, not implemented (a placed mirror line; your strikes
repeat across it at range).

## 6. Awakening

Three inputs, as in the original: **choices** (the prologue's dilemmas),
**behaviour** (how the prologue's fights were played) and **history** (what
the Chronicle's seed and earlier Chronicles put in your path).

```
resonance(root) = 3 * choices(root) + 2 * behaviour(root) + 1 * history(root)
```

* Three candidates are offered: the highest Root's best-fitting Assertion,
  the second Root's, and one from the Root the player most acted *against*
  (the "shadow" candidate).
* Ties are broken by the Chronicle seed. Nothing is rolled in secret.
* **Each candidate shows its evidence**: the two or three moments that
  earned it, in the player's own actions ("You held the door while the others
  ran").
* The two not chosen are kept in the Codex as paths not taken.
* From the second Chronicle on, the player may instead choose any Root the
  Codex has recorded ("a remembered awakening").

Behaviour is read from mechanical dilemmas, not from morality. Example: a
collapsing oath-hall. Hold the door for the crowd (Threshold), take the blow
meant for the clerk (Debt), or follow the guide's exact path through the
falling stone (Reflection). All three get you out.

Status: designed. Not implemented.

## 7. Doctrine

Each Doctrine trains one property of the engine. A tenet is applied per
Expression slot, so a character can mix.

| Doctrine | Property | Effect of a tenet | Cost of a tenet |
|---|---|---|---|
| Dominion | Authority | +3 authority in contests | Price +20% |
| Custody | Persistence | Term +25%; one breach condition removed | Cannot be re-imposed while standing |
| Guile | Trigger | The law may be imposed latent and fire on a chosen event | Authority -3 |
| Convergence | Chain | When your law's consequence triggers another of your clauses, refund 5 Resonance | Repeating the same Expression twice in a row refunds nothing |

Status: designed. Authority and term exist in the engine; tenets are not
implemented.

## 8. Vows (D-010, D-032)

Status: **built and tested** in the engine and in the Quarter (2026-11-13).
Unseen and unplayed.

A Vow is not an Axiom. Anyone in Veyr can swear one, because Veyr's standing
law is that a vow spoken before a witness binds. In the engine a Vow is an
ordinary law of a tier of its own, `VOW`, with its author as its only
subject. Its Root is Ownership, the struck Root that leaks in Veyr: the one
thing everyone there owns is their word.

| A Vow | How |
|---|---|
| Grants nothing while it stands | It has no clauses. The validator refuses one that has |
| Costs nothing to swear | Its price is its **forfeit**: harm paid on the spot when it falls |
| Has no term in time | It stands until it is **kept** or it **falls**. It ends, unkept and unpunished, with its author |
| Falls when the named thing happens | A breach of type `EVENT`: an event that would stand, matched like a clause. An act another law denied never stood, and a blow that does no harm is no blow |
| Is kept when a post is cleared under it | The place tells the engine (`LawWorld.keep`) |
| Pays, when kept | Resonance made whole, and **standing** |

**Standing** is what a word weighs. It is added to the authority of every
law its holder imposes, so it decides contests between laws of equal rank
and reach: with 3 or more, a Gatekeeper's line breaks an Escort that would
otherwise have cancelled it. It is capped at 9, lost entirely when a Vow
falls, and forgotten at every rest. It is not a stat that grows: it is what
has just been shown, for as long as the Witness does not stop.

| Vow | Sentence | Falls when | Forfeit | Standing |
|---|---|---|---|---|
| The Watched Back | I will not be struck from behind. | Harm reaches me from behind | 15 | +2 |
| The Varied Hand | I will not make the same strike twice running. | I repeat my own last strike by hand | 20 | +3 |
| Bare Hands | I will impose no law. | I impose one | 20 | +3 |
| The Unmarked | I will not be struck from the front. | Harm reaches me from the front, even through a guard | 25 | +4 |

One Vow at a time in the slice. Stacking Vows is the Assize's challenge
mode and is not built.

What Vows already do with other laws, because they are laws (each is a
scenario in `tests/scenarios/vow.json`):

* Under Voss's Edict a repeated strike is **denied**, so it was never made,
  so The Varied Hand does not fall. The player pays his sanction, not the
  forfeit.
* A Debtor **defers** a blow from behind. It has not struck yet, so The
  Watched Back stands; and when the debt comes due it comes from no side.
* Under the Writ of Licence an unlicensed law is refused, so Bare Hands
  stands. So is any Vow one tries to swear in front of him.
* One swing that reaches two bodies is one strike (D-026), for a Vow as
  for the Edict.

## 9. Versioning

Every law definition carries a `version`. Saved laws store their id and form
and are re-resolved on load. A definition change that would alter a standing
law mid-save must bump the version; migration is a later problem and is
noted in `10_tech_architecture.md`.
