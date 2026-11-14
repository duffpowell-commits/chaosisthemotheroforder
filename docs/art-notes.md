# Art notes: The Rail Yards slice

Art team pass, Nov 14 2026. Duff approved the style and the first draft round
(You, guard, Mara, Kesh, Teodor fronts) on Nov 14 and asked for the rest in the
same style. **Background / environment art is on hold until Duff approves the
plan at the bottom of this page.**

Everything here is new files only. No code, scripts, scenes or rig data were
changed, and no existing wired path was overwritten (see "Rig" below).

## 1. Style bible (approved)

- **Look:** semi-realistic painted graphic-novel / comic art. Thin dark ink
  outline, slightly thicker around the whole silhouette; light crosshatching;
  realistic painted shading on faces, skin, denim and leather; light from the
  upper left.
- **Pose (sprites):** full body, three-quarter front (or back) view, A-pose with
  arms angled out and a clear gap between each arm and the torso, hands open,
  relaxed and **empty** (weapons are drawn in code), legs slightly apart, feet
  visible.
- **Background (sprite sources):** plain flat light grey, no ground shadow, no
  text, no scenery. 3:4 aspect.
- **Anchors (attach to every character prompt):**
  `assets/characters/source/you_front_anchor.jpg` and
  `assets/characters/source/you_back.jpg` (also used as the Duff/You fronts and backs).
- **Faction rules:** regime = dark blue-grey riot gear, full helmet, visor down,
  no face, never red. Movement = street clothes, one red item, face visible.
  Civilians = olive/brown, no red, no blue. Human cast only.

## 2. Palette

| Use | Hex |
|---|---|
| Regime uniform | `#1A1F2B` |
| Regime visor glint | `#6A8CB3` (never red) |
| Movement red (bandana, armband, scarf, cap) | `#9E1A14` |
| Woodcut paper / ink | `#E9E0CC` / `#1B1714` |
| Civilian clothing | desaturated olive / brown / charcoal |

Woodcut pieces use paper + ink + **one** of: movement red `#9E1A14` *or* regime
blue-grey `#1A1F2B`. Never both on the same piece.

## 3. File map

Sprites live in **per-character subfolders** so nothing collides with paths the
code already loads.

| Asset | Master (~1024 px tall, transparent) | Display (128 px tall) | Raw source (grey bg) |
|---|---|---|---|
| You / Duff | `assets/characters/duff/duff_{front,back}.png` | `assets/characters/duff/display/duff_{front,back}.png` | `assets/characters/source/you_front_anchor.jpg`, `you_back.jpg` (already in repo) |
| Riot guard | `assets/characters/guard/guard_{front,back}.png` | `.../guard/display/` | `assets/characters/source/guard_{front,back}.jpg` |
| Guard, helmet off (defector) | `assets/characters/guard_defector/guard_defector_front.png` | `.../guard_defector/display/` | `source/guard_defector_front.jpg` |
| Visor-down movement operative (dark endings) | `assets/characters/visor_operative/visor_operative_front.png` | `.../visor_operative/display/` | `source/visor_operative_front.jpg` |
| Mara | `assets/characters/mara/mara_{front,back}.png` | `.../mara/display/` | `source/mara_{front,back}.jpg` |
| Kesh | `assets/characters/kesh/kesh_{front,back}.png` | `.../kesh/display/` | `source/kesh_{front,back}.jpg` |
| Teodor | `assets/characters/teodor/teodor_{front,back}.png` | `.../teodor/display/` | `source/teodor_{front,back}.jpg` |
| Operative A (red scarf) | `assets/characters/operative_a/operative_a_{front,back}.png` | `.../operative_a/display/` | `source/operative_a_{front,back}.jpg` |
| Operative B (red flat cap) | `assets/characters/operative_b/operative_b_{front,back}.png` | `.../operative_b/display/` | `source/operative_b_{front,back}.jpg` |
| Operative C (red armband) | `assets/characters/operative_c/operative_c_{front,back}.png` | `.../operative_c/display/` | `source/operative_c_{front,back}.jpg` |
| Portraits | `assets/portraits/<name>_<emotion>_{cold,warm}.png` (768 px): duff_{neutral,angry,tired}, teodor_{guarded,betrayed,resolved}, mara_{calm,worried}, kesh_{suspicious,scared}; plus `defector_helmet_cold.png` (cold only) | | `assets/art/source/portrait_<same name>.jpg` (1024 px originals) |
| Woodcut UI | `assets/ui/woodcut/title.png`, `report_frame_cn24.png`, `report_frame_unbroken.png`, `opening_dormitory_raid.png` (1024x576), `stamp_{blackmail,the_lie,fake_radio,killing_guards,secrecy,clean_slot,lay_low}.png` (1024 sq; `lay_low` is extra, not on the art-needs list) | | `assets/art/source/woodcut_<name>.jpg` (full-size originals); PNGs are 64-colour palette, no dithering |

