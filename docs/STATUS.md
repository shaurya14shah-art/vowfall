# Status

Last updated 2026-11-13 (M5 in progress: the Quarter and its Vows captured; an art pass made since and **not yet seen in the game**). Status words: Designed, Prototyped,
Implemented, Tested, Polished, Complete. A design document existing does not
move a feature past Designed.

## In one paragraph

VOWFALL is a practice yard in which the Witness carries one of three
Instruments, each with its own body of moves and its own verb, and can earn
and perform the first Revelation. All six Assertions of the slice can be
imposed against four sets of opponents and one boss: Aurel Voss, who fights
in three phases under his own Writs, is bound by his own Edict, and yields
instead of dying. Those five encounters now also stand in a place: the
**Assize Quarter**, one connected district of four areas with vow-stones, a
shortcut gate, records to read and Voss in his Hall. Every model on screen
is the game's own. 502 headless checks pass. Every milestone has been
seen in a scripted capture. **Nobody has played any of it**, so everything
about feel is untested.

## M5: the Assize Quarter (first session, 2026-11-13)

Full description and plan: `docs/13_assize_quarter.md`. Press T in the yard
to go there, or run `res://scenes/Quarter.tscn`.

| What | As built | State |
|---|---|---|
| One connected district | Oath-Market, Scriveners' Stair (two flights, landing, forecourt), Drowned Docket, Hall of Standing. 12 m of height between the Docket and the Hall | **Tested**: a scripted player walks both routes end to end through the real collision |
| A loop | The Docket's far end climbs to a gate on the landing that opens only from the Docket's side, and stays open | **Tested** |
| Vow-stones (three) | E opens the stone's choices. Rest: whole again, stand here after falling, every keeper back at their post. Refused while a post is roused | **Tested**; seen in three captures |
| **Vows** (four) | Sworn at a stone, one at a time. A law of tier VOW: grants nothing, costs nothing, falls when the named thing happens (forfeit paid on the spot), kept when a post is cleared under it (Resonance whole; standing added to the authority of your laws until you rest) | **Tested** in the engine (12 scenarios) and in the Quarter, including a real blow from behind. Seen once (swearing; not yet a Vow kept or fallen). **Unplayed** |
| Keepers at posts | The five encounters of M2 to M4, each asleep at a post until approached or struck; a leash; they walk back; a cleared post stays cleared until rest | **Tested**, including one live fight for the leash |
| The Hall | Walking in rouses Voss and drops the Bar of Standing; it lifts when he yields or the Witness falls. Yielded, he is not put back by resting | **Tested** |
| Records (eight) | Read with E at a lectern or wall. Two contradict each other; two teach a counterplay | **Tested** for reach and text. The writing is unread by anyone but its author |
| HUD | An interact prompt, a record as a leaf of vellum, help text for the Quarter | Seen in two captures |
| Twelve new models | Vow-stone, lectern, stall, shelf, statue, struck plinth, rubble, lamp, banner, gate, the Witness Gate, desk | Reviewed in Blender renders and seen in the game twice |
| A plan of the district | Drawn by script from the real collision and data | `docs/assize_quarter_map.png` |
| Capture tool | `CaptureM5.tscn`, 22 moments, about 45 s, with frame timings in three places | Run three times in a window |

One bug the tests found: Voss opened his hearing at the first tick, with
the Witness a hundred metres away (D-031).

### Art pass (2026-11-13). Built; reviewed in Blender where it could be; **not seen in the game**

It answers the three things the captures left for the owner, and the
blockout's blankness. Nothing below has been drawn by the game yet. The
captures in `m5_first_look` to `m5_third_look` show the Quarter **before**
this pass.

