# Face Off — Asset Prompt Pack

Everything the game needs drawn, with the prompt to generate it. Pair this with
`shared/art/manifest.json`, which is the machine-readable index the art-integration pass
reads — same asset ids, so the two files must stay in sync.

The reference app that inspired this look is copyrighted. Nothing here asks for a copy of it;
these prompts describe our own palette and art direction (`FACE_OFF_PRD.md` §6), which already
called for "rounded vector illustration, high-saturation flat colours with a single soft
shadow."

---

## How to generate these (read this first)

**1. Establish a style seed before anything else.**
Generate `char/basketball_p1` first. Judge it hard — outline weight, head-to-body ratio, eye
style. Once one character looks right, **attach that image to every subsequent prompt** and
add: *"Match the exact art style, outline weight, and proportions of the attached image."*
Sixty independently-prompted images will not look like one app; sixty seeded ones will.

**2. Never prompt the P2 variant from scratch.**
Generate the P1 character, then upload it back and ask:
> *Recolour this exact character to a teal `#22B8CF` kit — same pose, same linework, same
> proportions, only the uniform/kit colour changes. Keep skin, hair and equipment as they are.*

If you re-prompt P2 from the text, the two players will differ in build and pose, and Face Off's
one non-negotiable rule is that both players get identical visual weight.

**3. Output format.**
PNG with a **transparent background** for everything except scene backgrounds (which are opaque
and full-bleed). Sizes are listed per asset. If the generator only emits square images, generate
square and crop — do not letterbox with visible bars.

**4. Say no to what ChatGPT likes to add.**
Every prompt below ends with the style block, which already forbids gradients, gloss, 3D
shading, text, watermarks and borders. If an image comes back with a soft airbrush gradient or a
drop-shadowed rectangle background, regenerate — those two ruin the flat-sticker read more than
anything else.

**5. Where to put the files.**
Exactly at the `path` in `manifest.json`, relative to the repo root. A missing file is a data
problem the integration pass reports; a misnamed one silently doesn't load.

---

## THE STYLE BLOCK

Append this verbatim to the end of **every** prompt below.

> Flat vector cartoon illustration, funky and chunky. Bold rounded shapes, one even-weight dark
> navy `#1D2B36` outline around every form, high-saturation flat fills. **No gradients, no
> gloss, no highlights, no texture, no 3D shading, no realism.** A single soft drop shadow
> beneath the subject only. Big-headed cute character proportions, simple dot eyes, small
> smile, stubby limbs, no individual fingers. Playful but not babyish — it should read for a
> 25-year-old as much as a 7-year-old. Colour palette: coral `#FF5A5F`, teal `#22B8CF`, cream
> `#FFF4E0`, off-white `#FFFDF7`, dark navy ink `#1D2B36`, gold `#FFC857`, mint `#4ECB8D`.
> Transparent background. Subject centred, entire form visible, even margin on all sides. No
> text, no lettering, no numbers, no watermark, no UI elements, no frame or border.

**Scene backgrounds override two lines of it:** they are *opaque, full-bleed, no transparent
background, no centred subject, no margin.* Each background prompt says so inline.

---

## 1. Sports game art

Six games. Each needs a scene background, a character in P1 and P2 kits, and its props.
Characters are drawn **facing right and viewed from the side** unless noted — the game mirrors
them in code, so never generate a left-facing variant.

### Basketball
Two half-courts, one per player; each player flicks to shoot at their own hoop.

- **`bg/basketball`** — 1440×1280, opaque, full-bleed.
  > A cartoon indoor basketball half-court seen from a flat side-on angle. Warm wooden floor in
  > cream `#FFF4E0` with painted key and three-point arc in coral `#FF5A5F`. Behind it a dark
  > navy `#1D2B36` crowd stand with simple rounded blob spectators in muted teal and gold, and
  > a plain banner rail. Composition is a vertical portrait scene: floor across the bottom
  > third, stand filling the upper two thirds. Opaque full-bleed background, no transparency,
  > no centred subject, no margin, nothing important in the outer 8% (it will be cropped).

- **`char/basketball`** (P1 + P2) — 1024×1024.
  > A cute chunky cartoon basketball player, side view facing right, mid-shot pose: knees
  > bent, both arms raised above the head releasing a shot. Coral `#FF5A5F` sleeveless jersey
  > and shorts, white sneakers, a headband, short dark hair. Big round head, tiny body, stubby
  > limbs.

