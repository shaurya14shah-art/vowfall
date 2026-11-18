# Decision log

Every significant change to the original concept or to the architecture.
Newest at the bottom. Each entry answers the Directive's seven questions:
what changed, why the original was insufficient, the alternative, effect on
play, technical implications, production cost, why it is better.

A decision marked **OPEN** was made so work could proceed and is the owner's
to overturn.

---

## D-001. Engine: Godot 4.7 instead of Unreal Engine 5. OPEN

1. **Changed:** the engine.
2. **Why the original fails:** Unreal is not installed, needs full Xcode
   (not installed, needs the owner's password), 60 to 100 GB and more than
   16 GB of RAM to be comfortable. The owner ruled it out on this machine
   earlier. An agent cannot author Blueprints, materials or levels from a
   terminal.
3. **Alternative:** Godot 4.7.2, already installed, text-based scenes and
   resources, runs headless.
4. **Play:** none directly. A stylised look instead of Nanite and Lumen
   realism, which the art direction wants anyway.
5. **Technical:** typed GDScript; core kept free of engine types so it can
   move.
6. **Cost:** saves weeks of setup. Loses Unreal's animation tooling
   (motion matching, control rig) and marketplace.
7. **Better because:** it is the only option on which work can be built,
   run and tested today, on the machine that exists.

*To reverse:* install Xcode and Unreal on a machine with 32 GB or more; port
`core/law/` (about 1,100 lines) to C++ against the 40 scenarios.

## D-002. Law Engine core in pure GDScript, not C++

1. **Changed:** the Directive preferred C++ for core systems.
2. **Why:** C++ in Godot means GDExtension, which needs scons and godot-cpp
   (neither present), a compile step on every rule change, and a binding
   layer. The core is small.
3. **Alternative:** `RefCounted` GDScript classes with no nodes, integers
   only, pinned by data-driven scenarios.
4. **Play:** none.
5. **Technical:** 134 microseconds per fully judged strike measured; budget
   500. The scenarios are language-neutral JSON.
6. **Cost:** near zero now. A port later is bounded and testable.
7. **Better because:** rules can be changed and re-tested in seconds, which
   is what a design still being discovered needs.

## D-003. The Canon Twelve and the Struck Six

1. **Changed:** eighteen taught Roots become twelve taught and six struck
   from the Canon, one per family.
2. **Why:** several Roots were the same mechanic (Continuity, Memory and the
   Reflection example; Absence and Silence; Permission and Threshold);
   Possibility cannot be done honestly in a deterministic game; eighteen
   Roots at two Assertions each is 36 kits.
3. **Alternative:** each Root governs exactly one engine concept. Each
   family is taught as a pair; the struck third breaks the pair. Struck
   Roots belong to bosses first and unlock for players through Codex
   discoveries.
4. **Play:** twelve clearly different Roots at launch; a strong reason for a
   second Chronicle; bosses that use rules the player was told do not exist.
5. **Technical:** `roots.json` carries `canon` and permitted operations.
6. **Cost:** removes a third of launch kit work.
7. **Better because:** it turns "forbidden Roots, maybe later" into the
   spine of the mystery, and the number eighteen stays true.

## D-004. Axioms are authored; the grammar validates, it does not generate

1. **Changed:** "individually generated" powers and Instruments.
2. **Why:** generated abilities are dull or broken; generated Instruments
   cannot have unique animation.
3. **Alternative:** authored Assertions written in a formal grammar and
   checked by a validator with a power budget. The awakening chooses among
   authored candidates.
4. **Play:** every power is one someone designed and tested answers for.
5. **Technical:** `LawValidator`, 13 rule codes, 19 refused examples.
6. **Cost:** each Assertion is authored work: about one data file entry,
   four scenarios, plus presentation.
7. **Better because:** it is achievable and it is what quality needs.

## D-005. Nine operations: DEFER and DENY added

1. **Changed:** seven operations become nine.
2. **Why:** holding a consequence for later and refusing an act are
   primitives. Expressing "may not cross" as PRESERVE, or a debt as
   TRANSFER, hid what the law did.
3. **Alternative:** add them; PRESERVE keeps the meaning "this act must
   proceed", which is what opposes DENY in a conflict.
4. **Play:** laws read the way they behave.
5. **Technical:** FORBID, TAKE and REQUIRE stances fall out cleanly.
6. **Cost:** none.
7. **Better because:** the grammar is honest about its primitives.

## D-006. Doctrines redefined as engine properties

1. **Changed:** the meaning of Dominion, Custody, Guile, Convergence.
2. **Why:** as written they were aggressive, defensive, tricky, combo.
3. **Alternative:** Authority, Persistence, Trigger, Chain: one engine
   property each, applied as a tenet per Expression.
4. **Play:** a build choice changes which conflicts you win and how your
   laws end, not a damage percentage.
5. **Technical:** authority and term already exist. Tenets not built.
6. **Cost:** small; they are modifiers on existing fields.
7. **Better because:** two players with the same Assertion now lose to
   different things.

## D-007. Edicts bind their author and are counted in acts

1. **Changed:** the definition of an Edict.
2. **Why:** a personal battlefield rule is a familiar shape elsewhere, and
   an asymmetric one is a win button.
3. **Alternative:** an Edict may not exempt its author (validator rule
   E_EDICT_EXEMPT) and its term is a number of acts.
4. **Play:** speaking an Edict is a commitment. Opponents can run its count
   down or use it against its author.
5. **Technical:** implemented and tested with The Hearing.
6. **Cost:** none.
7. **Better because:** it is distinct, fair, and it is the cosmology in
   miniature.

## D-008. Paradox changes one slot, not the whole kit

1. **Changed:** "the Axiom changes fundamentally" becomes "one slot of the
   Assertion changes: its operation, its subject or its trigger".
2. **Why:** a full second kit per Assertion doubles content.
3. **Alternative:** a single-slot change that inverts how the law is used.
4. **Play:** the same character, played differently, with continuity.
5. **Technical:** a second form in the same definition, like UNVEILED.
6. **Cost:** roughly 40% of a new kit instead of 100%.
7. **Better because:** a contradiction inside one sentence is what a
   paradox is.

## D-009. Six Severances; the Hanging Kingdom joins Veyr

1. **Changed:** seven regions become six. Launch target is four.
2. **Why:** seven bespoke regions is beyond scope, and six struck Roots
   wanted six places to leak.
3. **Alternative:** one Severance per struck Root. The Hanging Kingdom
   becomes Veyr's upper city.
4. **Play:** each region's rule is a mechanic the player will later meet as
   a Root.
5. **Technical:** a Severance is a regional law in the same engine.
6. **Cost:** one fewer region; a better Veyr.
7. **Better because:** world structure and power system are the same shape.

## D-010. Vows

1. **Changed:** added. Optional sworn promises with a reward and a forfeit.
2. **Why:** the game was called Vowfall and nothing fell. Difficulty options
   and challenge modes had no place in the fiction.
3. **Alternative:** vow-stones; a Vow is a law with the player as author and
   subject.
4. **Play:** self-set difficulty, the Assize challenge mode, a title that
   means something.
5. **Technical:** reuses the engine. Not built.
6. **Cost:** small.
7. **Better because:** one mechanic covers three needs.

## D-011. Art direction: Illuminated Law

1. **Changed:** "dark, sophisticated, luxurious" becomes a specific
   language: manuscript, seal, ruled line, struck text.
2. **Why:** the brief asked for something that is not generic dark fantasy
   and gave none.
3. **Alternative:** `08_art_direction.md`.
4. **Play:** effects with edges are easier to read in a fight.
5. **Technical:** stylised rendering fits the hardware.
6. **Cost:** lower than realism.
7. **Better because:** it follows from what the game is about.

## D-012. The awakening shows its evidence

1. **Changed:** weighted random Root selection becomes a deterministic
   offer of three with the reasons shown.
2. **Why:** hidden randomness feels arbitrary; behaviour scoring is noisy.
3. **Alternative:** top Root, second Root, shadow Root; each lists the
   moments that earned it. Later Chronicles may pick a recorded Root.
4. **Play:** the player recognises themselves in the offer.
5. **Technical:** seeded, testable.
6. **Cost:** the prologue must be built from dilemmas with legible options.
7. **Better because:** agency and meaning both go up.

## D-013. Hands and laws

1. **Changed:** added. Every event is `by_hand` or `by_law`.
2. **Why:** the engine needed a principled way for laws to treat a person's
   act and a law's consequence differently without naming each other.
3. **Alternative:** two tags, set by the engine.
4. **Play:** "Writs bind hands, not laws" and every answer that follows.
5. **Technical:** two strings.
6. **Cost:** none.
7. **Better because:** large amounts of counterplay from no special cases.

## D-014. Four Instrument frames; Singular is for bosses

1. **Changed:** five archetypes become four frames (three in the slice).
2. **Why:** "Singular" meant "bespoke", which is not a reusable frame.
3. **Alternative:** Edge, Reach, Vessel, Array. Singular labels boss
   Instruments.
4. **Play:** none lost.
5. **Technical:** one fewer moveset pipeline to pretend exists.
6. **Cost:** lower.
7. **Better because:** honest.

## D-015. No stamina, no cooldowns, no air combos in the slice

1. **Changed:** resource model and combat scope.
2. **Why:** stamina slows a fast game; cooldowns are what the Directive
   said to avoid; air combos need airborne states on every enemy.
3. **Alternative:** Health, Poise, Resonance. Evasion limited by a slow
   third dodge. Plunge attacks only.
4. **Play:** faster, fewer bars, every bar is about fighting or about laws.
5. **Technical:** simpler controller.
6. **Cost:** lower.
7. **Better because:** it serves the pillars. Revisit air combat after M4.

## D-016. Placeholder characters and clips from CC0 packs for the greybox

1. **Changed:** M1 uses KayKit Adventurers models and animations and Kenney
   sounds (already licensed and on this machine from Crownfall) instead of
   capsules.
2. **Why:** feel cannot be judged on a capsule, and the owner has disliked
   code-built block characters before.
3. **Alternative:** real rigged characters as stand-ins, kept in
   `game/assets/placeholder/` with a licence file, and frame data fitted to
   the clips by measuring when each swing's hand speed peaks.
4. **Play:** strikes, dodges and reactions are readable from the first run.
5. **Technical:** clips are sped up 1.4 to 2.3 times to meet the frame data.
6. **Cost:** 8 MB of assets. They are replaced in M3 and M5.
7. **Better because:** the milestone's question is "does it feel good", and
   this is the cheapest way to be able to ask it. They are not the art
   direction and must not be mistaken for it.

## D-017. The verdict line always states its reason

1. **Changed:** the combat document said an unread law shows only its glyph
   and name on the verdict line.
2. **Why:** a denied strike with no reason reads as a dropped input, which
   is the failure the verdict line exists to prevent.
3. **Alternative:** the line always says why this event was judged as it
   was. What is earned by repeated sightings is the law's standing
   description above the enemy and in the Codex.
4. **Play:** less frustration on first contact; discovery still has a reward.
5. **Technical:** none.
6. **Cost:** none.
7. **Better because:** it serves "read, then break" without hiding the
   first half.

## D-018. Armoured strikes and the riposte

1. **Changed:** a Bailiff's strike under way is no longer interrupted by a
   blow that leaves his poise standing, and after blocking a hit he may
   strike back at once. Guard chance after two hits raised from 0.5 to 0.7.
2. **Why:** a scripted player mashing light killed him about two seconds
   after contact, every time, with any law or none. Hit-stun on every hit
   made poise meaningless and made laws unnecessary.
3. **Alternative:** poise decides interruption while he is swinging; data
   flags it per enemy (`armoured`). The player has no such armour.
4. **Play:** striking into his swing is a trade you lose. Openings are after
   his strikes, after a denial, after a parry: where the laws make them.
5. **Technical:** one flag on `Actor`, two numbers in enemy data.
6. **Cost:** none. Tuning needs hands.
7. **Better because:** it gives each law's opening something to be worth.

## D-019. One Axiom button: tap, draw, commit, inscribe

1. **Changed:** the combat design listed four inputs. As built they are one
   button used four ways (see `05_combat.md`).
2. **Why:** a line law needs two points, a pair law two subjects, and both
   need to be usable in under a second in a fight.
3. **Alternative:** a tap lays a default (a bar across your front; your
   target and its nearest neighbour). Holding and walking draws exactly.
   Holding longer commits. Holding while striking inscribes.
4. **Play:** the fast version is always available; precision costs time
   and exposure.
5. **Technical:** in `Player`; the engine is untouched.
6. **Cost:** none.
7. **Better because:** it is learnable in one sentence. It is also unfelt:
   the owner should try it before it is kept.

## D-020. A lunge never carries you over your own line

1. **Changed:** a strike's forward movement stops at the mover's own
   boundary. Walking over it still ends it.
2. **Why:** the Gatekeeper's price is "step over your line and it ends".
   The first scripted fight broke the line on its second follow-up strike,
   by lunge, without any decision by the player.
3. **Alternative:** the body refuses; the engine answers a question
   (`would_breach`) and changes nothing.
4. **Play:** the price is paid only on purpose, or when an enemy knocks you
   across, which remains counterplay.
5. **Technical:** one query on `LawWorld`, one check in `Actor`.
6. **Cost:** none.
7. **Better because:** a price you pay by accident is a bug, not a price.

## D-021. A returned blow carries its full weight

1. **Changed:** the engine's INVERT returns `max(amount, data.weight)`.
2. **Why:** a perfect parry takes the harm out of a strike before the
   engine sees it, so the Answer was returning nothing.
3. **Alternative:** the combat layer reports the weight a blow was thrown
   with; a law that turns the blow around uses it.
4. **Play:** parrying under the Answer returns the whole blow, as written.
5. **Technical:** one optional data field.
6. **Cost:** none.
7. **Better because:** the law now does what its sentence says in play, not
   only in the engine's own tests.

## D-022. The game's own models, built by script. D-016 is withdrawn

1. **Changed:** the KayKit placeholder characters and weapons are deleted.
   Every figure, held item, post and column is modelled from scratch.
2. **Why:** the owner rejected the pack: a chibi, cute style contradicts a
   theatrical, dramatic game, even in a greybox.
3. **Alternative:** procedural modelling in Blender, run headless
   (`tools/blender/`): a small kit of lofts, stacks, tubes and strips with
   skinning; shared anatomy; one script per figure. Reviewed by headless
   render, so no game window is needed to judge a model.
4. **Play:** none directly. Figures are 1.86 m instead of a scaled toy, so
   reach and framing read differently.
5. **Technical:** the pack's skeleton is re-proportioned and keeps its 76
   clips; only motion is borrowed. Models are about 3,000 triangles, flat
   coloured, no textures. 11 MB, most of it the clips repeated in each file.
6. **Cost:** every change of look is now ours to make. Faces, hands and
   cloth are simple because they are generated, not sculpted.
7. **Better because:** the world on screen finally belongs to this game's
   art direction, and it can be changed by editing a number.

## D-023. Instruments as built: bound to the Root, a moveset and a verb

1. **Changed:** the design gave each Assertion its own generated
   Instrument. As built there is one Instrument per Root in the slice, and
   it is what changes the body: the Lintel, the Tally, the Counterpart.
2. **Why:** a moveset is the expensive part and has to be authored; three
   are affordable, six are not, and the Root is where a weapon's meaning
   lives.
3. **Alternative:** `data/instruments/index.json` binds Root to Instrument:
   a moveset, an awakened addition, what is held in each form, and a verb.
   Plant swaps the moveset while a line stands; catch is a clause of the
   law; show changes how a pair is chosen.
4. **Play:** choosing a Root chooses reach, tempo and guard, not only a law.
5. **Technical:** `Player` swaps its `ActionMachine` between actions. Motion
   is borrowed two-handed, one-handed and unarmed clips, measured and fitted.
6. **Cost:** three movesets of three to five moves. No fittings yet.
7. **Better because:** it is the smallest thing that makes criterion 4 true.

## D-024. The Unveiling is earned by a trial and performed as a rite

1. **Changed:** the design said "complete your personal Recognition Trial".
   As built: each Assertion has one measured trial, and the Unveiling is a
   held input (Axiom and Guard together, 1.25 s, unstruck).
2. **Why:** it had to be playable in a yard with no quests, and it had to be
   something done, not a menu.
3. **Alternative:** `Recognition` counts a named clause of the law from the
   Law Engine's own notes (so a trial is data: "clause deny_crossing, five
   times"). The rite is interruptible and guards nothing.
4. **Play:** the player uses their law the way it is meant to be used, sees
   the count rise on the panel, and chooses the moment to stand still.
5. **Technical:** the engine's notes now carry owner, clause and amount.
6. **Cost:** small. A real transformation sequence is still to make.
7. **Better because:** mastery is measured by the engine, not asserted, and
   the same mechanism will serve the personal quest when there is one.

## D-025. Voss yields. The engine can spare

1. **Changed:** an actor may carry `yields_at`. When a blow would take it
   below that, the bridge calls `LawWorld.spare`: it stays alive on that
   health, its laws end, and it can no longer be struck.
2. **Why:** the design says Voss is not killed, and the fight ends in a
   choice. Faking it above the engine (a hidden health floor) would have
   made the verdict log lie about what the last blow did.
3. **Alternative:** `spare` is an engine operation with its own log line
   (YIELDED). The arena then puts his offer to the player: take the licence
   (tags `licensed` and `recognised`) or refuse it. The answer is logged
   (CHOSE) and kept in `Arena.flags`.
4. **Play:** the fight ends with him speaking, not falling. Keys 1 and 2
   answer the question; while it is asked they do not change the law in
   hand.
5. **Technical:** one engine method, one bridge signal (`actor_yielded`),
   one HUD panel. Nothing reads the flag yet; the Court and Crownless lines
   are M6.
6. **Cost:** small. The choice has no consequence in the yard.
7. **Better because:** yielding is a rule the engine knows, so a later
   enemy can yield, be spared by a law, or be denied the right to.

## D-026. One swing is one act

1. **Changed:** every swing has a number. The Hearing counts and judges an
   act once per swing, however many bodies the swing reaches.
2. **Why:** found by the scripted fights. One sweep that reached Voss and
   one of his seals was heard as two acts, and the second was denied as a
   repeat of the first. The player was sanctioned for hitting two things at
   once, which the Edict's sentence does not say.
3. **Alternative:** `Actor.swing_serial` rises when an attack begins; the
   bridge passes it as `data.swing`; the engine remembers each source's
   last swing. `same_act_as_last` is false within one swing, and a clause
   may ask for `first_of_swing`.
4. **Play:** a wide blow is one argument. Seals near him no longer turn a
   legal strike into a sanction.
5. **Technical:** one integer per entity, two conditions in the matcher,
   one scenario in `tests/scenarios/voss.json`. The validator counts
   `first_of_swing` as a restriction.
6. **Cost:** none measurable.
7. **Better because:** the law now does what its sentence says when more
   than one thing is in reach, which is most of a real fight.

## D-027. Voss as built: phases are data, his choices obey his own laws

1. **Changed:** the design's three phases exist. Which Writs stand in each,
   how many at once, what he says and when he yields are in
   `data/enemies/voss.json`. How he fights is `gameplay/actors/voss.gd`.
2. **Why:** the fight's claim is that he is bound by what he imposes. That
   had to be true of his AI, not only of the engine's refusal after the
   fact.
3. **Alternative:** under The Hearing he never chooses the act he made
   last, so he is never denied by his own Edict; the engine would deny him
   if he did. In Cross-examination he turns his back when the Writ of
   Standing is up. His stamp leaves a seal: a construct with 50 health that
   stands 25 seconds, three at most. Seals are bodies in the fight, so a
   Twin can bind one to him and a line can be drawn through them.
4. **Play:** he speaks each Writ as he imposes it. The third phase is a
   strict alternation a reading player can predict.
5. **Technical:** `Voss extends Enemy`; `Seal extends Actor`. He pays for
   his Writs with Resonance like anyone and is given 5 per upkeep.
6. **Cost:** his moves are two borrowed clips (a sweep and an overhead).
   The fight is in the practice yard; the Hall of Standing is M5.
7. **Better because:** six scripted fights, two per Root, each win by a
   different count of engine outcomes. See `docs/m4_logs/`.

## D-028. A law spoken aloud is read by everyone

1. **Changed:** `LawWorld.declare(owner, law)`: the author says a standing
   law aloud and every side can read it at once. Voss declares each Writ
   as he imposes it.
2. **Why:** the first capture of his fight showed his Writs struck out on
   his own panel while a banner above displayed their text. The engine
   treated them as unmet until they had denied the player once, which
   contradicts a judge who "explains every rule before he enforces it".
3. **Alternative:** the engine already let an Edict be read on imposition
   because an Edict is spoken. This is the same rule, made available to
   any law by an act of its author. Laws nobody announces stay hidden
   until met: the sealed post's Writs still have to be found.
4. **Play:** against Voss the player is never punished by a rule they could
   not have read. Discovery stays where it belongs: in what the rules
   permit, not in what they say.
5. **Technical:** one engine method, saved with the rest of knowledge.
6. **Cost:** none.
7. **Better because:** what the HUD shows and what the character said can
   no longer disagree.

## D-029. The Quarter is built from blocks, with the game's own models in it

1. **Changed:** the Assize Quarter's architecture is made in code from
   boxes, ramps and stairs (`Massing`), merged into one mesh and one body.
   What stands in it (stones, stalls, shelves, statues, gates) is modelled
   by script in Blender, like the figures.
2. **Why:** a district needs hundreds of walls, and the art direction asks
   for blank stone with ornament only where authority sits. Modelling
   walls one by one would have bought nothing a block does not give, and a
   level editor's scene would not be reviewable without a window.
3. **Alternative:** every wall is one line of code that can be read against
   the plan, and the plan is drawn from the same collision the player
   walks on. No arches: openings are lintels, the game's own motif.
4. **Play:** none directly. The layout has no two places overlapping in
   plan, because the Law Engine's space is flat.
5. **Technical:** the whole district is a handful of draw calls plus its
   props. Stairs are drawn as steps and walked as a hidden ramp.
6. **Cost:** it is a composed blockout, not a production art pass. Curves
   cost many boxes (the round Hall is 25).
7. **Better because:** it could be built, tested by walking a scripted
   player through it, and mapped, all without opening a window.

## D-030. Keepers hold posts; vow-stones reset them

1. **Changed:** in the Quarter nobody is summoned with a key. Each
   encounter is a post: its keepers stand there asleep, rouse when the
   Witness comes near or strikes one, give up beyond a leash and walk
   back. A cleared post stays cleared until the Witness rests or falls.
2. **Why:** the yard's "next opponents" key is a test bench, not a place.
3. **Alternative:** `Quarter` extends `Arena` and overrides only who is
   here and when they fight. A vow-stone restores the Witness, becomes
   where they stand again, and puts every keeper back. It refuses while a
   post is roused. Voss, once he has yielded, is not put back: the Hall
   stays open.
4. **Play:** the short way round (the Docket Gate) and the stone past the
   last Bailiff are what make a fall to Voss cheap.
5. **Technical:** one field on `Enemy` (a post to walk back to). No
   pathfinding: posts are in open rooms.
6. **Cost:** swearing Vows at a stone, the design's reason for it, is not
   built.
7. **Better because:** the five encounters of M2 to M4 are now a journey
   with an order, a shortcut and an end.

## D-031. Voss does not open the hearing until the Witness is in the Hall

1. **Changed:** `Voss.hearing_open`. In the Quarter it is false until his
   post is roused.
2. **Why:** found by M5's tests. He began the Arraignment at the first
   tick, a hundred metres from the player: his first line replaced the
   district's name on screen, and in live play he would have spent the
   walk up imposing Writs on nobody.
3. **Alternative:** the yard leaves it true, so nothing there changes.
4. **Play:** his first words are heard when the bar comes down.
5. **Technical:** one flag.
6. **Cost:** none.
7. **Better because:** a test that reads the HUD caught what a test of the
   rules would not have.

## D-032. Vows as built: a tier of law, a forfeit, and standing

1. **Changed:** D-010 said a Vow is "a law with the player as author and
   subject" and stopped there. As built: a tier `VOW`; no clauses; a breach
   of type `EVENT`; a forfeit in harm; kept when a post is cleared under
   it; and a reward of Resonance made whole plus **standing**, which is
   added to the authority of the holder's laws until they next rest.
2. **Why:** the design named a reward and never said what it was. The
   game's own rule is that power does not come from numbers that grow, so
   the reward had to be something the Law Engine already understands.
   Authority is: it is how two laws of equal rank and reach are decided.
3. **Alternative:** considered and refused: a health or Resonance cap
   (stats), a currency (there is nothing to buy), a cosmetic (nothing to
   risk a forfeit for). Resonance on its own was too little: a rest gives
   the same. Standing that lasted across rests could be farmed on the
   first Bailiff, so a rest forgets it. That makes a Vow a wager on not
   stopping.
4. **Play:** swear at a stone, clear the next post without the named thing
   happening, and arrive at the post after it full of Resonance with a
   word that weighs something. Break it and pay on the spot.
5. **Technical:** the engine comment said only the hands raise Resonance;
   a kept Vow now does too. One Vow at a time. Four Vows as data. A Vow's
   Root is Ownership, a struck Root, because it is the Root that leaks in
   Veyr: this is the first law in the game that is not of the Canon, and
   nothing in the game says so yet.
6. **Cost:** standing matters only where laws collide, which in the slice
   is the Escort and little else. Until there are more contested laws the
   Resonance is the larger half of the reward. Enemies do not yet try to
   make a Vow fall. The stone's menu makes resting two presses, not one.
7. **Better because:** three things fell out for nothing, because a Vow is
   only a law: a strike Voss's Edict denies does not break a Vow against
   repeating; a blow a Debtor defers has not yet struck; a law the Writ of
   Licence refuses was never imposed.

## D-033. The Quarter's art pass: rule, not texture

1. **Changed:** the Quarter was blocks of flat colour. It is now dressed:
   walls coursed and jointed by a shader that reads world position, faces
   given plinth, cornice and pilaster by one function, a second light to
   model the shade, the hanging vows written as script, and two set pieces
   modelled by hand in script (the Hanging Courts, the fallen Oath Hall).
2. **Why:** three captures showed a place that composed well and looked
   unfinished, and three things that did not read at all: a city that was
   slabs, a ruin that was a dark mass, writing that was a dashed border.
3. **Alternative:** textures were refused. There is no texture artist, no
   image generation (0 credits), and the art direction is a ruled page,
   which a shader draws exactly. Sculpted set pieces were refused for the
   same reason the figures are scripted: a number can be changed and the
   model rebuilt.
4. **Play:** the ruin's stumps and drums are now things to walk round. The
   Hanging Courts hang directly over the Hall, so the fight with Voss
   happens under them.
5. **Technical:** one new shader (cannot be compiled headless), about 150
   more unsolid blocks in the district's one mesh, about 1,300 strokes of
   script in another, two models of 7,166 and 2,280 triangles. The Courts
   cast no shadow.
6. **Cost:** none of it has been seen in the game. Everything is still
   flat-shaded and hard-edged.
7. **Better because:** it is the look the art direction describes, made
   with the tools this project actually has.