| What | Before | Now | Checked how |
|---|---|---|---|
| The Hanging Courts | Six pale slabs in the sky | A model, 124 m across: four dark terraces with pale rims, sixty towers built downward from their bellies, a keel pointing at the Hall, the Court's mark in gold round it, seven chains ending in open links. 7,166 triangles | Blender render, from below. Not in the game |
| The fallen Oath Hall | Low blocks, a dark mass, a black slab | A model: the two ends of its front standing and stepped, its doorway with the lintel down across it (its gold band still on it), four column stumps and their drums lying toward the square, the roof in slabs behind, and the Court's black bar on two sealed bronze posts. 2,280 triangles. Stumps and drums are solid | Blender render. Not in the game |
| The hanging vows | Rows of gold dashes | Lines of script: words of upright strokes, some tall, some hanging below the line, all leaning. The fallen one is the same hand in vermilion, in three pieces | Code only. Not seen at all |
| Walls | Flat colour | Dressed stone from a shader, no textures: courses 1.6 m high, staggered joints, each block a shade off its neighbours, joints fading with distance | **Not compiled yet**: headless Godot compiles no shaders. If it is wrong the next capture will say so |
| Wall faces | Bare blocks | Every main face has a dark plinth, a cornice, and pilasters where nothing else stands | Code only |
| Shade | One flat grey-violet | A weak cool second light from the far side of the sky, casting no shadow, so shaded stone has a lit face and a turned one | Code only |
| The Hall's floor | Ruled lines | The Court's mark inlaid in gold, 24 m across | Code only |
| The city beyond | Boxes with dark lids | Each has a second storey set back | Code only |

Still a stylised place of flat colour. It should now look composed rather
than unfinished; whether it does is a question for the next capture. The
Hanging Courts still cast no shadow on the Quarter. They could: the sun
would put the north of the Hall in their shade, which may be exactly right
or may make the fight hard to read. Left for a look.

**Seen in the game twice** (`docs/screenshots/m5_first_look/`, 19 moments;
`m5_second_look/`, 20).
What worked:

* The district reads as a place. Tall blank walls throw long hard shadows
  across the square and the Stair; the pale stone holds its value in sun
  and goes to ink in shade, as the art direction asks.
* From the first step there is an axis: through the lintel at the foot of
  the Stair, up both flights, to the gold band over the Hall's portal.
* The landing (four Clerks among copyists' desks, the grille of the Docket
  Gate to one side), the forecourt (banners, lamps, the Bailiff, the Hall's
  columns beyond) and the Hall (Voss small and far across a wide floor)
  each compose without help.
* The Docket is dark green water between shelves, under ribs. It is the
  one place with a mood of its own.
* Both gates, both prompts, and both record leaves draw and are legible.
* All twelve models sit at the right size beside the figures.

Frame time: 60 Hz at the median everywhere. 99th percentile 33 ms in the
market (597 draw calls), 23 ms in the Docket (535), 39 ms in the Hall (221,
measured while Voss was waking). Draw calls are within budget; the hitches
first seen in M3 are still here and still unexplained.

Five things the first capture showed, changed, and **confirmed by the
second**:

* **The Hanging Courts could not be seen from anywhere.** They stood 320 m
  to the north and every wall in the Quarter hid them. They now hang over
  the Hall, their lowest point forty metres above it, and should fill the
  sky above the north wall when the player looks up from the market.
  Confirmed, with a reservation: they are visible from the market and from
  inside the Hall, but they read as pale stepped slabs in the sky, not yet
  as a city hanging there. Their chains are hairlines.
* **The interact prompt was drawn across the Witness's back.** It is now
  under their feet, and the Quarter starts with the help panel folded away
  ("H keys") to make room.
* **A bright blob followed the camera across the Docket's water.** It was
  the lamps' highlight on a mirror-smooth surface. The lamps no longer
  give one.
* **The fallen vow could not be found.** It was a red hairline. It is
  thicker and lies in three pieces in front of the rubble.
* **Both vow-stones were hidden behind the Witness.** Staging; the capture
  now stands to one side.

Three things it showed and **not changed**, for the owner to judge:

* The vows hanging over the market are rows of gold dashes. They read as
  ruled or written lines, but also a little like a dashed border. They
  could become something more like script.
* Where the Oath Hall stood there is rubble, a low broken wall and a large
  dark mass with the black bar across it. It reads as "something dark
  there", not yet as "a hall fell here".
* Everything out of the sun is one flat grey-violet. That is the palette's
  ink shadow doing what it was told, but across a whole ramp or the back
  of the Docket it is a lot of one colour.

**A third capture, with Vows** (`m5_third_look/`, 22 moments). Seen: the
stone's list of five choices; "Sworn: I will not be struck from behind."
as a banner; the sworn line at the top of every later shot, with the
Arbiter's panel moved down beneath it; and a gold ring at the Witness's
feet for as long as the Vow stands (the engine's ordinary mark for a law
laid on oneself; nobody designed it for Vows, and it suits them). One
fault: the stone's list ran under the corner of the law panel. The law
panel is now hidden while a list is open; **not re-checked**. A Vow being
kept and a Vow falling have not been captured.