- **`prop/basketball_hoop`** — 512×512.
  > A cartoon basketball hoop seen from the side: off-white `#FFFDF7` rounded backboard with a
  > coral `#FF5A5F` inner square, a gold `#FFC857` rim, and a short white net drawn as a few
  > simple tapering strokes.

- **`prop/basketball_ball`** — 256×256.
  > A cartoon basketball, perfectly circular, gold-orange `#FFC857` with three simple curved
  > dark navy seam lines. Completely flat colour.

### Sprint (100m)
Alternate two tap pads to run; first to the line.

- **`bg/sprint`** — 1440×1280, opaque, full-bleed.
  > A cartoon athletics track seen from a flat side-on angle. Coral-red running track surface
  > across the lower half with crisp off-white lane lines, a low kerb, and a strip of mint
  > green `#4ECB8D` infield. Above it a dark navy `#1D2B36` stadium stand with rounded blob
  > spectators in teal and gold, and a pale sky band at the very top. Opaque full-bleed
  > background, no transparency, no centred subject, no margin.

- **`char/sprint`** (P1 + P2) — 1024×1024.
  > A cute chunky cartoon sprinter, side view facing right, in a full running stride: front
  > knee driven high, opposite arm forward, torso leaning slightly ahead. Coral `#FF5A5F`
  > running vest and shorts, white spikes, a sweatband. Big round head, tiny body, stubby
  > limbs, confident little grin.

- **`char/sprint_lean`** (P1 + P2) — 1024×1024.
  > *(second frame of the run cycle — seed with `char/sprint` and say "same character")*
  > The same cartoon sprinter, side view facing right, on the opposite stride: rear leg
  > extended behind, front leg reaching forward, arms swapped. Identical character, kit, and
  > proportions to the attached image — only the leg and arm positions change.

- **`prop/sprint_finish`** — 512×512.
  > A cartoon finish-line gantry: two chunky off-white posts with a gold `#FFC857` crossbar and
  > a small black-and-white chequered flag panel hanging from it.

### Diving
Tap to launch, hold to tuck, tap to enter the water cleanly.

- **`bg/diving`** — 1440×1280, opaque, full-bleed.
  > A cartoon outdoor diving pool seen from a flat side-on angle. Bright teal `#22B8CF` water
  > filling the lower third with a flat off-white surface line and a few simple ripple dashes.
  > Above it a cream `#FFF4E0` poolside deck and a pale sky with two chunky rounded clouds.
  > Opaque full-bleed background, no transparency, no centred subject, no margin.

- **`char/diving_stand`** (P1 + P2) — 1024×1024.
  > A cute chunky cartoon diver standing on tiptoes at the edge of a board, side view facing
  > right, arms stretched straight up above the head, body straight, about to spring. Coral
  > `#FF5A5F` swim briefs, a matching swim cap, bare feet. Big round head, tiny body.

- **`char/diving_tuck`** (P1 + P2) — 1024×1024.
  > *(seed with `char/diving_stand`)*
  > The same cartoon diver curled into a tight mid-air tuck: knees hugged to the chest, arms
  > wrapped around the shins, body a compact rounded ball. Identical character, kit and
  > proportions to the attached image.

- **`char/diving_entry`** (P1 + P2) — 1024×1024.
  > *(seed with `char/diving_stand`)*
  > The same cartoon diver in a straight vertical entry: body perfectly straight and pointing
  > down, arms pressed together above the head, toes pointed. Identical character and kit to
  > the attached image.

- **`prop/diving_board`** — 512×512.
  > A cartoon springboard seen from the side: an off-white `#FFFDF7` plank with a rounded tip,
  > on a chunky teal `#22B8CF` pedestal, with a small gold `#FFC857` fulcrum roller.

- **`prop/diving_splash`** — 512×512.
  > A cartoon water splash: a rounded crown of teal `#22B8CF` and white droplets bursting
  > upward and outward, chunky rounded blob shapes, thick navy outline, no spray or mist.

### Horse Jump
Tap to jump each hurdle; mistime it and you stumble.

- **`bg/horse_jump`** — 1440×1280, opaque, full-bleed.
  > A cartoon equestrian arena seen from a flat side-on angle. Warm sandy coral-brown ground
  > across the lower half, a crisp white post-and-rail fence running horizontally above it,
  > then a band of mint `#4ECB8D` grass, rolling rounded hills in muted teal, and a pale sky.
  > Opaque full-bleed background, no transparency, no centred subject, no margin.

