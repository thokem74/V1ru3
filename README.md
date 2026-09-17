# Vector Plague

An offline, single-player 3D arcade defence game for **Godot 4.7.2 stable** (GDScript, Compatibility renderer). Pilot a fragile, inertial lander across a living polygon landscape, destroy alien infection craft, and return to the home pad for fuel.

This is an original clean-room game inspired by David Braben’s **Zarch / Virus**. It is not an official release. All bundled game geometry and sound effects are original and generated procedurally; no original game assets, external services, addons, or downloads are required.

## Run

Open `project.godot` in Godot 4.7.2 and press **F5**, or run:

```sh
godot --path .
```

Default window: 1280×720. Simulation: 60 Hz. The native-resolution HUD and flat polygon world scale with the window. The project deliberately uses native rendering rather than a low-resolution viewport so distant targets and instruments remain legible.

## Fly

| Input | Action |
|---|---|
| Mouse movement | Left/right: relative heading adjustment; up/down: increase/reduce tilt |
| Left mouse / Space | Main thruster; consumes fuel |
| Right mouse / F / Ctrl | Forward cannon, 10 rounds/sec; **−1 point per round**, even on a miss |
| W / Up, S / Down | Increase / reduce declination |
| A / Left, D / Right | Rotate heading |
| R | Recenter attitude input; **does not cancel momentum** |
| M | Homing missile; requires a target ahead within 340 m |
| B | Smart bomb; 145 m radius |
| Tab | Toggle enlarged radar |
| Esc | Pause / resume and release / capture mouse |
| Enter / left click | Start, resume, continue results, or restart |

Lift straight up first. Horizontal mouse movement adjusts the requested heading by 0.10° per pixel; stopping the mouse holds that heading. Turns are damped and limited to 45°/sec. Up/down independently increases/reduces tilt, with a small neutral zone and a gentle progressive curve for hovering and landing. Larger movements progressively increase tilt and can still invert the craft. Tilt to accelerate, counter-tilt to brake, then return upright. The nose reticle shows the actual cannon direction. The circular instrument at lower right shows your requested lean direction and tilt.

The engine stops accelerating above 180 m world altitude. Fuel burns at 4 units/sec. Land on the enlarged gold **H** pad to refill at 20 units/sec. For an assisted landing, approach within 22 m of home and below 18 m above the pad, then release thrust. At moderate speeds (up to 14 m/s horizontal and 16 m/s descending) and within 40° of upright, the pad automatically levels the craft, reduces drift, and guides a gentle descent—even with empty fuel. Press thrust to abort. Touchdown inside the marked 30×30 m area tolerates up to 8 m/s vertical speed, 7 m/s horizontal speed, and 22° tilt, then stabilizes the craft. Ground away from the pad, water, fast/bad landings, ramming, and a single enemy round are lethal. Spawn protection lasts 1.5 seconds against enemies, not crashes.

## Campaign

Destroy **every enemy** to finish a wave. Four waves complete a landscape; clear all **three landscapes / twelve waves** to win. Later landscapes have less land and stronger enemy pressure. A wave’s healthy-land bonus can earn extra lives.

- **Rose seeders:** patrol low, linger above land, and drop infection.
- **Amber fighters:** moving interceptors with a visible pre-shot warning.
- **Violet pests:** agile ramming craft.
- **Steel bombers:** appear from landscape two, crossing high and fast while dropping broad infection packets.

Start with three lives, two missiles, and two bombs. Every 5,000 points earns a life and one of each special weapon. Enemy rewards are 250 / 300 / 100 / 600 respectively; destroying friendly scenery costs 75 points. Scores may be negative. Death preserves enemies and infection; a replacement craft arrives at home. Wave intermissions restore fuel and reposition the craft at home while preserving score, lives, and weapons. Losing all lives or leaving less than 2.5% healthy land ends the run.

Radar shows the entire toroidal map: green land, blue water, red infection, a white player marker, gold home marker, and detected hostiles. Destroyed scanner towers leave dark regions with no enemy detection. A local high score is stored in Godot’s `user://record.cfg`; saving is not required to play.

## Implementation

- A deterministic 128×128 grid of 8 m tiles uses nine periodic sine waves and a flattened home area. Water increases through the height bias.
- Sixty-four 16×16 `ArrayMesh` chunks use faceted colors. Infection changes rebuild only dirty chunks, at most two per tick.
- Collision samples the same two triangles and shoreline-clamped vertices as rendering; it does not rely on a mismatched approximate heightmap. Fast projectiles use swept enemy tests and terrain samples.
- Nearest periodic images of chunks, actors, props, and particles surround the player. Shared wrapped deltas drive AI, radar, weapon range, and collision. The view distance remains below half the world width.
- Infection deposits are applied at a fixed tick; water is excluded. Trees use a `MultiMesh`, mutate with infection, and are destructible. Scenery collision uses toroidal spatial bins.
- Separate flight, terrain, scenery, enemy, projectile, effects, score, progression, UI, and controller scripts own their systems. All flight tuning is grouped at the top of `lander_controller.gd`.
- Audio has bounded voices and coalesces same-frame effects; particles cap at 480. Runs without an audio device omit playback. Gameplay also works with Godot’s Dummy audio driver.

Rebuild the bundled WAV effects with `python tools/generate_audio.py` (Python standard library only).

## Validation

```sh
godot --version
godot --headless --path . --import
godot --headless --path . --quit-after 180
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --audio-driver Dummy --script res://tests/endurance_test.gd
```

With a graphical display:

```sh
godot --path . --script res://tests/smoke_test.gd
godot --path . --script res://tests/visual_check.gd
godot --path . --script res://tests/performance_test.gd
```

The logic runner verifies wrapping, deterministic terrain, seam continuity, water exclusion, infection clamping, score thresholds, and progression. Integration tests exercise actual flight, combat, landings, enemies, coverage loss, defeat, victory, and restart. Graphical runs additionally check pointer capture and rendered tree colors. The endurance test simulates 3,600 frames of late-wave combat and seam crossings with bounded entity counts. The visual harness saves screenshots under `/tmp/vector-plague-*.png`. Tests do not write high scores.

Behavioral references: [Zarch overview](https://en.wikipedia.org/wiki/Zarch), [Virus manual](https://www.lemonamiga.com/doc/virus/1794), and [Godot ArrayMesh documentation](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html). Implementation and assets are original.

## Reading the code

See [the code guide](docs/CODE_GUIDE.md) for the execution order, coordinate conventions, flight and landing equations, terrain/wrapping design, combat, effects, and test structure. Every GDScript function has a documentation comment, and flight tuning fields explain their units directly in `lander_controller.gd`.