Frame time in the third capture, on battery in Low Power Mode but with
nothing else running: median 16.7 ms everywhere; 99th percentile 19 ms in
the market (594 draw calls), 21 ms in the Docket (540), 18 ms in the Hall
(226). **These are the best numbers the game has produced**, and there is
no hitch in them. The hitches of M3 and of the first Quarter capture may
have been the machine and not the game; one clean run does not prove it.

**The second capture's frame times are not usable.** Median 30 ms, worst
frames 70 to 380 ms, with the same draw calls as the first. The Mac was on
battery in Low Power Mode with another game running at 246% CPU, so this
says nothing about the Quarter either way. The first capture's numbers
stand until it is measured again on mains with nothing else running.

One thing went wrong in the first run itself: a script error was printed once
("get_tree" on a node outside the tree, in the capture tool's wait). All
nineteen shots were still written. The pattern fits the capture scene
being reloaded part-way by a key reaching its window (Backspace is
"reset"), after which it ran again from the start; that is a guess, not a
finding. Capture runs no longer obey the keyboard, and the second run
printed no error.

What the roadmap asked of M5 and this does not yet do:

* **"First production art pass."** This is a composed blockout in the right
  palette: blocks of flat colour and twelve simple models. Not production.
* Vows are built (D-032). Their reward is thin for now: standing decides
  contests between laws, and in the slice only the Escort is contested.
* **"Environmental storytelling"** is eight short records and some set
  dressing (a fallen vow, a struck plinth, a sealed gate). No people.
* **Criterion 9, "atmospheric and worth exploring"**, cannot be judged
  from a test. It needs a capture, then a person walking it.

Also not done: enemies have no pathfinding (posts are in open rooms so it
does not show yet); water is only a surface; no sound of place.

## M4: Aurel Voss (built 2026-11-12)

| What | As built | State |
|---|---|---|
| The fifth encounter | "Aurel Voss, the Last Arbiter": 420 health, armoured strikes, his own body and the Imprimatur. N steps through the opponents to him | **Tested** headless |
| Three phases, as data | Arraignment (one Writ), Cross-examination below two thirds (two Writs, and he baits what they forbid), The Hearing below one third (his Edict and the Writ of Licence) | **Tested** |
| He says each rule | Every Writ is spoken as it is imposed and shown as a banner. A spoken law can be read by everyone at once, as an Edict can (`LawWorld.declare`) | **Tested**; the banners were seen in the capture |
| He obeys his own Edict | Under The Hearing his AI never chooses the act he made last. Forty seconds of attacks, no repeat, no denial | **Tested** |
| Seals | His stamp leaves a seal 2.5 m in front of him: a body with 50 health, 25 seconds, three at most. It can be struck, bound as a twin, or cut off by a line | **Tested** |
| One swing is one act (D-026) | A sweep reaching him and a seal is heard once by The Hearing | **Tested** in the engine and in the fights |
| He yields (D-025) | At 33 health the blow that would kill him spares him; his Writs end; he cannot be struck | **Tested** |
| The choice | "Take my licence, or refuse it." 1 takes it (licensed and recognised), 2 refuses. Logged. **Nothing reads the answer yet** | **Tested** for the mechanism only |
| HUD | A boss bar with phase marks and his standing Writs, without lock-on; his words; the offer | Seen in two captures. Two small changes after the second are **not re-checked** (below) |
| Capture tool | `CaptureM4.tscn`, 11 moments, about 40 s | Run twice in a window |

**Seen in the game twice** (`docs/screenshots/m4_first_look/` and
`m4_second_look/`, 11 moments each).
What worked: Voss's model and the Imprimatur render and animate (the
overhead stamp reads clearly as a wind-up); each Writ and the Edict appear
as a banner when he speaks; the seal is a vermilion disc with a gold
meridian and is easy to see on the stone; a strike from behind shows "Writ
of Standing: the Arbiter did not see it struck, sanction 8"; his yielding
line, the two-option offer and "Licensed. The Court will know your name."
all draw. Frame time: 16.7 ms at the median, 23 ms at the 99th percentile,
240 draw calls. That is the best of any capture so far, but it is one
enemy, not four.

Three things the first capture showed, changed, and **confirmed by the
second**:

