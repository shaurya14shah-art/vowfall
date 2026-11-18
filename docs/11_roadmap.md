# 11. Production roadmap

## An honest statement of scale

The game the Directive describes in full (six regions, eighteen Roots, five
factions, three Revelations each, a campaign) is the work of a large studio
over several years. One person with an AI collaborator cannot build it, and
planning as if they could is how projects die.

What one person *can* build is the slice, to a standard worth showing, and
the slice is designed to be a complete short game in its own right:
**VOWFALL: The First Severance.** Everything after it is conditional on the
slice being fun. The roadmap below therefore ends at the slice, with the
rest as direction.

The original estimate of 19 to 30 weeks assumed sequential full-time work
and no art. The estimates below are in **working sessions** (a focused block
with the AI collaborator) because that is the unit this project actually
moves in. They are estimates, not promises.

## Milestones

Each milestone ends with: tests passing, a benchmark number, `STATUS.md`
updated, remaining issues written down.

### M0. Law Engine core. DONE (2026-11-10)
Twelve laws as data, validator, 40 scenarios, determinism and save/load
checks, benchmark. Exit: 68 of 68 checks pass, headless.

### M1. A character worth controlling. BUILT, NOT YET PLAYED (2026-11-10)
Built and passing 82 headless checks: controller, camera, lock-on, strings,
dodge, guard, perfect parry, hit-stop, two posts, a Bailiff with AI,
`CombatBridge`, the verdict line. Not yet seen in a window or tuned by hand,
and its exit test is a person, so it is not closed. Remaining: a first look,
a frame-time measurement, feel tuning, a stranger at the controls.

Original scope, for reference: greybox arena. Third-person controller, camera, lock-on, light and heavy
strings, dodge, guard, perfect parry, hit-stop, one training dummy and one
Bailiff with simple AI. `CombatBridge` proposing real events. The verdict
line on screen.
Exit: acceptance criteria 1 and 2. A stranger can move and fight within a
minute and can say why a strike was denied.

### M2. Three Axioms in the arena. BUILT, NOT YET SEEN OR PLAYED (2026-11-11)
Built and passing 88 headless checks: impose (tap, draw, commit), inscribe
and counter through real input; all six Assertions in play; a Bailiff with a
Warrant, a Bailiff and Ward under an Escort, four Clerks; standing-law
effects; a verdict log; one fight played three ways by scripted policies
with the three logs in `docs/m2_logs/`. Not yet rendered, and no person has
played it. Remaining: a capture, then hands.

Original scope, for reference: impose, Commit, Inscribe and Counter inputs. All six Assertions playable
against Bailiffs, a Bailiff and Ward, and a Clerk swarm. Placeholder effects
that obey the edge rule.
Exit: criteria 3 and 5. The same encounter played three ways is three
different fights. Recorded as three verdict logs.

### M3. Instruments and Unveiling. BUILT, NOT YET SEEN OR PLAYED (2026-11-11)
Built and passing 54 headless checks: three Instruments bound to their
Roots, each a moveset and a verb (plant, catch, show); Recognition Trials;
the Unveiling as a held rite that changes the laws, the moves and the
model; awakened forms. The models are the game's own. Remaining: a capture,
then hands; and a real transformation sequence, which this is not yet.

Original scope, for reference:
Three movesets on a shared rig from retargeted clips. Instrument verbs
(plant, catch, show). Unveiling as a playable sequence that changes the kit.
Exit: criteria 4 and 7.

### M4. Aurel Voss. BUILT AND SEEN, NOT YET PLAYED (2026-11-13)
Built and passing 50 headless checks: three phases as data, an AI that
chooses only what his own Edict permits, seals, yielding and the licence
choice, a boss HUD, and six scripted fights (two per Root) with their logs.
Not built: the Hall of Standing (he is fought in the yard; moved to M5),
seeded bot matches in bulk, his own motion. Captured twice; the first
capture's three fixes are confirmed, two small HUD changes after the
second are not. Remaining: hands.

Original scope, for reference:
Three phases, AI that chooses among acts its own Writs permit, the Hall of
Standing, yield and choice. Automated bot matches for each Axiom.
Exit: criterion 6. Each Axiom has at least two distinct winning lines, shown
by logs.

### M5. The Assize Quarter. IN PROGRESS: session 1 of 6 to 10 (2026-11-13)
Built and passing 135 headless checks: the district as one connected place
(market, Stair, Docket, Hall), a one-way gate that closes the loop, three
vow-stones that rest and reset, keepers at posts with leashes, the Hall's
bar, eight records, twelve new models, a plan drawn from the build.
Captured twice; the first capture's five fixes are confirmed. Vows are
built (four, sworn at the stones, kept or fallen by the Law Engine) and
seen once. A first art pass is made (dressed stone, two set pieces,
written vows, a second light) and unseen. Still to do in M5: a look at
that pass and what it needs; people (Maren, Tove, Ysolde); pathfinding;
sound of place.

Original scope, for reference:
One interconnected district: oath-market, Scriveners' Stair, the Drowned
Docket, the Hall of Standing. Vow-stones. Environmental storytelling. First
production art pass in the Illuminated Law style.
Exit: criterion 9.

### M6. A Chronicle. 5 to 8 sessions
Prologue and awakening with evidence, the personal quest, the faction line,
save files and slots, the Codex persisting across Chronicles, the Assize
challenge.
Exit: criteria 8 and 10.

### M7. Showable. 5 to 8 sessions
Sound, music direction, UI pass, performance pass, five external players,
fixes from watching them.
Exit: criteria 11 and 12.

Total for the slice: roughly 33 to 52 sessions after M0.

## Order of risk

M1 is the milestone that decides whether there is a game. If moving and
striking do not feel good, nothing built on top matters. It comes first and
gets the most iteration. M2 decides whether the Law Engine is fun or merely
correct.

## After the slice (direction, not a plan)

1. Sovereignty and player Edicts. The second Revelation.
2. A second district and the first struck Root as a boss (Nyxara).
3. The remaining canon Roots, three at a time, each with its two Assertions.
4. Array frame.
5. Paradox.
6. Only then: a second Severance.

## Decisions waiting on the owner

See `STATUS.md`.

## Dependencies outside the code

| Need | For | State |
|---|---|---|
| Image generation credits | Reference pack | 0 credits |
| Humanoid rig and combat clips | M1, M3 | CC0 packs exist in Crownfall; Mixamo needs a manual download |
| Sound library | M7 | Kenney CC0 in Crownfall; nothing bespoke |
| Trademark search on the title | Any public release | Not started |
| Playtesters | M7 | Not arranged |
