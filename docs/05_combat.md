# 05. Combat design

Status: **M1 parts implemented and tested headless** (movement, light and
heavy strings, dodge, guard, perfect parry, hit-stop, lock-on, the verdict
line, a Bailiff). Not implemented: directional lights, charged heavy,
plunge, every Axiom input, every enemy but the Bailiff.

The frame numbers that are actually running live in
`game/data/instruments/placeholder_edge.json`, not here. They differ from the
table below because they were fitted to the placeholder animation clips
(light startup is 9 to 12 ticks, heavy 16 to 18). Nothing has been tuned by
hand yet. When it has, this table is updated to match the data.

## Goals

Fast, readable, and impossible to play as a row of cooldown buttons. There
are no cooldowns in VOWFALL. Laws are limited by Resonance, by their own
conditions, and by what the opponent's laws allow.

## Simulation

* Fixed 60 Hz tick. All frame data below is in ticks.
* Input buffer 10 ticks. Input to first animation frame at most 3 ticks.
* The character controller decides *what was attempted*. The Law Engine
  decides *what happened*. The controller proposes `STRIKE`, `MOVE` and
  `IMPOSE` events with tags and reacts to the record.

## Resources

| Resource | Range | Gained | Spent |
|---|---|---|---|
| Health | 100 base | Flask (3 charges per rest) | |
| Poise | 60 base | Recovers after 2 s without being hit | Emptied: staggered for 60 ticks |
| Resonance | 0 to 100 | Light hit +4, heavy +9, perfect dodge +12, perfect parry +18 | Imposing laws, inscribed strikes, committing to contests |

No stamina. Stamina slows a fast game and adds a bar that is not about laws.
Evasion is limited instead: a third dodge in a row is slow and has no
invulnerability.

## Actions

| Action | Startup | Active | Recovery | Notes |
|---|---|---|---|---|
| Light | 8 | 3 | 14 | Cancels into light, heavy, dodge or impose from tick 12 on hit |
| Heavy | 16 | 4 | 22 | Poise damage x2. Hold to charge (+18 startup, breaks guard) |
| Directional light | 9 to 11 | 3 | 16 | Forward lunge, side cut, retreating cut |
| Dodge | | | 24 total | Invulnerable ticks 3 to 14. Perfect if a strike would have landed in ticks 3 to 8 |
| Guard | 2 | held | 6 | Takes 30% as chip and full poise damage |
| Perfect parry | | first 6 ticks of guard | | No harm, attacker loses 30 poise. Tags the strike `perfect_parry` |
| Plunge | | | | From any drop over 2 m |

Strings are per Instrument frame (`06_characters_instruments.md`). Each
strike in a string carries an `act` name (light, heavy, thrust, sweep,
plunge) and its `combo_index`. The Law Engine reads both: Voss's Writ of
Order denies a third strike in a string, and The Hearing denies a repeated
act. Combat variety is therefore something enemies can make laws about.

Launchers and air combos are not in the slice. They need airborne states and
animations on every enemy. Revisit after the slice is fun.

## How a law enters a fight

Four inputs, all woven into the weapon.

1. **Impose** (Axiom button). Establishes your Assertion. For a line: the
   Instrument plants where you stand, you move, release to draw. For a pair:
   the next two things you strike are bound. Costs the law's Price.
2. **Commit** (keep holding Impose). Adds up to 10 more Resonance to the
   law's authority. The reason to hold is an enemy who can contest you.
3. **Inscribe** (Axiom + attack inside a string). The strike carries a tag
   your law reads: the Creditor's "call in" is an inscribed strike. 5
   Resonance.
4. **Counter** (perfect parry while your law stands). Some laws have a
   clause that fires on it: the Answer returns the blow.

### As built in M2 (D-019)

One button (Q, left trigger) does all four, by how it is used.