* **His Writs were struck out on his own panel.** A law the player has not
  yet met is drawn as a black bar, and his Writs counted as unmet even
  though he had just said them aloud. The bar sat under his thin health
  line and read as a broken health bar. Now a law spoken by its author is
  read by everyone at once, and two checks cover it.
* **His health line was too thin to read.** It is a proper bar now, with a
  gold mark at each point where the hearing turns. An unmet law is drawn
  as the words "a law not yet met" under a thin strike, not as a block.
* **The ending hid him.** In the yield and licence shots he stood directly
  behind the Witness. That was the capture's staging; it now sets them
  apart first.

Two things the second capture showed, changed since and **not re-checked**:

* A read Writ's sentence was cut off at the edge of his panel ("No one may
  strike the Arbiter u"). The panel now widens to fit its longest line.
* His offer was drawn over his head. A question is now put at the foot of
  the screen, in place of the help panel.

Frame time in the second capture: 16.7 ms median, 22 ms at the 99th
percentile, 222 draw calls.

Two things both captures showed and **not changed**:

* He does not look like the most dangerous thing in the yard. He is a
  pale, narrow figure in a tall cap, a little smaller on screen than the
  Witness in front of him. Whether that is the tired judge the design
  describes or simply underwhelming is the owner's call.
* With lock-on, at his preferred three metres, the Witness's back covers
  part of him. This is true of every opponent; it matters more for one
  whose tells have to be read.

### Six scripted fights (`docs/m4_logs/`)

The roadmap's exit test: each Root wins by at least two distinct lines,
shown by logs.

| Root | Line | How the policy plays | Result |
|---|---|---|---|
| Threshold | The Gatekeeper | Bars the way and strikes after a denial | Yields in 57 s, Witness untouched. 17 denials |
| Threshold | The Gatekeeper, Unveiled | Strikes through the gate from its own side | 47 s, untouched. 9 strikes from the threshold |
| Debt | The Creditor | Catches blows on the Tally, calls the debt in | 27 s, on 74 health. 30 conversions |
| Debt | The Debtor | Takes blows as debt and pays them forward by striking | 46 s, on 56 health. 20 paid forward, 2 came due |
| Reflection | The Answer | Parries, earns recognition, returns the blow | 28 s, untouched. 8 returned, 13 mirrored |
| Reflection | The Twin | Binds a seal to him and beats the seal | 64 s, untouched. 29 harms copied |

Read these honestly:

* They are six different fights by the engine's own count of outcomes. That
  is what criterion 6 asks, and it is **met in test, not in play**.
* Four of six bots finish untouched. Bots parry and step with perfect
  timing, so this does not say he is easy, but it does not say he is hard
  either. His difficulty is unknown until a person fights him.
* Threshold's two lines are one Assertion in two forms. The Divide has no
  line against him.
* Each line was run once, from one starting position. The testing plan's
  hundreds of seeded matches, and its check for a single repeated act that
  wins, are **not built**.
* Every line went through all three phases and met the Writ of Licence and
  The Hearing.

What M4 does not yet do:

* The fight is in the practice yard. The Hall of Standing is M5.
* His moves are two borrowed clips, a sweep and an overhead. He has no
  motion of his own, no entrance and no yielding animation beyond a pose.
* His lines are text. No voice, no music, no camera work.
* The choice changes two tags and a flag. The Court and Crownless lines it
  is meant to open are M6.
* The design's variants (rematch, Vow, Warrant) are not built.

## M3: Instruments and Unveiling (built 2026-11-11)

| What | As built | State |
|---|---|---|
| The Instrument follows the law's Root | Lintel for Threshold, Tally for Debt, Counterpart for Reflection. It changes when a law of another Root is chosen, never mid-swing | **Tested** headless |
| Three bodies of moves | Lintel: reach 3.4 to 4.0 m, slowest, hardest. Counterpart: three quick cuts at 2.4 m. Tally: 1.75 m, quickest to recover, guard lets 15% through | **Tested** (frame data and a reach test in the yard). Untuned by hand |
| **Plant** (Lintel) | Drawing a line plants the stave at its middle; the short half is in hand (reach 2.1 m, quicker) until the line ends | **Tested** |
| **Catch** (Tally) | A blow guarded under the Creditor is owed in full, not only the 15% that got through. A clause of the law, not special code | **Tested** in the engine and the yard |
| **Show** (Counterpart) | Imposing the Twin arms the blade and costs nothing; the next two struck are bound, and the price is paid then | **Tested** |
| Recognition Trials | One per Assertion (five denials, forty called in, three blows returned...). Counted from what the Law Engine notes, saved with the character | **Tested** |
| The Unveiling | Recognised, hold the Axiom button and Guard for 1.25 s unstruck. Laws take their Unveiled form, Resonance is made whole, enemies within 6.5 m are thrown down unharmed, the Instrument wakes | **Tested** |
| Awakened Instruments | Lintel: the crossbar opens; a heavy blow runs on into a full circle. Counterpart: a second, reflected blade; a fourth turning cut. Tally: the cord trails; a cast that strikes at 4.8 m | **Tested** for the moves. Models built and reviewed in Blender only |
| HUD | The law panel names the Instrument, shows trial progress, "RECOGNISED", the rite's progress, and an armed blade | Draw code runs headless without error. **Never rendered** |

