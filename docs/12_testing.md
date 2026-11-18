# 12. Testing strategy

## What exists and runs today

```bash
./tools/test.sh                    # everything; exit code 0 only if all pass
./tools/test.sh -- --verbose       # list every check

G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path game --import                                   # after adding a class_name or an asset
$G --headless --path game --script res://tests/run_tests.gd          # Law Engine only
$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM1.tscn   # action machine and arena
$G --headless --path game --script res://tests/bench.gd
```

$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM2.tscn   # Axioms in play
$G --headless --fixed-fps 60 --path game res://scenes/tools/CaptureM2.tscn -- /tmp/x   # dry run of the capture script

$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM3.tscn   # Instruments and Unveiling
$G --headless --path game --script res://tools/measure_clips.gd -- 2H_Melee   # when does a clip connect?

$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM4.tscn   # Aurel Voss; rewrites docs/m4_logs/
$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM4.tscn -- --rules   # or --lines

$G --headless --fixed-fps 60 --path game res://scenes/tools/TestM5.tscn   # the Assize Quarter
$G --headless --path game res://scenes/tools/MapQuarter.tscn -- /abs/out.svg   # a plan of it, from the build

No window opens. Last run, 2026-11-13: **502 passed, 0 failed** (90 Law
Engine, 82 M1, 91 M2, 54 M3, 50 M4, 135 M5). The Law Engine's 90 include
12 Vow scenarios and 8 Vows the validator must refuse or accept.

### M5 checks (`tests/test_m5.gd`)

| Group | Checks | What it proves |
|---|---|---|
| The Quarter as built | 10 | Four areas where the map says; every model exists; all stone is one mesh; every stone, keeper and record stands on the floor it claims (ray cast); nine keepers asleep at five posts; nobody falls through |
| Two routes, walked | 27 | A scripted stick walks the real player up the Stair into the Hall, and down through the Docket and out by its gate, checking height at each stage and that the gate is a wall from the landing, opens from behind, and stays open |
| Vows | 30 | The stone's menu (open, step away, walk off, choose); one Vow at a time; kept when a post is cleared or Voss yields (Resonance whole, standing 2, authority 22 on the next law, forgotten at rest); **a roused Bailiff really striking the Witness's back makes The Watched Back fall**, with the forfeit, and striking their front does not; a Vow survives a rest and ends unkept and unpunished with its author |
| Vow-stones | 18 | The yard's rest and Unveil keys are off; E opens the stone's choices; a stone restores, sets where the Witness stands again, and returns a downed keeper as a new one; no rest while roused; falling and leaving the world both return to the stone |
| Posts | 9 | A roused Bailiff leaves his post (live AI), gives up beyond his leash, walks back and faces his watch; a struck sleeper wakes; a cleared post stays cleared |
| The Hall | 20 | Voss silent until the Witness is in; the bar drops and holds; he yields; the bar lifts; the choice works; resting does not put him back; falling in the Hall resets it |
| Records | 9 | Eight, each with text; two contradict; open, close, walk away; each can be reached from in front |
| Presentation, headless | 10 | Prompt, record leaf, help text, the gate's refusal, the stone's choices, the sworn line, the kept banner, all drawn without error |
| Cost | 1 | The whole Quarter with eight keepers awake: under 0.6 ms a tick headless |

Walking a route in a test is the nearest thing to a playtest a headless
run can do: it finds a missing floor, a wall across a doorway, a keeper
standing where the path goes. It says nothing about whether the place is
worth walking through. The whole run takes several minutes;
most of it is M4's six fights.

### M4 checks (`tests/test_m4.gd`)

| Group | Checks | What it proves |
|---|---|---|
| The rules of the fight | 37 | The encounter, his health and yield point; a Writ he has spoken can be read before it is ever enforced, and none is struck out on his panel; the three phases at their thresholds and how many Writs stand in each; each rule spoken; under The Hearing he attacks freely and never repeats himself, and speaks it again when it is spent; seals (where, how many, how long, cleared when broken); the yield, the offer, both answers, the log; the HUD draws all of it |
| Six lines | 13 | Each of six policies makes him yield; each line's log is made of the outcome its law exists for (denials, strikes from the threshold, conversions, debts paid forward, blows returned, harm copied); all six pass through all three phases |