| Use | What happens |
|---|---|
| Tap | A line law is laid 1.4 m ahead, square to your facing, just under 6 m wide: "bar the way". A self law is imposed. A pair law binds your locked target (or whoever you are facing) and whoever stands nearest to them |
| Hold and walk, release | A line law is drawn from where you pressed to 40 cm short of where you stand. You walk at 45% speed while drawing. Being hit or dodging loses the drawing |
| Hold, release | Every 6 ticks held commits 1 more Resonance, up to 10, into the law's authority |
| Hold while pressing a strike | The strike is inscribed, if your standing law has an inscription and you can pay 5. The hold is then spent and imposes nothing |
| Perfect parry | A law with a counter clause fires |

A press made while you are mid-action is kept: a hold starts imposing the
moment you are free, a tap is honoured within 12 ticks.

Two body rules came out of testing with scripted play:

* **A lunge never carries you over your own line.** Stepping over it ends
  it, as designed, but a strike's forward movement stops at the line.
  Otherwise the Gatekeeper broke itself on the first follow-up.
* **Armoured strikes (D-018).** A Bailiff's swing is not stopped by a blow
  that leaves his poise standing. He takes the harm and the swing lands.
  The player's is. This is what stops a mashed light string from being the
  answer to everything.

## The verdict line

Whenever the engine writes REJECTION, OVERRIDE, CONTEST, CANCELLATION or
CONVERSION, the player sees, at the point of contact, a glyph for the
outcome and the law's reason in a few words ("did not see it struck"), for
about 0.8 s. The full sentence goes to the Codex log. Each outcome has its
own hit reaction:

| Outcome | What the player feels |
|---|---|
| REJECTION of your strike | The weapon stops dead. 18 ticks of recoil. If sanctioned, you take the sanction |
| REJECTION of theirs | Their weapon stops at your line; they recoil |
| OVERRIDE | The losing law's effect flickers and holds |
| CONTEST | 6 ticks of hit-stop; the broken law shatters visibly |
| CANCELLATION | Both effects snuff out together |
| CONVERSION | The blow visibly becomes something else: a bead on the Tally, a mirrored strike |

The verdict line always gives the reason for *this* event ("it was struck a
third time unanswered"), because that is what just happened to the player
(D-017). What is earned is the law itself: above an enemy, a law not yet met
is a struck-out bar, a law sensed shows its name, and a law seen three times
shows its sentence. Its clauses and answers appear in the Codex at the same
point.

## Enemies

Health is low. Rank-and-file enemies fall in three to six hits. Difficulty
comes from what they carry.

| Enemy | Carries | Pressures |
|---|---|---|
| Court Bailiff | Warrant: two acts that no broader law may deny | Threshold players who stand behind a line |
| Bailiff and Ward | Escort: the pair may pass, unless contested | Teaches Commit |
| Process-server | Fast, flanks, strikes from behind | Creditor (unwitnessed harm is not owed) |
| Clerk swarm | Many weak hits | Debtor (default), feeds Creditor |
| Notary | Ranged seal that marks a spot; standing in it reveals your law's remaining term to all enemies | Anyone relying on a law nearly spent |
| Oathbound duellist | A Vow of its own: "I will not strike first" | Players who only counter |

Status: Warrant and Escort exist as tested laws. No enemy AI exists.

## Boss: Aurel Voss

Full design in `06_characters_instruments.md`. His laws are implemented and
the three Axiom families are shown by test to meet them differently:

* **Reflection:** his Writs bind hands. A mirrored strike is not a hand. The
  Answer hits him from behind while you stand in front of him.
* **Debt:** his sanctions are harm, and every harm is a loan. The Creditor
  gets rich on being punished. The Debtor is squeezed: Writ of Order limits
  the strikes they need to pay with.
* **Threshold:** a line stops his blows but not his Writs, and the Writ of
  Licence stops the line being drawn at all until he has recognised you.

## Difficulty

One tuned difficulty, plus Vows. No health multipliers.

## Feel targets (to verify in M1)

* Hit-stop 4 ticks light, 7 heavy.
* Camera never loses the locked target; shake is capped and can be turned off.
* A new player lands a three-hit string and a dodge inside the first minute.
* A denied strike never feels like a dropped input: the recoil is distinct
  and the verdict line always shows.