- **`char/horse_jump`** (P1 + P2) — 1024×1024.
  > A cute chunky cartoon horse with a small rider, side view facing right, mid-jump: front
  > legs tucked up, back legs extended, body arcing over. Cream `#FFF4E0` horse with a darker
  > mane and tail; the rider is a big-headed cartoon figure in a coral `#FF5A5F` jacket and a
  > navy riding helmet, leaning forward. Stubby rounded legs, no anatomical detail.

- **`char/horse_gallop`** (P1 + P2) — 1024×1024.
  > *(seed with `char/horse_jump`)*
  > The same cartoon horse and rider in a grounded gallop stride, all four legs bunched
  > beneath the body, rider upright. Identical character, kit and proportions to the attached
  > image.

- **`prop/horse_hurdle`** — 512×512.
  > A cartoon show-jumping hurdle seen from the side: two chunky off-white standards with a
  > gold `#FFC857` finial, holding two horizontal rails painted in coral `#FF5A5F` and white
  > diagonal stripes.

### Swimming
Rhythm taps on the beat, tap to turn at the wall; first to two lengths.

- **`bg/swimming`** — 1440×1280, opaque, full-bleed.
  > A cartoon swimming pool lane seen from a flat side-on cutaway angle, showing both the water
  > surface and below it. Bright teal `#22B8CF` water with a flat off-white surface line and
  > simple ripple dashes, a tiled off-white pool wall on the far side with a coral `#FF5A5F`
  > tile stripe, and a cream `#FFF4E0` deck strip along the top. Opaque full-bleed background,
  > no transparency, no centred subject, no margin.

- **`char/swimming`** (P1 + P2) — 1024×1024.
  > A cute chunky cartoon swimmer doing front crawl, side view facing right, seen half in and
  > half out of the water: one arm reaching forward over the surface, the other trailing back,
  > head turned to breathe. Coral `#FF5A5F` swim cap and briefs, cheerful expression. Big
  > round head, stubby limbs.

- **`char/swimming_pull`** (P1 + P2) — 1024×1024.
  > *(seed with `char/swimming`)*
  > The same cartoon swimmer on the opposite stroke: arms swapped, face down in the water.
  > Identical character, cap and proportions to the attached image.

- **`prop/swimming_rope`** — 512×512.
  > A cartoon pool lane divider: a horizontal row of chunky alternating coral `#FF5A5F` and
  > off-white disc floats threaded on a rope, drawn flat and side-on, tileable left to right.

- **`prop/swimming_wall`** — 512×512.
  > A cartoon pool touchpad: a flat off-white `#FFFDF7` rectangular panel with a rounded gold
  > `#FFC857` border and a small mint `#4ECB8D` sensor strip along its base.

### Archery
Drag to aim against a drifting wind band, release to loose. Best of five arrows.

- **`bg/archery`** — 1440×1280, opaque, full-bleed.
  > A cartoon outdoor archery range seen from a flat side-on angle. Mint green `#4ECB8D` mown
  > grass across the lower half with a lighter mowing stripe, a low cream `#FFF4E0` backstop
  > bank, rounded muted-teal trees along the horizon, and a pale sky with one chunky cloud.
  > Opaque full-bleed background, no transparency, no centred subject, no margin.

- **`char/archery`** (P1 + P2) — 1024×1024.
  > A cute chunky cartoon archer standing side-on facing right, bow arm extended forward and
  > drawing hand back at the cheek, at full draw. Coral `#FF5A5F` tunic and arm guard, navy
  > trousers, a small quiver on the back. Big round head, one eye squinting in aim, stubby
  > limbs.

- **`prop/archery_bow`** — 512×512.
  > A cartoon recurve bow seen from the side, drawn vertically: a chunky gold-brown `#FFC857`
  > curved limb with a thin dark navy string, thick even outline, flat colour.

- **`prop/archery_arrow`** — 256×256.
  > A cartoon arrow pointing right: a slim navy shaft, a chunky triangular gold `#FFC857` head,
  > and simple coral `#FF5A5F` fletching. Flat colour, thick outline.

- **`prop/archery_target`** — 512×512.
  > A cartoon archery target seen face-on: concentric flat rings in gold `#FFC857`, off-white,
  > coral `#FF5A5F`, and a navy bullseye, on a simple wooden tripod stand.

