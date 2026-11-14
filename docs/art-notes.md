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
| Civilian A (woman, 40s, headscarf, shopping bag) | `assets/characters/civilian_a/civilian_a_{front,back}.png` | `.../civilian_a/display/` | `assets/characters/civilian_a/source/civilian_a_{front,back}.jpg` |
| Civilian B (elderly man, flat cap, tweed) | `assets/characters/civilian_b/civilian_b_{front,back}.png` | `.../civilian_b/display/` | `assets/characters/civilian_b/source/civilian_b_{front,back}.jpg` |
| Civilian C (young labourer, overalls) | `assets/characters/civilian_c/civilian_c_{front,back}.png` | `.../civilian_c/display/` | `assets/characters/civilian_c/source/civilian_c_{front,back}.jpg` |
| Woodcut icons | `assets/ui/woodcut/icons/<name>.png` (1024 sq, 64-colour palette): `action_{aid,expose,recruit,scavenge,listen,lay_low,see_teodor,diversion}`, `res_{cash,supplies,parts,people,legitimacy,heat}`, `tool_{smoke,lights_out,radio_call,flashbang}` | `assets/ui/woodcut/icons/display/<name>.png` (128 sq) | `assets/art/source/icon_<name>.jpg` |
| Painted backdrops (new, beside the old ones) | `assets/ui/backdrop_signal_box.png`, `backdrop_regime_painted.png`, `backdrop_liberated_painted.png` (1280x720). The old `backdrop_regime.png` / `backdrop_liberated.png` are untouched | | `assets/art/source/backdrop_<name>.jpg` |
| Street posters (woodcut) | `assets/ui/woodcut/poster_regime_continuity.png` (blue-grey), `poster_movement_unbroken.png` (red), 768x1024, 64-colour palette, blank text bands | | `assets/art/source/woodcut_poster_<name>.jpg` |
| Story stills | `assets/art/stills/{opening_raid_phone,teodor_dock,strike,safehouse_door,broadcast_airing}.png` (1280x720). The woodcut state-TV raid version is the existing `assets/ui/woodcut/opening_dormitory_raid.png` | | `assets/art/source/still_<name>.jpg` |
| Endings + kid's wall | `assets/art/endings/{district_turns,yards_silent,occupiers,captured,window_closes}.png`, `kids_wall_{bare,your_poster,over_regime}.png` (1280x720) | | `assets/art/source/ending_<name>.jpg` |
| itch page | `assets/art/itch/cover_630x500.png` (crop of the title woodcut), `banner_960x300.png` | | `assets/art/source/itch_banner.jpg` (cover source is `woodcut_title.jpg`) |

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

## 7. Background and scene art (approved Nov 14; done)

Duff approved the three painted drafts (Signal Box, regime street, liberated
street) and asked for the rest of the list to be filled without further sign-off.
Those three are the scene-art style anchors: HD-2D painted, near-monochrome
war-photojournalism grade, grain, crushed blacks, red the only warm accent.
Everything is in section 10. The district map stays dropped (art-needs says no
maps or UI layouts).

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

Everything else on art-needs was done in the third pass (icons, civilians,
section 9) and the fourth pass (scenes, posters, endings, itch, section 10). Stills and endings are background
art and wait for Duff's approval (section 7).

Known issues, second pass:
- The defector portrait has a small cut under one eye (no gore).
- The secrecy stamp has a thin warm-gold glow under the door, a slight third
  tone beyond paper / ink / red.
- The neutral, betrayed and resolved prompts needed one regen each: the first
  tries copied the reference pose too closely to read as a different emotion.

## 9. Third pass (Nov 14): icons and civilians

Done per art-needs:
- **Action icons** (8): aid, expose, recruit, scavenge, listen, lay low, see
  Teodor, diversion. **Resource icons** (6): cash, supplies, parts, people,
  legitimacy, heat. **Tool icons** (4): smoke, lights out, radio call, flashbang.
  All are woodcut on #E9E0CC with the same round carved border as the stamps,
  ink #1B1714 plus movement red only, no lettering or numbers. 1024 masters plus
  128 px display copies, so the 128 px copies can be checked for readability.
