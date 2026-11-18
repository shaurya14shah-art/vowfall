# 02. Master game design

The top-level document. Where another document disagrees with this one, this
one is wrong only if `DECISIONS.md` says so.

## One sentence

A third-person action RPG in which your power is a law you wrote, your enemy's
power is a law they wrote, and the fight is won by whoever understands both.

## Pillars

1. **A power is a sentence.** Every Axiom can be stated in one line, has a
   condition, a price, an end, and at least two answers. If it cannot be
   stated, it does not ship.
2. **Read, then break.** The best moment in the game is "I understand what
   this opponent is doing." Encounters are built to produce it.
3. **Hands and laws.** Weapon skill and Axiom skill are one system. A law is
   usually imposed *through* a strike, a step or a parry, never from a menu.
4. **Becoming, not levelling.** The three Revelations change what you can do
   and what you are. No transformation is a number going up.
5. **Small and dense.** One district you know by heart beats a map you fast
   travel across.

## The loop

Minute to minute: move, strike, read the verdict line, adjust.
Encounter to encounter: meet a rule you have not seen, lose to it or scrape
through, read it in the Codex, come back with an answer.
Hour to hour: a personal quest that tests your Thesis, a faction that wants
your testimony, a Revelation that changes your kit.
Chronicle to Chronicle: a different law, the same world, and a Codex that
already knows what you learned last time.

## Terms (the only definitions; other documents use these)

| Term | Meaning |
|---|---|
| Root | One of eighteen foundational concepts. Twelve are taught, six were struck |
| Thesis | Your one-line belief about your Root |
| Assertion | The rule you can impose. In the engine: a *law definition* |
| Expression | A way of using your Assertion in combat (an input that imposes, inscribes or counters) |
| Edict | Your highest law. Field-wide, counted in acts, binds you too |
| Condition | What must be true for your law to hold |
| Price | What it costs: Resonance up front, and what breaks it |
| Instrument | Your bound weapon. A moveset frame plus what it does for your Assertion |
| Doctrine | Which engine property you have trained: Authority, Persistence, Trigger or Chain |
| Resonance | The one combat resource for laws. Earned with your hands |
| Verdict | What the Law Engine decided about an event, with its reason |
| Vow | An optional promise sworn at a vow-stone. A self-imposed rule with a reward |
| Chronicle | One playthrough: one character, one Axiom, one set of consequences |
| Codex | What you know, kept across Chronicles |
| Severance | A region where a standing law with no living author holds |

## The three Revelations

| Stage | What changes | Engine meaning | Status |
|---|---|---|---|
| Unveiling | The Instrument wakes; your Assertion loses a limit or gains a clause | The law resolves in its `UNVEILED` form | Rules implemented and tested for five of six Assertions. No presentation |
| Sovereignty | You can speak an Edict | A tier-4 law: outranks Techniques by two tiers | One Edict implemented (the boss's). Player Edicts designed |
| Paradox | Your Thesis turns over. One slot of your Assertion changes (operation, subject or trigger) | A second definition replacing the first | Designed |

Paradox is deliberately one slot, not a new kit (D-008). Gatekeeper: "nothing
may cross without permission" becomes "a boundary nothing crosses has no
other side": the line stops being placed and starts being carried. That is one
field in the data and a different way to play.

## Progression

No experience levels and no stat tree. Four things grow.

* **Mastery** of your Assertion, earned by using it in distinct situations
  (the Codex lists them as "applications found"). Each rank adds 1 authority.
* **Doctrine**, chosen at Unveiling and changeable at cost. One tenet per
  Expression slot.
* **The Instrument**, through the three forms and through moveset additions
  earned in trials. Never through item stats.
* **Standing** with factions, which opens quests and closes none.

Health, poise and Resonance caps grow a little at each Revelation and nowhere
else. Difficulty comes from rules, not from enemy health.

## Vows (new, D-010)

Veyr's standing law is that a vow spoken before a witness binds. At a
vow-stone you may swear one before an encounter: "I will not be struck from
the front." "I will not repeat a strike." Keep it and the reward is yours.
Break it and the vow falls: you pay its forfeit on the spot. Vows are the
difficulty system, the challenge mode and the title, and in the engine they
are ordinary laws with the player as author and subject.

## Replayability

* **Chronicles:** a new character, a different awakening, a different quest
  for the Thesis, different faction outcomes.
* **The Codex of the Unwritten** keeps knowledge: every law you have Read
  stays Read. A boss whose Writs cost you an hour in one Chronicle is
  legible from the first second in the next. That is the reward for
  understanding, and it is not power.
* **Struck Roots** become available to awaken with once the Codex holds the
  discovery that proves they exist.
* **The Assize:** a replayable arena where Vows stack as modifiers.
* **Rematches:** every Sovereign can be re-fought with their Unveiled laws.
* **Interaction log sharing:** the engine's records are plain data. A fight
  can be exported as a list of verdicts. This is the hook for a community
  that trades discoveries, and it costs nothing extra to build.

No loot grind, no random stats, no level reset.

## What the game is not

No gacha, no paid power, no stamina-gated exploration, no map icons to clear,
no crafting, no class selection screen, no cooldown bar.

## The slice: "The First Severance"

One district of Veyr (the Assize Quarter), three Roots, six Assertions, three
Instruments, Unveiling, Aurel Voss, one personal quest, one faction line, the
Assize. Target length: two to three hours first time, replayed three times to
see it properly. Acceptance criteria and their current state are in
`STATUS.md`.