---

## 2. Game Select thumbnails

Twelve, one per game, **600×450**, transparent background. These sit inside a rounded card, so
keep the composition simple and centred — a single readable object or character, no scene.

Prompt shape (substitute the subject):

> A cartoon icon-style illustration of **{SUBJECT}**, centred on a transparent background,
> filling most of the frame, drawn as a single clear silhouette readable at thumbnail size.

| Asset id | SUBJECT |
|---|---|
| `thumb/air_hockey` | an air-hockey puck and a red striker paddle on a slice of pale blue rink |
| `thumb/ping_pong` | a white ping-pong ball and two crossed paddles, one coral one teal |
| `thumb/tic_tac_toe` | a chunky tic-tac-toe grid with a coral X and a teal O placed in it |
| `thumb/tap_race` | two tiny cartoon race cars nose to nose, one coral one teal |
| `thumb/connect_four` | a blue upright grid board with coral and teal discs dropping into it |
| `thumb/sumo_blob` | two round cartoon blob creatures with faces bumping into each other |
| `thumb/basketball` | a basketball dropping through a gold hoop with a white net |
| `thumb/sprint` | a cartoon sprinter mid-stride breaking a finish tape |
| `thumb/diving` | a cartoon diver curled in a tuck above a teal splash |
| `thumb/horse_jump` | a cartoon horse and rider arcing over a striped hurdle |
| `thumb/swimming` | a cartoon swimmer doing front crawl in a teal wave |
| `thumb/archery` | an arrow struck in the gold bullseye of a round target |

---

## 3. Shell and UI art

- **`shell/hero`** — 1200×900, transparent.
  > Two cute chunky cartoon blob mascots facing each other in a playful face-off pose, one
  > coral `#FF5A5F` and one teal `#22B8CF`, both leaning in with big eyes, rosy blush cheeks
  > and tiny determined grins, stub arms raised. Symmetrical composition, equal visual weight
  > for both characters.

- **`shell/mascot`** (P1 + P2) — 800×900, transparent.
  > A single cute chunky cartoon blob mascot, front view, standing: a rounded coral `#FF5A5F`
  > body, big friendly eyes with white catchlights, rosy blush cheeks, a small smile, tiny stub
  > arms and two short legs. Symmetrical, facing the viewer.
  > *(P2 is this exact image recoloured teal — see rule 2 above. It gets mirrored in code, so
  > keep the pose symmetrical.)*

- **`shell/laurel`** — 800×400, transparent.
  > Two symmetrical cartoon laurel branches curving upward and inward toward each other,
  > leaving an empty gap between their tips. Chunky rounded mint `#4ECB8D` leaves with a thick
  > navy outline, flat colour. Decorative header ornament.

- **`shell/card_frame`** — 600×450, transparent.
  > An empty rounded-rectangle card frame with a thick dark navy `#1D2B36` border, a soft
  > off-white `#FFFDF7` fill, and a small gold `#FFC857` ribbon banner across the bottom edge.
  > Completely empty inside — no illustration, no text.

### Icons — 256×256 each, transparent

All twelve share one prompt shape:

> A single flat cartoon UI icon of **{SUBJECT}**, centred, thick dark navy `#1D2B36` outline,
> solid off-white `#FFFDF7` fill, chunky rounded geometry, readable at 24 pixels. No
> background shape, no circle behind it, no text.

`icon/gear` a settings cog · `icon/back` a left-pointing chevron arrow ·
`icon/pause` two thick vertical bars · `icon/close` a thick X cross ·
`icon/restart` a circular arrow · `icon/home` a simple house ·
`icon/question` a question mark · `icon/star` a five-pointed star ·
`icon/sound_on` a speaker with two sound waves · `icon/sound_off` a speaker with a slash ·
`icon/music` a double musical note · `icon/trophy` a two-handled cup

---

## Checklist before handing the files back

- [ ] Every file is a PNG at the listed size, at the `path` from `manifest.json`.
- [ ] Transparent background on everything except the six `bg/*` scene backgrounds.
- [ ] Every P2 character was **recoloured from** its P1 file, not prompted separately.
- [ ] Characters all face **right**.
- [ ] No gradients, no gloss, no 3D shading, no text baked into any image.
- [ ] Line weight looks consistent when the whole set is viewed together at once —
      this is the check that catches style drift, and it is much easier to fix now than after
      integration.