- **Optional civilians x3**, front and back, olive/brown, no red, no blue, faces
  visible: A is a woman in her 40s (headscarf, cardigan, shopping bag), B is an
  elderly man (flat cap, tweed jacket), C is a young labourer (overalls). Same
  cutout pipeline as the cast. Their raw sources are in each character's own
  `source/` subfolder (per Duff's note), not in `assets/characters/source/`.

Prompts, icons: "Square woodcut game UI <action|resource|tool> icon for <NAME>:
<one-object motif>, one bold simple silhouette that reads at small size,
inside a rough circular carved border matching the attached stamp. Thick carved
black lines (#1B1714) on cream paper (#E9E0CC), flat red #9E1A14 as the only
other colour, no blue. Visible wood grain and gouge marks. Absolutely no
letters, no words, no numbers, no text." Reference: the approved empty-boots
stamp.

Prompts, civilians: the cast sprite prompt (section 6) with "a neutral civilian
... Clothes ONLY in desaturated olive and brown ... NO red anywhere, NO blue
anywhere." Backs are made from each front plus the approved You back.

Regens: cash v1 had digit-like markings on the notes and was redrawn. Lights
out v1's lamp still looked lit and was redrawn with a dark lamp and a red lever.

Known issues, third pass:
- **expose** shows a small fedora-wearing watcher silhouette beside the torn
  poster. It reads as an informant, not as a regime officer.
- **supplies** has no red accent (ink only). It reads fine, but it is the only
  icon without one.
- **heat** uses red for the searchlight glow. Here red means danger, not the
  movement.
- **people** uses blank, simplified heads (no faces) with a red scarf.
- **diversion** has rusty-barrel tones that sit slightly warm beyond
  paper / ink / red.
- **lights out** v2: the lamp glass is dark but drawn open, not solid black.
- Civilian A's headscarf is charcoal. It is neutral, not blue, but check it
  under the cold grade.

## 10. Fourth pass (Nov 14): scenes, posters, endings, itch. List complete

**`docs/art-needs.md` is now complete.** Every item is ticked there. (Mapping for the earlier woodcuts: the State TV bulletin frame is `report_frame_cn24.png`, the pirate radio card is `report_frame_unbroken.png`, and the opening raid's woodcut state-TV still is `opening_dormitory_raid.png`.) Screenshots
and the GIF come from the engine, not from here.

What was made (all 16:9 paintings are 1280x720 PNG, upscaled with Lanczos from
the generator's output; full-size originals are in `assets/art/source/`):
- **Backdrops**: Signal Box (Depot yard at night), Dormitories regime (no red,
  the barrier is blue-grey/grey), Dormitories liberated (grey dawn, barrier down
  and kept red-and-white per Duff, red banner). They are saved as `_painted`
  files beside the old backdrops, so nothing that is already wired changes.
- **Posters**: the regime "Continuity" poster (a leader's head over a faceless
  crowd, blue-grey, never red) and the movement "Unbroken" poster (raised open
  hands, cranes, red sunburst). Both are woodcut with an empty text band.
- **Stills**: the phone-video raid aftermath (grainy, aftermath only, no people,
  no gore, no children), Teodor's dock at 2 a.m., the strike (Teodor on a cable
  drum, floodlight towers going dark), the safehouse door, and the broadcast
  airing (district screens showing the raid footage, residents stopping).
- **Endings**: district turns (warm morning crowd), yards go silent (idle
  cranes, red cloth banners with no lettering), occupiers (our people in visors
  and red armbands at the checkpoint, empty-handed), captured (an empty chair
  and a blue-grey woodcut poster of You with a black bar over the eyes), window
  closes (shuttered empty street, regime van back).
- **Kid's wall**: a child's chalk drawing (family, house, sun) with a bare wall
  above, then our movement poster pasted up, then our poster pasted over the
  torn regime poster. All three versions share one wall.
- **itch**: the cover is a 630x500 crop of the title woodcut. The banner is
  960x300, from a new wide woodcut panorama. Its left edge is padded with
  tiled paper texture from the same image.

Prompts (pattern; the exact references are listed):
- Scenes: "Wide 16:9 ... in exactly the same painted HD-2D style and grade as
  the attached <Signal Box | Dormitories> backdrop: <SCENE> ... Empty of people
  / <who> ... no weapons ... The image contains no text whatsoever." The Signal
  Box backdrop is the reference for the yard and dock; the regime street for
  the dormitories, raid, safehouse, broadcast, occupiers, window and kid's
  wall; the liberated street for district turns. The strike also uses Teodor's
  front sprite; occupiers uses the visor operative; captured uses the You
  anchor.
- Posters and banner: woodcut prompt (section 6) with the blue-grey report
  frame (regime) or the title woodcut (movement) as reference.
- Kid's wall 2 and 3 are edits of the bare wall, with the two posters attached.

Redraws (each checked for stray text, wrong colour and off-theme content):
- **Signal Box draft**: v1 had a graffiti tag, which was removed.
- **Regime street draft**: v1's barrier was red-and-white, which was recoloured
  blue-grey.
- **Phone raid**: v1 had red stains that read as blood, so they were removed
  and stronger phone grain was added.
- **District turns**: v1 printed the scene title as a caption, and the crowd
  wore robe-like costumes. It was redrawn with modern clothes and no text.
- **Yards go silent**: v1 printed the scene title as a caption, which was
  painted out.
- The itch banner's first crop was wrong (the source is 1280x720, not 1024),
  so it was redone.

Known issues, fourth pass:
- 16:9 paintings come from the generator at 1280x720 or smaller and are not
  4K. Re-render or upscale them before any high-resolution use.
- **Captured**: the poster of You copies the anchor's tattoos, ear gauges and
  bandana exactly. This is intentional (it identifies Duff), but the poster is
  more grey than blue-grey.
- **Broadcast airing**: FIXED (fifth pass). The two watchers who read as young teens are now clearly adults: a middle-aged man and a woman in her 30s.
- **Kid's wall**: FIXED (fifth pass). In all three versions the chalk is now off-white lines with a movement-red roof and heart. There are no pastels, and the regime poster stays blue-grey. In `over_regime`, one figure's faint blue fill was neutralised by hand (a local desaturation of the chalk only).
- **Strike**: FIXED (fifth pass). Teodor was redrawn against his approved sprite, with medium-dark brown skin, grey beard and beanie. The red rag stays, as Duff approved.
- **Liberated backdrop and district turns**: the fallen barrier keeps its red-and-white stripes (Duff's call; not part of the fifth-pass fix).
- **Occupiers**: FIXED (fifth pass). The barrier is now movement red with dark ink bands, with no white or candy stripes.
- **Regime poster**: the collar has faint carved marks. They read as texture,
  not lettering, at game size.
- **District turns**: one woman wears a dull blue apron. It is minor and not
  regime blue-grey.
- The `.import` files for the new PNGs are not committed. Godot will generate
  them when the editor next opens the project.

## 11. Fifth pass (Nov 14): four scene fixes approved by Duff

These were redrawn as image edits of the fourth-pass files, at the same paths
(this branch's own files only; nothing from main was overwritten):
`assets/art/stills/broadcast_airing.png`, `assets/art/stills/strike.png`,
`assets/art/endings/occupiers.png`, and `assets/art/endings/kids_wall_{bare,your_poster,over_regime}.png`,
plus their sources in `assets/art/source/`.
- Broadcast airing: the teen-looking watchers were replaced with adults.
- Kid's wall x3: the chalk is off-white plus movement red only. `over_regime`
  needed a second edit and a small hand desaturation of one figure's blue fill.
- Strike: Teodor was matched to his sprite (the sprite was attached as the
  reference; this took two edits, since the first barely changed his skin).
- Occupiers: the barrier is solid red with dark bands.
All were re-checked for stray text and off-palette colour, and none was found.
The occupiers barrier still alternates red with dark bands rather than being
one flat red. That fits "red with dark/ink", but say so if you want it flat.