**Seen in the game once** (`docs/screenshots/m3_first_look/`, 21 moments).
What worked: the Lintel carried, reaching a Bailiff at range, and standing
planted on its line with the short half in hand; the Tally's catch ("owes
you 12" above the Bailiff); the armed Counterpart binding two with one cut;
the rite, the gold shock rings and the "Unveiled" banner; the law panel's
Instrument name and trial count. The closer camera from the last round
frames the taller figures well.

Three things it showed, changed since and **not re-checked**:

* The Instrument only woke in the hand after the Unveiling pose ended. It
  now wakes at the moment of Unveiling.
* The law's name and the Instrument's name ran into each other on the
  panel. The panel is wider.
* Both blades were too thin and too mirror-like to see from behind. They
  are broader, duller, and the reflected blade gives a little light.

Frame time in that capture: 60 Hz at the median, but a 99th percentile of
42 ms in the four-Clerk fight. The scene is light (324 draw calls), so the
likely cause is the engine building a render pipeline the first time each
new effect or model appears. Unconfirmed; it needs a proper look before M5.

What this does not yet do:

* The Unveiling's "sequence" is a held input, a pose and a shock. There is
  no bespoke transformation animation and no camera work.
* In the yard a character can hold all six laws, so one Unveiling applies to
  whichever Instrument is in hand. In the real game a character has one.
* The Tally's verb exists for the Creditor only; the Debtor has none.
* The Answer still has no Unveiled law form.
* Strikes with the Tally are a borrowed punch and kick; the gauntlet is on
  the off hand as designed, so the punches are bare-handed.

## Owner direction, 2026-11-11: no chibi models

The owner rejected the KayKit placeholder characters: their small, cute
style contradicts the game's theatrical, dramatic one. **Every model is to
be made from scratch.** This overrides D-016 (see D-022).

**Done.** The pack's characters and weapons are deleted from the game.
Everything on screen in the yard is now VOWFALL's own, built by scripts in
`tools/blender/` and reviewed with headless Blender renders
(`docs/screenshots/models/`):

| Model | What it is | Triangles |
|---|---|---|
| The Witness | 1.86 m. A long ink coat with an uneven hem, a high open collar, a shoulder mantle, the left arm in a full sleeve and the right bound in cord, a lead seal at the throat, sealed strips of vellum at the hip, an empty hilt | 4,200 |
| Court Bailiff | 1.97 m, broad and faceless. A pale surcoat to the ankle, an ink stole with lead seals, the meridian in gold on the chest, squared shoulders, a closed helm with one slit and a fin | 2,664 |
| Ward of the Court | 1.73 m. A short tunic, a verdigris cowl coming to a point, a hood with a long tail | 3,040 |
| Court Clerk | 1.80 m, narrow. An ink robe to the ankle, white legal bands, a skullcap, a long nose | 2,784 |
| Held items | The Counterpart (single-edged blade), a seal-headed tipstaff, a tablet shield with the meridian, a knife, a pen-knife, a ledger | 36 to 320 |
| Yard | A stone stele (plain, and sealed with wax, ribbons and a gold band), a ten-metre column with base, swell, capital and abacus | 320 to 1,200 |

What is not ours: **motion.** The figures play the pack's 76 CC0 clips on a
skeleton re-proportioned from 1.5 m to 1.86 m (`rig.py`); feet still meet
the floor. Bespoke animation is M3 and later.

What has been checked: every model renders in Blender from four angles and
in motion; each loads in the game with its 76 clips; held items point where
they should in idle, strike, guard and run (measured, not seen); all 238
headless checks pass.