The six lines are run once each from one start. They are a demonstration
that six routes exist, not a search for a broken one.

### M3 checks (`tests/test_m3.gd`)

| Group | Checks | What it proves |
|---|---|---|
| Three bodies (pure) | 10 | Reach, speed and weight order the three Instruments; the short half is shorter and quicker; each awakened moveset has its new move and the route into it |
| The Instrument follows the Root | 8 | Lintel, Tally, Counterpart by law; never changed mid-swing; from 4.4 m the Lintel reaches a post and the Counterpart does not |
| Verbs | 12 | Plant: the short half in hand, the stave at the line's middle, whole again when the line ends. Catch: 15% through, all of it owed. Show: one cut shown to two binds them |
| Recognition and Unveiling | 21 | Trials count the right clause of the right law and survive save and load; no rite without recognition; the rite takes time, guards nothing and is broken by a blow; Unveiled, the Bailiff is thrown down unharmed, Resonance is whole, the next line is the Unveiled Gatekeeper, and the Counterpart walks four cuts |
| Presentation, headless | 3 | The planted stave is placed, the Unveiling announced, the law panel draws through all of it |
`tools/test.sh` also fails if any script error was printed, because an error
inside a draw call or a signal handler does not fail a check on its own.

### M1 checks (`tests/test_m1.gd`)

The real arena scene is loaded headless and the player is driven by
`ScriptedInput`, a tick-by-tick timeline that replaces the keyboard. The
Bailiff is either driven the same way or left to its AI.

| Group | Checks | What it proves |
|---|---|---|
| Action machine (pure) | 21 | Active ticks, whiff and hit cancel windows, the ten-tick buffer, hit-stop, the string order, dodge invulnerability and the slow third dodge, the six-tick parry and its lockout, interruption |
| Movement and the bridge | 11 | Run speed, camera-relative steering, position sync to the centimetre, lock-on, and a Gatekeeper line that refuses a step once per attempt |
| Striking | 17 | A three-hit string and its Resonance; the sealed post's Writ of Order denying the third strike and Writ of Standing denying a strike from behind, each with its sanction and its verdict |
| Defence | 15 | An unanswered hit, guard chip, perfect parry (tagged for the Law Engine), perfect dodge |
| Life and death | 7 | The Bailiff dies in six strikes and is cleared; the player falls and stands again |
| The Bailiff's AI | 5 | First strike inside seven seconds, steady pressure, a minute of random play with every actor in bounds and sane |
| HUD, headless | 6 | The verdict line receives the denial with its law, reason and sanction; the draw code runs every frame without error |

What these cannot prove: anything about how it looks or feels.

### M2 checks (`tests/test_m2.gd`)

Every law is imposed and used the way a player would: `ScriptedInput` holds
and releases the Axiom button, the `Player` builds the arguments, the bridge
asks the engine.

| Group | Checks | What it proves |
|---|---|---|
| Impose, commit, draw | 21 | A tap bars the way; holding commits Resonance into authority; walking with the button held draws the line and stops short of the feet; no Resonance, no law; the Unveiled form is used when set |
| Threshold in play | 10 | A Bailiff's strike is denied and he recoils; the player strikes out across their own line; three denials spend it; the Divide refuses its author too |
| Debt in play | 17 | Loans recorded and called in by an inscribed strike, with the cost; a Debtor struck is unharmed, pays forward by striking, and suffers the rest eight seconds later |
| Reflection in play | 10 | The Twin binds target and nearest; the Ward takes six for the Bailiff's ten; a strike is mirrored; a perfect parry returns the whole blow |
| Court laws | 12 | A Warrant is drawn only once the player has a law, and passes the line (OVERRIDE); an Escort and a plain line cancel (CANCELLATION); a committed line breaks the Escort (CONTEST) |
| Opponents | 5 | Four Clerks land many small hits, take turns, fill a Creditor's ledger |
| Presentation, headless | 7 | Preview, standing line, ring and beads are created and removed; the HUD's new panels draw without error; changing opponents while locked on does not crash |
| One fight, three ways | 6 | Three scripted policies beat the same Bailiff by denials, by debt, and by reflection; the logs differ in kind and in cost |

