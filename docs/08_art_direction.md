# 08. Art direction bible

Status: **direction written. No images exist.** Image generation was checked
and is unavailable (0 credits). Prompts for the whole reference pack are in
`design/references/PROMPTS.md`.

## The idea: Illuminated Law

Eidolon looks like a world that was written, ruled, sealed and amended.
Not "dark fantasy". The reference frame is the illuminated legal manuscript
and the monumental courthouse: ruled lines, margins, seals, gold leaf,
vermilion ink, pale vellum stone, and the black of a struck-through line.

Three consequences follow, and they are what make the game recognisable in
one frame.

1. **Laws are drawn, not glowing.** An Axiom shows up as something a scribe
   could make: a ruled line, a seal, a tally mark, a gilt margin, a blot. It
   has edges. It does not look like energy.
2. **Architecture is typography.** Buildings are composed like pages: wide
   margins of blank stone, dense ornament only where authority sits,
   colonnades that read as ruled lines. Empty wall is a design element.
3. **What was struck is still visible.** A redaction bar, a scraped
   palimpsest, a gap where a statue was. The six struck Roots are in the
   world's art before the story names them.

The supplied tone image (a torch-lit gothic arena in rain) is a good
reference for scale and for warm against cold light. Its palette of black,
grey and red is exactly what VOWFALL should not default to.

## Rendering target

Stylised, not photoreal: strong shapes, hand-authored material ramps,
controlled detail. This is an art decision and a production one. It is what
one person with Godot on a laptop can make look deliberate.

## Colour

| Use | Colour | Rule |
|---|---|---|
| World ground | Vellum stone, warm pale grey | The largest area of every frame |
| Structure | Iron-gall ink, a blue-black | Shadows are ink, never neutral black |
| Authority | Gold leaf | Only on things that carry law: seals, Instruments, crowns |
| Act | Vermilion | Only for a law being imposed or a vow being sworn |
| Age | Verdigris | Bronze, water stains, the old city |
| Struck | Flat matte black bar | Never glossy, never glowing |

One accent per frame. A fight between two Sovereigns is the only time two
accents share the screen.

### Regions

| Severance | Light | Palette | Signature phenomenon |
|---|---|---|---|
| Veyr | High overcast, pale gold breaks | Vellum, verdigris, gold | Spoken vows hang in the air as written lines until kept |
| Mourning Wilds | Low sun through birch | Bone white, moss, faded rose | Translucent figures repeating one gesture |
| Stillwater | Dawn mist, flat water | Pewter, lamp amber | Buildings visibly nearer or farther than they were |
| Cathedral of Silence | Shadowless white | White on white, one black bar | No particles, no cloth movement, no echo |
| Ashen Expanse | Ember under slate | Charcoal, ember orange, new green | Ash falling upward where a fire has not finished |
| The Unwritten | Paper white fading to nothing | Graphite, blue pencil | Geometry that is still a sketch at its edges |

## Root visual identities

Not a colour each. Each Root has a motif, a material, a motion, a silhouette
and a sound. Any two must be distinguishable in greyscale and with the sound
off, and again with the picture off.