**Seen in the game once** (`docs/screenshots/models_in_game/`, 16 moments):
all four figures, their held items, the posts and the columns render and
animate in the yard; materials read correctly under the game's light; the
law effects sit at the right heights on the taller figures. Frame time held
60 Hz at the median with a 99th percentile of 35 ms in the four-Clerk fight
(408 draw calls: each figure is many small materials, an easy thing to
merge later).

Two things that capture showed, changed since and **not re-checked**:

* The camera, tuned for the bulky old figures, left the new slim ones small
  in frame. It is now 4.8 m back instead of 5.8, lower, and flatter.
* Identical labels stacked on top of each other in a crowd; they now reuse
  one label.

Known weaknesses, visible in the review renders:

* They are stylised stage figures, not sculpted characters: about 3,000
  triangles each, flat colours, no textures, faces reduced to a brow, a
  nose and two slits. Whether this is dramatic enough is the owner's call.
* Robes follow the legs half-way. On the pack's high-stepping walk the hem
  still lifts more than cloth would, and a shin can pass through the front.
* The clips were made for a toy with a huge head: some poses hold the
  elbows wider than a tall figure would.
* The moveset is unchanged, so strikes are still sword swings whatever is
  in the hand (a Clerk's pen-knife swings like a sword).
* MPFB (MakeHuman for Blender) is installed here and could give realistic
  bodies if this route disappoints.

## The M2 capture (2026-11-11)

All sixteen moments rendered (`docs/screenshots/m2_first_look/`): the line
and its preview, the Divide, debt beads and the "owes you" line, the thread
between twins, mirrored and returned blows, the Warrant's seal and its
OVERRIDE verdict, four Clerks. Frame time 10.4 ms average, 15 ms at the 99th
percentile, with 384 draw calls. Noted and not yet changed: a Debtor's own
beads sit high enough to read as the enemy's; the help panel is large.

## Done

| What | State | Proof |
|---|---|---|
| Audits and the development bible | Written | `docs/00` to `docs/13`, 33 logged decisions |
| Law Engine core, 12 laws as data | **Tested** | 70 checks |
| Action machine | **Tested** | 21 checks |
| Controller, camera, lock-on, HUD, the yard (M1) | **Tested** headless; seen twice in captures; unplayed | 61 checks, `docs/screenshots/` |
| Axiom input: impose (tap, draw, commit), inscribe, counter | **Tested** headless. Unseen, unplayed | 21 checks |
| All six Assertions in play through real input | **Tested** headless. Unseen, unplayed | 37 checks |
| Court laws against the player's: Override, Cancellation, Contest | **Tested** in the live scene | 12 checks |
| Opponents: Bailiff, Bailiff with Warrant, Bailiff and Ward, four Clerks | **Tested** for behaviour and sanity. Untuned | data in `game/data/enemies/` |
| Standing-law effects (lines, rings, threads, beads, preview) | Implemented; code runs headless without error. **Never rendered** | presentation checks |
| HUD: law panel, owed amounts, consequence labels, encounter banner | Implemented; draw code runs headless without error. **Never rendered** | presentation checks |
| Verdict log, exportable as text | **Tested** | `docs/m2_logs/` |
| One fight three ways | **Done by scripted policies, not by people** | three logs, 6 checks |
| Capture tool for M2 (16 moments) | Written; dry-run headless is clean | `game/tools/capture_m2.gd` |

## M2's exit test, honestly

The roadmap says: "the same encounter played three ways is three different
fights, recorded as three verdict logs." That exists in `docs/m2_logs/`:

| Law | How the policy plays | Result against one Bailiff |
|---|---|---|
| The Gatekeeper | Bars the way, waits, strikes only after a denial | Won in 26 s on 64 health. 8 denials |
| The Creditor | Takes the blow facing him, strikes only to call the debt in | Won in 10 s on 64 health. 3 loans, 3 call-ins |
| The Answer | Parries everything, strikes into the opening | Won in 9 s untouched. 3 blows returned, 2 strikes mirrored |

These are three different fights by construction of the engine, and the logs
show it. But they were played by scripts with perfect timing. Whether a
person finds them different, readable and fun is the real test and has not
been run. Criteria 3 and 5 are therefore **met in test, not yet in play**.

## What still needs eyes and hands

1. A capture of the Quarter (`CaptureM5.tscn`, about 50 seconds, needs a
   window): the whole art pass is unseen, and one new shader has never
   been compiled.
2. Play. Everything about feel: strike timing, the Axiom button (tap, hold,
   draw), how readable a line or a thread is in a fight, whether the Bailiff
   is fair.
3. Then a stranger.

## Not started

Any level beyond the Quarter. Stacked Vows (the Assize). People in the Quarter. Awakening, quests, factions in play, Chronicle
and Codex persistence, save files, menus, production art, music, bespoke
animation, Sovereignty and Paradox.

## Blocked

| What | By | Needs |
|---|---|---|
| Reference images | Image connector has 0 credits (free plan) | Credits, or another generator |
| Unreal Engine | Not installable here | See D-001 |
| Bespoke animation | No animator, no mocap | CC0 clips for now (D-016) |

## Decisions that need the owner

1. **The Canon Twelve and the Struck Six (D-003).** Open.
2. **The slice as a standalone short game.** Open.
3. **Art direction "Illuminated Law" (D-011).** Open.
4. **Image generation.** Open.
5. **The Axiom button scheme (D-019).** Tap to bar the way, hold and walk to
   draw, hold to commit, hold while striking to inscribe. It is one button
   doing four things; it needs to be felt before it is kept.

## Vertical slice acceptance criteria

| # | Criterion | State |
|---|---|---|
| 1 | Controllable third-person character | Implemented and tested headless. Not yet played |
| 2 | Movement and combat feel responsive | Unverified |
| 3 | Three Axioms create different gameplay | **Met in test** (six Assertions, three scripted fights, three logs). Not yet in play |
| 4 | Each Instrument has a distinct combat identity | **Met in test**: three movesets that differ in reach, speed, weight and guard, and a verb each. Not yet in play |
| 5 | The Law Engine resolves meaningful interactions | **Met in test, in the live scene**: all five outcomes arise from real input against real opponents |
| 6 | A boss challenges different builds differently | **Met in test**: six scripted lines, two per Root, each won by a different count of engine outcomes. Seen once; unplayed |
| 7 | Unveiling changes gameplay | **Met in test**: earned by a trial, performed in play; it changes the laws' rules, the Instrument's moves and its model. Not yet in play |
| 8 | The player can discover and understand the rules | Verdict line, sensed and read law names, a text log. No Codex screen |
| 9 | The region is atmospheric and worth exploring | A district exists, can be walked end to end in test, and composes well in stills. It is a blockout with one mood (the Docket). Unplayed: **not met** |
| 10 | Progression and save/load work | Engine state only |
| 11 | Stable and maintainable | True of what exists |
| 12 | Polished enough to show external players | No |

## Measured

| What | Cost |
|---|---|
| One strike judged by four standing laws | 134 us |
| Whole simulation tick, headless, M1 yard | about 400 us of a 16,667 us frame |
| Whole frame headless with HUD and law effects, four Clerks attacking | 0.84 ms average, 2.5 ms worst |
| Rendering (M1 yard, 3420x2084 window, 67% 3D scale, 60 Hz) | Held 60. CPU render 0.38 ms. GPU time not reported by the driver |
| Rendering with M2's effects | **Not measured** |

## Known issues

* Nothing in M2 has been rendered. Likely first-look problems: effect sizes
  and colours against the stone, the law panel's position, clutter with
  four Clerks.
* The Bailiff was a pushover for a mashing bot (dead two seconds after
  contact). He now keeps swinging through light hits and may answer a
  blocked strike (D-018). Untuned by play.
* A pair law takes the locked target and whoever stands nearest to it. The
  design's "the next two things you strike" waits for the Counterpart (M3).
* Impose cannot yet be cancelled into from a landed strike (the combat
  design allows it).
* The sealed post re-imposes its Writs every fifteen seconds, which adds
  noise to every verdict log.
* The Quarter has been seen only in stills. Not yet looked at: feet on the
  steps (they are walked as a ramp), the camera against walls on the Stair
  and in the ramps, the gates in motion.
* Enemies walk in straight lines. In the Quarter a fight dragged round a
  corner will leave them pressed against a wall.
* Voss is untuned. Four of six bots beat him untouched; whether a person
  can is unknown.
* The frame hitches measured in M3's capture (99th percentile 42 ms) have
  not been looked at.
* Models are the game's own; motion, sound and fonts are still borrowed. Scopes ignore height. Tuning numbers are first-pass.
* No project-level git repository. Nothing is committed.