The dry run of the capture script found a real crash (changing opponents
while locked on one) before any window was opened. Running presentation
code headless is worth doing even though nothing is drawn.

| Group | Checks | What it proves |
|---|---|---|
| Loading | 3 | Roots and laws parse; there are eighteen Roots |
| Shipped laws valid | 1 (17 forms) | Every law, in every form, passes the validator and its budget |
| Invalid laws refused | 19 | Each kind of impossible power is rejected with the right code |
| Scenarios | 40 | What every law does, how it is answered, how laws meet |
| Determinism | 1 (40 replays) | Same inputs, same state hash |
| Save and load | 1 (40 replays) | A JSON round trip between every step changes nothing |
| Engine guards | 3 | A law that slipped past the validator still cannot loop forever |

The suite was checked against itself: a scenario with a deliberately wrong
expectation fails and returns exit code 1.

### Coverage against the Directive's list

| Required | State |
|---|---|
| Axiom validity | Covered |
| Invalid ability combinations | Covered (19 cases) |
| Resource consumption | Covered (price paid, price refused, commit, nothing spent on rejection) |
| Interaction resolution | Covered (all five outcomes, cross-Root cases) |
| Transformation state changes | Covered for rules (five Unveiled forms). No presentation to test |
| Save and load | Covered for the Law Engine. No save files yet |
| Enemy behaviour | Covered for the Bailiff: pressure, bounds, sanity. No bot matches yet |
| Combat edge cases | Covered: cancel windows, buffered inputs, parry and dodge edges, interruption, death mid-string. Not yet: two strikes on one tick, a kill during hit-stop |

## How scenarios are written

A scenario is JSON: a cast, steps, and what each step must produce.

```json
{"do": "strike", "source": 2, "target": 1, "amount": 10,
 "expect": {"verdict": "REJECTED",
            "outcomes": [{"type": "REJECTION", "law": "threshold.gatekeeper"}]}}
```

Scenarios are the specification. A port of the engine to another language is
correct when these files pass. Rule: **no law is merged without one scenario
for what it does and one for how it is answered.**

## What comes next, by milestone

**M1, combat.** Built (above). Still to add: parry at the first and at the
last perfect tick through the real scene, two strikes landing on the same
tick, and a replay-determinism check for the arena (same seed and inputs,
same Law Engine hash).

**M2, Axioms in play.** Built (above). Still to add: the Debtor's default
in the live scene; a drawn Divide; a replay-determinism check.

**M4, boss.** Built (above) as six single matches. Still to add, as first
written: bot matches in bulk. A simple policy per Axiom (for example "Creditor:
provoke sanctions, then call in") plays Voss a few hundred times from seeds.
Assertions: every Axiom can win; none wins more than a set share with a
single repeated act; no fight exceeds a time limit; no state hash differs
between two runs of the same seed. This is the test that finds degenerate
strategies before players do.

**M5, the Quarter.** Built (above). Still to add: a route walked with
every keeper's AI live; a Gatekeeper line drawn on the landing checked
against the Docket below (the layout says they cannot meet; no test says
so); a Vow kept and a Vow broken by a scripted player fighting with real
input, not by harm dealt from the test.

**M6, Chronicle.** Save file round trips across versions; Codex persistence;
awakening determinism (same seed and inputs, same three candidates).

**Every milestone.** The benchmark, compared with the last number. A
contact sheet of screenshots for anything visual, reviewed before anyone
claims it looks right (headless Godot renders nothing, so visual checks need
a window: ask first).

## Edge cases already known and not yet tested

* A law imposed while its owner is mid-air (scopes are 2D).
* Three or more laws in one conflict (the settle loop handles pairs in
  order; no scenario has three).
* Two TAKE clauses from opposing teams on one event.
* A pair in which one member is the law's owner.
* A debt whose original attacker has died before it comes due (works by
  inspection; no scenario).
* A tag expiring on the same tick a law checks it.
* Unveiling while a Dormant-form law is standing.

Each becomes a scenario before the feature that would expose it ships.