| Root | Motif | Material | Motion | Silhouette | Sound |
|---|---|---|---|---|---|
| Threshold | Ruled line, lintel, hinge | Brass rule on stone | Snaps straight, then is perfectly still | A hairline with two end-marks | A latch; a held breath |
| Debt | Tally marks, beads, a balance | Counting-beads, wax | Slides, clicks, locks | Hanging beads, tilting beam | Abacus clicks, a coin settling |
| Reflection | Bilateral fold, silvering | Mirror-polish, folded ink blot | Opens like a book from a centre line | Symmetrical pair | The same note twice, the second reversed |
| Identity | A name written and overwritten | Wet ink over dry | Text that re-letters itself | A label that does not match its object | A voice saying a word that changes mid-syllable |
| Permission | Seal, stamp, signature | Red wax, pressed lead | One heavy downward impact | Disc on a field | A stamp; a door bolt |
| Hunger | A margin being eaten | Moth-holed vellum | Edges recede toward a centre | A shape with a bite out of it | Paper tearing slowly |
| Ruin | Foxing, cracking gilt | Flaking gold, rust bloom | Spreads from a point, never retreats | Fracture web | Dry cracking, a dropped tile |
| Continuity | A line that carries over the page | Thread, stitched binding | Does not stop when its cause stops | A stitch crossing a gap | A sustained note held past its bar |
| Silence | Blank margin | Felt, unmarked vellum | Things entering it lose their trails | A clean rectangle of nothing | Everything else ducking out |
| Revelation | Marginal gloss, pointing hand | Gold leaf catching light | A beam that underlines | A manicule; an underline | A single bright bell |
| Gravity | Plumb line, weighted cord | Lead, taut string | Everything leans to one point | Converging verticals | A low string, rising in tension |
| Velocity | Stroke speed: a fast pen line | Dry-brush ink | Streaks that thin as they slow | Tapering stroke | A quill flick; air |
| Absence | Redaction bar | Matte black | Appears complete, with no build-up | A hole in the picture, hard-edged | A cut in the audio |
| Ownership | Signet, bookplate, brand | Stamped leather | A mark that appears on what is taken | An object wearing someone's seal | A key turning |
| Adaptation | Correction over correction | Layered ink of different ages | Redraws itself after each hit | The same shape, slightly changed | A phrase repeated with one note altered |
| Memory | Palimpsest | Scraped vellum, ghost text | An earlier image shows through, off-register | A double exposure | A sound heard a moment before its source |
| Distance | Scale bar, map fold | Folded paper | Space creases and two points touch | A fold line across the scene | A far sound suddenly near |
| Possibility | Draft lines, alternatives | Pencil under ink | Several outcomes sketched, one inked | A figure with ghost outlines | A chord resolving two ways at once |

## Characters

* Silhouette first. Every named character must be identifiable as a black
  shape at thumbnail size.
* Clothing is cut cloth and bound cord, not plate. Rank is shown by seals and
  by how much blank space a costume is allowed.
* Faces are specific and unglamorous. No interchangeable heroes.
* Faction language:

| Faction | Shape | Material | Mark |
|---|---|---|---|
| Meridian Court | Long verticals, stoles | Wool, lead seals, gold | A meridian line through a circle |
| Crownless | Asymmetric, mended | Canvas, knotted cord | A crown outline, struck through |
| Pale Archive | Layered, pocketed | Linen, ink stains, vellum strips | An open bracket |
| Hollow Choir | Smooth, featureless, veiled mouth | Felt, undyed | An empty staff of music |
| Unbound | Travelling layers, nothing tied in a knot | Felted wool, wood toggles | None. They wear no mark |

### The figures as built (2026-11-11)

Stage figures: 1.86 m, long-limbed, small-headed, in cut cloth with no plate.
Faces are a brow, a nose and two dark slits, or are hidden altogether (the
Bailiff's helm). Colour is flat and from the palette above; there are no
textures. Each is built by a script (`tools/blender/characters.py`), so a
change of costume is a change of numbers. Review renders:
`docs/screenshots/models/`. They replaced a cute placeholder pack the owner
rejected (D-022).

## Effects rules

* An effect has an edge. No soft additive fog as a default.
* An effect appears in at most 6 ticks and is readable at its first frame.
* An effect says who owns it: the owner's fitting colour appears in it once.
* Screen-filling effects are reserved for Edicts and the three Revelations.
* Budget: 20,000 particles on screen, two shadow-casting lights.

## Asset classes (kept in separate folders, never mixed)

| Class | Folder | May ship? |
|---|---|---|
| External reference (someone else's image) | Not stored. Links only, in a text file | No |
| Generated concept image | `design/references/` | No. Direction only |
| Placeholder (CC0 packs, retargeted clips) | `game/assets/placeholder/` with a licence file | Only if the licence allows and it is credited |
| Production asset | `game/assets/` | Yes |

## Reference pack: order of work once generation is available

1. Master key art. 2. The Witness. 3. The Assize Quarter. 4. The Lintel,
Tally and Counterpart sheets. 5. Threshold, Debt and Reflection effect
boards. 6. Unveiling board. 7. Aurel Voss and the Hall of Standing. 8. HUD
and Codex. Then the remaining boards in the Directive's list.