### Operative sheets → recruit names

The three generic recruit sheets cover the eight names in `scripts/sim/rules.gd`.
Suggested mapping (swap freely; tint the red item or hair in engine for variety):

| Sheet | Who | Covers |
|---|---|---|
| `operative_a` | woman, late 20s, short dark bob, nose stud, olive work jacket, **red knit scarf** | Ilse, Yusra, (Lida) |
| `operative_b` | man, mid 40s, dark brown skin, shaved head, beard, corduroy jacket, **red flat cap** | Dov, Sami, Oren, Pell |
| `operative_c` | woman, late 50s, silver hair, glasses on head, long dark coat, **plain red armband** | Renata, Lida |

### Cutout process

`rembg` (`isnet-general-use`) mask, then: drop near-background-grey pixels that
aren't solid (removes the faint ground shadow), keep the main component, fill
only tiny interior holes (the arm/torso gaps stay open), tight crop with 6 px
padding, Lanczos resize to 1024 px tall (master) and 128 px tall (display).
Checked by compositing on black and white.

## 4. Rig: re-jointing needed

`assets/characters/duff_front.png` is the 47x128 placeholder wired into
`cutout_rig.gd`, with joint positions in 72x196 space. **It was deliberately not
replaced.** The new art is in `assets/characters/<name>/`. To switch the rig to
the new art, each sprite needs its own joint map (neck, shoulders, elbows,
wrists, hips, knees, ankles) measured on the new canvas; the old joint numbers
won't line up. That is a code change and is left for a separate PR.

## 5. Known issues

- **Mirroring breaks asymmetric details.** Don't flip sprites to fake the other
  facing: Duff's mandala sleeve (left arm) / illustrative right arm / fox on the
  neck, Mara's left armband, Teodor's back-pocket rag and Operative C's armband
  would all swap sides. Use the drawn back view instead.
- **design.md / character-prompts.md are out of date on Duff:** they still say
  "wolf with a blue rose" on the neck, a band t-shirt and generic plugs. The
  approved look is a **geometric fox** neck tattoo, **round plugs**, **plain
  black tee**, mandala blackwork left sleeve, illustrative right arm (blue rose
  on the right forearm).
- **Mara's armband has a white medic cross** (front, back and both portraits).
  Approved as-is, but it reads as "medic" more than "movement". Paint it out if
  you want a plain red band.
- **Kesh and Teodor read lighter-skinned than their briefs** in the approved
  fronts. Backs and portraits follow the approved fronts; Teodor's portraits were
  pushed a little darker (one regen) but are still lighter than "deep dark
  brown". Kesh's thin moustache didn't come through; he got a bandana instead of
  a scarf and a beanie as briefed.
- Teodor's cigarette behind the ear is missing (as in the approved front).
- Guard back/defector show a thigh holster pouch. No weapon is drawn.
- Operative C's armband ended up on her left arm (brief said right); it's
  consistent front and back.
- The guard defector front needed one regen (the first pass copied Duff's
  tattoos and short sleeves). Operative A needed one regen (mustard jacket
  competed with the movement red). Operative C needed one regen (a black star
  emblem on the armband).
- Woodcut pieces are 1024 px wide. Fine for phone; upscale or regenerate larger
  before any desktop/4K title screen.
- The title piece has no carved band reserved for the title; the open sky in
  the upper left is the intended text area.

## 6. Prompts used (exact)

Shared sprite tail (appended to every sprite prompt below as **[TAIL]**):
> Semi-realistic painted graphic-novel comic style matching the attached images:
> thin dark ink outline slightly thicker around the whole silhouette, light
> crosshatching, realistic painted shading, light from the upper left. Full body,
> isolated on a plain flat light grey background, no ground shadow, no text, no
> weapons.

