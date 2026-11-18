# 09. UI and UX specification

Status: **designed.** No interface exists.

## Principle: the interface is marginalia

The game world is the page. The interface is what a careful reader writes in
the margin: small, exact, in the reader's own hand. It never covers the
middle of the screen during play, and it is never glass, glow or chrome.

* Thin ruled lines, not boxes. Panels are opaque vellum with one ink rule.
* Type: a serif with small capitals for names of laws; a plain humanist sans
  for numbers and settings. Two weights. Nothing below 18 px at 1080p.
* Gold for what you own, vermilion for what is happening now, ink for
  everything else, a matte black bar for what you cannot yet read.
* Every law is shown as its sentence. Never an icon alone.
* Colour is never the only signal. Outcomes have distinct glyph shapes.
* All text scales to 150%. Shake, flash and hit-stop each have a setting.

## Combat HUD

| Element | Where | Content |
|---|---|---|
| Health and poise | Bottom left, two ruled lines | No numbers by default |
| Resonance | Along the Instrument-side edge, a column of ten gilt ticks | Ticks that would be spent by the current input are outlined |
| Your law | Above Resonance: the Thesis in small capitals, with its term as a ruled line shortening and its acts as pips | "Nothing may cross without permission  . . ." |
| Verdict line | At the point of contact, then stacks at left centre for 3 s | Outcome glyph, law name, reason in at most six words |
| Enemy laws | Above the locked target: one line per standing law | Unknown: a black bar. Sensed: its name. Read: its sentence |
| Lock-on | A small bracket, not a reticle | |
| Vow | Top centre while sworn | The vow's sentence, and what the Witness's word weighs. As built it is a strip of text with a gold rule; it does not yet crack when at risk |

The verdict line is the most important element in the game. It is what
turns a denied attack from "the game ate my input" into information. It is
built in the first combat milestone, before any other HUD element.

### Outcome glyphs

REJECTION: a bar across a stroke. OVERRIDE: one stroke over another.
CONTEST: two strokes meeting. CANCELLATION: two strokes, both broken.
CONVERSION: a stroke that turns a corner. Each is one continuous pen
mark and is readable at 24 px.

## Screens

| Screen | Purpose | Notes |
|---|---|---|
| Main menu | Continue, Chronicles, Codex, Settings | A blank page with one line of text per item and the last Chronicle's Thesis written at the foot |
| Character creation | The person, not the power | Appearance, voice, origin. No stats |
| Awakening | Choose one of three Axioms | Three pages side by side. Each: Root, Thesis, the Assertion's sentence, its price, its two answers, and **the evidence**: the moments that earned it |
| Codex: Axioms | Everything you know about every law met | Organised by Root. Unknown Roots are black bars; struck Roots show as scraped entries until discovered |
| Codex: Record | The verdict log of the last fight | Plain list, exportable as text |
| Instrument | The three forms, the moveset, fittings | No stats screen. Moves are shown as inputs and as what the law does with them |
| Revelation | Unveiling, Sovereignty, Paradox | Full screen, playable: the player performs the act that completes it |
| Quarter map | Hand-drawn district plan | Shows where you have been and who is looking for you. No icons to clear |
| Journal | What you were asked, by whom, in their words | No objective markers by default; an optional guide line |
| Progression | Mastery applications found, Doctrine tenets | A list of sentences, each a thing you did |
| Boss introduction | Name, title, one line | The boss's first law is shown as a black bar |
| Settings | Controls, display, sound, accessibility, difficulty of reading (verdict detail) | Rebinding for every action; hold-to-toggle options |

No inventory screen in the slice. There are no items except the flask.

## Controls (gamepad first, keyboard and mouse equal)

| Action | Pad | Keyboard and mouse |
|---|---|---|
| Move, camera | Sticks | WASD, mouse |
| Light, heavy | R1, R2 | LMB, RMB |
| Dodge | Circle | Space |
| Guard, parry | L1 | Shift |
| Impose (hold to commit) | L2 | Q |
| Inscribe | L2 + attack | Q + attack |
| Lock on | R3 | Middle mouse or Tab |
| Flask | Square | R |
| Interact | Triangle | E |
| Codex | Touchpad | C |

## Onboarding

No tutorial pop-ups. The prologue teaches movement and striking by needing
them. Each law is taught by a first enemy that carries only that law, in a
room where its answer is physically available. The Codex entry fills in as
the player sees it work.

## Acceptance checks for the interface

* A player who has never seen the game can say, after one denied strike,
  which law denied it.
* With colour vision deficiency simulation on, all five outcomes remain
  distinguishable.
* Nothing in the HUD is clipped at 16:10, 16:9 or 21:9.