Back-view pose clause (**[BACK]**): "turned around, three-quarter back view seen
from behind and slightly to one side, same A-pose with arms angled out leaving a
clear gap from the torso, hands open and empty, legs slightly apart, feet visible."

Front pose clause (**[FRONT]**): "Three-quarter front view, A-pose with arms
angled out leaving a clear gap from the torso, hands open and empty, legs
slightly apart, feet visible."

All sprite prompts: aspect 3:4. References in brackets.

**guard_back** [guard front + you back]:
> Same character, same style as the first attached image (regime riot guard):
> [BACK] Full dark blue-grey (#1A1F2B) riot armour from behind: back of the
> full-face helmet, padded shoulders, back plate, belt, shin guards, no face or
> skin visible, no red anywhere, no insignia on the back. [TAIL]

**mara_back** [mara front + you back]:
> Same character, same style as the first attached image (Mara, woman late 30s,
> dark hair in a low bun, dark green field jacket, grey hoodie, cargo trousers,
> worn boots, canvas shoulder bag, red armband on her LEFT arm): [BACK] From
> behind: the low bun with loose strands, hood of the grey hoodie over the jacket
> collar, bag strap across her back with the bag at her hip, the red armband
> (#9E1A14) still on her left arm. [TAIL]

**kesh_back** [kesh front + you back]:
> Same character, same style as the first attached image (Kesh, wiry young man
> early 20s, messy black curls under a black beanie, dark olive bomber jacket,
> dark tee, slim dark jeans, grey high-top sneakers, red scarf/bandana at his
> neck): [BACK] From behind: curls poking out under the beanie, the red (#9E1A14)
> scarf knot visible at the back of his neck, bomber jacket back with ribbed hem. [TAIL]

**teodor_back** [teodor front + you back]:
> Same character, same style as the first attached image (Teodor, broad
> heavy-shouldered dock foreman in his 50s, dark knit cap, heavy dark canvas work
> jacket with grey reflective stripes over a grimy vest, dark work trousers,
> steel-toe boots, red rag tucked in his back pocket): [BACK] From behind: back
> of the knit cap and close-cropped grey hair, the reflective stripes across the
> jacket back, the red (#9E1A14) rag hanging clearly from his back trouser pocket. [TAIL]

**guard_defector_front** (v2, used) [guard front only]:
> Same character and same style as the attached image (regime riot guard in full
> dark blue-grey #1A1F2B riot armour with long sleeves, padded shoulders,
> armoured forearms, gloves, chest number patch, belt, knee and shin guards,
> black boots), but the DEFECTOR variant: the helmet is gone, his head is bare.
> Tired, ordinary human face: a man in his late 20s, pale, short cropped brown
> hair flattened and sweaty from the helmet, a faint pressure line on the
> forehead from the helmet rim, light stubble, dark circles under his eyes,
> uncertain exhausted expression. Armour exactly as in the attached image, fully
> covering arms and neck; NO tattoos anywhere, no bare arms, no red cloth.
> [FRONT, gloved hands] [TAIL]

**visor_operative_front** [you front + guard front]:
> Same art style as the attached images, a different character: a movement
> operative in a dark ending who has started to look like the regime. Street
> clothes: a worn dark charcoal hoodie, dark jeans, scuffed black boots, a faded
> red (#9E1A14) armband on the left upper arm, but wearing the regime's
> full-face dark blue-grey (#1A1F2B) riot helmet from the attached guard image
> with the visor DOWN and a cold blue glint (#6A8CB3) on the visor, so no face is
> visible. Unsettling mix: civilian body, faceless regime head. [FRONT] [TAIL]

**operative_a_front** (v2, used) [operative_a v1 + you front]:
> Same art style, line weight, shading and lighting as the attached image, but a
> different character: movement operative A, a woman in her late 20s, slim, mixed
> East-Asian features, short choppy dark bob haircut, small silver nose stud,
> alert determined expression, face fully visible. Street clothes in muted
> desaturated colours: a worn olive-drab canvas work jacket over a grey knit
> sweater, dark grey trousers, worn brown lace-up boots, and ONE red item: a red
> (#9E1A14) knit scarf wrapped around her neck. The scarf is the only warm
> colour. Grounded, practical, slightly grimy. [FRONT] [TAIL]

**operative_b_front** [you front]:
> Same art style, line weight, shading and lighting as the attached image, but a
> different character: movement operative B, a man in his mid 40s, stocky, dark
> brown skin, North-African features, shaved head, short black-and-grey beard,
> steady weary expression, face fully visible. Street clothes: a brown corduroy
> jacket over a dark green work shirt, grey cargo trousers, scuffed black work
> boots, and ONE red item: a red (#9E1A14) flat cap. Grounded, working-class,
> slightly grimy. [FRONT] [TAIL]

**operative_c_front** (v2, used) [operative_c v1]:
> v1: Same art style ... movement operative C, a woman in her late 50s, sturdy,
> pale weathered skin, silver-grey hair cut short, reading glasses pushed up on
> her head, wry resolute expression, face fully visible. Street clothes: a long
> dark navy-brown wool coat, unbuttoned, over a cream turtleneck, brown trousers,
> sensible dark ankle boots, and ONE red item: a red (#9E1A14) armband on her
> right upper arm over the coat sleeve. Grounded, ordinary neighbourhood elder.
> [FRONT] [TAIL]
> v2: Same character and same style as the attached image ..., identical in
> every way except the armband on her upper arm is now a PLAIN solid red
> (#9E1A14) cloth band with no symbol, no emblem, no star, no pattern. [FRONT] [TAIL]

**operative_{a,b,c}_back** [that operative's front + you back]:
> Same character, same style as the first attached image ([one-line recap of
> the front]): [BACK] From behind: [the red item and hair as seen from behind]. [TAIL]

### Portraits (1:1)

Second pass: extra emotions use the character's first cold portrait as the reference, with "same chest-up three-quarter framing ... but [EMOTION]". Where that came out too close to the reference (neutral, betrayed, resolved), the regen asked for "a clearly DIFFERENT pose" plus a gesture: Duff neutral with arms folded, looking at the viewer; Teodor betrayed pointing; Teodor resolved with a gloved hand at his collar, cranes behind. Defector: the guard_defector sprite as reference, "holding his removed full-face riot helmet against his chest in both gloved hands ... shaken, uncertain, on the edge of a decision ... No red anywhere." Warm versions are made from each cold one as before.

Cold, [that character's sprite front]:
> Chest-up portrait of the attached character ([recap]), three-quarter view,
> looking just off camera, [EMOTION]. Painterly oil style, visible brush
> strokes, dramatic single light source from the side, deep shadow on the far
> side of the face, desaturated blurred night street behind. COLD GREY version:
> cold blue-grey near-monochrome palette, regime district mood, the red [item]
> the only warm note. Documentary mood, not glamour. No text.

Emotions: Duff "tired and steady"; Mara "calm and tired, kind but hard eyes";
Kesh "alert and suspicious, shoulders slightly hunched"; Teodor "unimpressed and
watchful" (v2 used: added "deep dark brown skin", referenced v1 for composition).

Warm, [that character's cold portrait]:
> The same portrait as the attached image ([recap], same pose and composition),
> repainted as the WARM AMBER version for a liberated district: warm amber and
> sodium-orange side light on his/her face, softer glow, the blurred night
> street behind now lit with warm windows and amber streetlamps, colour
> returning. Same expression [+ small softening]. Painterly oil style, visible
> brush strokes, deep shadow on the far side of the face. Documentary mood, not
> glamour. No text.

### Woodcut (no references)

Every woodcut prompt ends with: "Thick carved black lines (#1B1714) on cream
paper (#E9E0CC), [flat red #9E1A14 | flat cold blue-grey #1A1F2B] as the only
other colour, no [blue | red]. ... Absolutely no letters, no words, no numbers,
no text. Visible wood grain and gouge marks."

- **title** (16:9, red): a lone figure in street clothes with a bandana at his
  neck standing on a rail-yard footbridge, seen from below in heroic 1930s
  protest poster composition, rail tracks and freight cars converging behind
  him, a dormitory block skyline, a single red flag-like cloth caught in the
  wind; large empty band across the top third for the in-engine title.
- **report_frame_cn24** (16:9, blue-grey): ornate cold official border; a
  stylised CRT television whose screen is a large EMPTY cream rectangle;
  broadcast antenna rays; rows of faceless helmeted riot police along the
  bottom; monumental government building at the top corners; an eye-like lens
  emblem; blank ribbon banner top and blank strip bottom for text.
- **report_frame_unbroken** (16:9, red): rough hand-carved border; battered
  valve radio and rooftop wire antenna sending jagged waves; a hand holding up a
  microphone; rail tracks and dormitory rooftops at the bottom; a red bandana
  tied to the mast; EMPTY centre rectangle and blank ribbon banner.
- **opening_dormitory_raid** (16:9, blue-grey): state-TV still of a night
  dormitory raid; helmeted faceless riot police storming a dormitory stairwell,
  a door kicked in, residents in nightclothes pushed back, searchlights from a
  police van; no weapons fired, no gore; blank band along the bottom for a caption.
- **stamp_*** (1:1, red): circular carved stamp border with a blank ring for text.
  blackmail = a hand sliding a sealed envelope across a table while another hand
  closes over cargo-manifest papers; the_lie = a handshake with crossed fingers,
  barred prison window behind; fake_radio = valve radio wearing a grinning
  theatre mask, jagged waves; killing_guards (v2, empty boots per art-needs) = a pair of empty heavy riot-police boots alone on cobblestones, laces loose, a dropped red cloth band beside them, no body, no blood, no weapons; secrecy = a heavy closed dormitory door with a chain lock, a line of light under it, a small red cloth on the handle; clean_slot = a single open empty hand, palm up, radiating carved lines, thin red ring; lay_low = a figure in a cap and bandana crouched under a dormitory
  stairwell while a searchlight passes above.

## 7. Background art plan (PENDING DUFF'S APPROVAL; not started)

Nothing below has been generated. (The woodcut district map was dropped: `docs/art-needs.md` says don't generate maps or UI layouts.) Same palette rules; woodcut pieces get one
accent colour each. Proposed order:

1. **Mission backdrop, the Signal Box** (`assets/ui/backdrop_signal_box.png`):
   Depot yard at night, containers, crates, gantry, signal box. Painted to match
   the Frontline grade (near-monochrome, sodium light).
2. **Ending scenes**, one per ending, regraded by result:
   the district turns (full colour), the yards go silent (strike, idle cranes),
   occupiers (cold, our people in visors), captured, the window closes. Includes
   the **kid's wall** scene (a child's chalk drawing on a dormitory wall).
3. **Street posters as scenery**: regime Continuity posters (blue-grey) and
   Unbroken wall posters (red), as woodcut decals with blank text space.
4. **Replacements for `assets/ui/backdrop_regime.png` / `backdrop_liberated.png`**
   in the new painted style (would be new files beside them, not overwrites,
   until the scenes are switched over).

## 8. Against `docs/art-needs.md` (second pass, Nov 14)

Done per art-needs:
- **Portraits** follow its emotion list, named `<name>_<emotion>_<cold|warm>`:
  You (neutral, angry, tired), Teodor (guarded, betrayed, resolved), Mara (calm,
  worried), Kesh (suspicious, scared). Cold grey for regime weeks, warm amber for
  liberated endings. The first-pass portraits became the tired / guarded / calm /
  suspicious sets (renamed, not redrawn).
- **Defector portrait, helmet in hand**: `defector_helmet_cold.png`. Cold only;
  art-needs asks for one, for the Persuade beat.
- **Stamps**: killing is redrawn as **empty boots** (replaces the empty helmet).
  **secrecy** (closed, chained door) and **clean slot** (open hand) are added.
  **lay_low** is kept but is extra (not on the list).
- **Sources**: non-cast originals are in `assets/art/source/` (`portrait_*.jpg`,
  `woodcut_*.jpg`). Cast sources stay in `assets/characters/source/`.

Still open from art-needs: regime and movement posters, action / resource / tool
icons, the phone-video raid still, story stills, endings, the kid's wall, itch
cover and banner, and the optional civilians. Stills and endings are background
art and wait for Duff's approval (section 7).

Known issues, second pass:
- The defector portrait has a small cut under one eye (no gore).
- The secrecy stamp has a thin warm-gold glow under the door, a slight third
  tone beyond paper / ink / red.
- The neutral, betrayed and resolved prompts needed one regen each: the first
  tries copied the reference pose too closely to read as a different emotion.
