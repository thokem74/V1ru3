# AGENTS.md — Zarch/Virus-inspired Godot game

## Mission

Build a complete, playable, polished single-player 3D arcade game in this repository that recreates the **gameplay feel and engine ideas of David Braben's Zarch / Virus** using Godot.

This is not a request for a loose prototype. Continue autonomously until the project is a coherent game that starts, plays, progresses through waves, can be won/lost, and can be run from the Godot editor.

The game must be a **clean-room recreation**:
- Recreate mechanics, control feel, visual language, terrain concepts, enemy roles, infection mechanics, radar concepts, scoring, and progression from scratch.
- Do NOT copy original binaries, source code, maps, models, textures, audio, fonts, logos, cover art, screenshots, or text.
- Do NOT download or bundle copyrighted Zarch/Virus assets.
- Use original procedural/generated assets and generic names in the shipped game.
- It is fine for the README to state that the project is inspired by Zarch/Virus and David Braben's 1987 game.
- Use the working game title **Vector Plague** in the UI and project metadata.

Useful behavioral references:
- https://en.wikipedia.org/wiki/Zarch
- https://www.lemonamiga.com/doc/virus/1794
- Godot documentation for the installed/current stable Godot 4.x release.

Do not ask the user questions. If something is unspecified, make a sensible decision using the priorities in this file and keep going.

---

## Non-negotiable technical constraints

- Target **Godot 4.7.2 stable or newer compatible Godot 4.x stable**.
- Prefer compatibility with 4.7.2 APIs.
- Use **GDScript**, not C#.
- No third-party addons.
- No external runtime services.
- No network requirement.
- No asset-store dependencies.
- The finished project must work offline after checkout.
- Use Godot-native scenes/resources plus procedural/generated art.
- Use the **Compatibility renderer** unless a feature absolutely requires another renderer.
- Target desktop Linux first, while keeping input/platform code portable.
- Default window: 1280x720.
- Prefer a 640x360 internal retro render scaled cleanly to the window if practical.
- Physics/game simulation target: 60 Hz.
- The game must be playable with mouse + keyboard.
- The game must not require a gamepad, but optional gamepad support is welcome after the core game is complete.

If this repository is empty, create the entire Godot project, including `project.godot`.

---

## Autonomy contract

You are the implementing engineer. Do not stop to ask about:
- art direction,
- exact numerical tuning,
- folder layout,
- input bindings,
- whether a feature should be simplified,
- whether placeholder procedural geometry is acceptable,
- whether to add tests,
- whether to fix warnings or errors.

Make those decisions yourself.

When there is uncertainty:
1. Prefer the characteristic Zarch/Virus feel over modern conventions.
2. Prefer a simple system that is fully working over a complicated unfinished system.
3. Prefer deterministic procedural content over hand-authored content.
4. Prefer local/offline implementations over dependencies.
5. Prefer readable, modular GDScript over clever code.
6. Prefer a complete gameplay loop over cosmetic extras.
7. Do not leave TODOs for required gameplay.
8. If a command/test fails, investigate and fix it before moving on.
9. Never declare completion just because the project launches. Completion means the acceptance criteria near the end of this file are met.

---

## Core experience

The player pilots a fragile hovercraft/lander over an undulating tiled landscape while alien craft infect the terrain.

The essential feel is:
- low-poly solid 3D,
- visible square terrain cells,
- fast terrain scrolling/flying,
- difficult but learnable inertia-based mouse control,
- one downward-facing thruster,
- gravity,
- dangerous ground contact,
- rapid-fire forward cannon,
- red infection spreading over green land,
- enemies that seed infection while others attack the player,
- a strategic radar showing the entire terrain,
- fuel management and risky landing-pad refueling,
- simple arcade waves with escalating pressure,
- dramatic particles for thrust, infection, impacts, dust, water splashes, and explosions.

The player should spend the first minute learning to fly and then discover that controlling the lander well is itself part of the game.

---

## Classic flight model

This is a priority feature. Do not replace it with ordinary six-degree-of-freedom flight, airplane controls, or a character controller that simply moves in WASD directions.

### Orientation

The craft has no intentional roll control.

Model orientation as:
- yaw/heading around world up,
- declination/pitch away from upright,
- no persistent roll.

The default mouse mode should emulate the classic behavior:

1. Capture the pointer when gameplay begins.
2. Maintain an internal `virtual_mouse_offset: Vector2`, initially `(0, 0)`.
3. Add relative mouse motion to this virtual offset.
4. Clamp its radius to a configurable maximum.
5. Treat the center as upright.
6. Distance from center determines target declination/tilt magnitude.
7. Angle around center determines the compass direction the craft points/leans toward.
8. Allow extreme input to tilt past 90 degrees and eventually invert the craft.
9. The craft must not snap to this target orientation. It follows with angular inertia/damping.
10. Releasing/re-centering input does not magically erase physical velocity; it only changes orientation toward upright.

This should feel sensitive and unusual, but still controllable after practice.

Expose the important tuning constants in one configuration/resource or clearly grouped exported variables:
- mouse sensitivity,
- virtual mouse radius,
- max declination (allow roughly 165–180 degrees),
- orientation response,
- orientation damping,
- gravity,
- thrust acceleration,
- linear drag,
- max practical speed,
- flight ceiling.

### Thrust

- Left mouse button = main thrust.
- Main engine pushes along the craft's local up axis, away from the engine mounted underneath.
- A tilted craft therefore accelerates sideways.
- An inverted craft can thrust toward the ground and crash.
- Thrust consumes fuel.
- Above the flight ceiling, main thrust produces no acceleration.
- Exhaust particles appear only while thrust is active and fuel is available.
- Gravity always pulls downward.

### Cannon

- Right mouse button = rapid-fire forward cannon.
- Cannon fires from the nose in the craft's forward direction.
- Rate of fire should feel fast, approximately 8–12 rounds/sec.
- Every cannon round costs **1 score point**, including misses.
- Shots have finite range/lifetime.
- Terrain impact: dust burst.
- Water impact: splash burst.
- Enemy impact: hit flash/debris and damage/destruction.

### Keyboard fallback

Mouse is the primary/classic mode, but provide keyboard fallback:
- W / Up: dip nose / increase forward declination
- S / Down: raise nose / reduce/reverse declination
- A / Left: rotate heading left
- D / Right: rotate heading right
- Space: thrust
- F or Ctrl: fire cannon
- M: homing missile
- B: smart bomb
- Tab: enlarged map/radar
- Esc: pause and release mouse
- Enter or left click: start/continue where appropriate

Do not let the keyboard fallback compromise the mouse model.

### Camera

Use a third-person chase camera:
- craft visible in lower/central screen area,
- camera follows heading smoothly,
- camera does not roll,
- moderate lag for a sense of speed,
- looks slightly ahead of the craft,
- terrain remains readable while pitching,
- typical distance about 10–16 m, height 4–8 m, FOV about 65–75 degrees.

Avoid cinematic camera behavior that interferes with aiming.

---

## Player survival, fuel, landing, and lives

Start with:
- 3 lives,
- full fuel,
- 2 smart bombs,
- 2 homing missiles.

The player is intentionally fragile:
- one enemy projectile is lethal,
- direct high-speed terrain collision is lethal,
- collision with an enemy is lethal,
- hitting water is lethal,
- a bad landing is lethal.

A safe landing requires all of:
- contact over the home landing pad,
- low vertical speed,
- low horizontal speed,
- craft close to upright (roughly <= 8 degrees),
- engine not driving the craft into the pad.

While safely on the pad:
- fuel refills steadily,
- craft is stabilized enough to remain landed,
- player is still vulnerable to enemy attack.

Suggested defaults:
- fuel range 0–100,
- main thrust burns about 4 fuel/sec,
- refuel about 20 fuel/sec,
- no automatic fuel regeneration away from pad.

If fuel reaches zero, the player must glide/fall and attempt to land.

After death:
- play an explosion,
- decrement a life,
- respawn at the home pad after a short delay if lives remain,
- preserve current landscape infection and current wave state,
- provide a brief spawn grace period of around 1.5 sec,
- reset fuel to a useful amount or full fuel so the respawn is playable.

Game over when lives reach zero or the landscape becomes effectively fully infected.

Award an extra life at score thresholds, initially every 5,000 points. Award one smart bomb and one missile with each extra life.

---

## World and terrain engine

The terrain engine is the technical centerpiece.

### Logical map

Create a deterministic toroidal tile world:
- default grid: 128 x 128 cells,
- default cell size: 8 m,
- approximately 1024 x 1024 m logical world,
- opposite edges wrap,
- all world-distance calculations for AI/radar/projectiles must use wrapped/toroidal deltas where appropriate.

Put wrap math in a dedicated utility.

Crossing the map edge must be visually seamless enough that the player does not perceive an empty world boundary. A practical solution is:
- periodic terrain copies around the playable map, or
- chunk repetition around the active camera/player,
- plus wrapped positions for dynamic actors.

Do not leave a visible hard terrain edge.

### Height generation

Generate terrain deterministically from a landscape seed.

Use a sum of pseudorandom periodic sine waves, inspired by the original technique:
- multiple waves with randomized amplitude, direction, frequency, and phase,
- frequencies chosen so the result tiles seamlessly,
- optionally add a low-frequency island/continent shaping function that is also periodic,
- flatten a small region around the home landing pad.

The final terrain should look like rolling hills, not Perlin-noise mountains.

Each landscape has:
- height field,
- land/water classification,
- infection amount per tile,
- scenery metadata.

Use sea level `y = 0`.

Make later landscapes contain progressively more water by modifying height bias/sea level relationship, not by hand-editing maps.

### Rendering

Use `ArrayMesh` for terrain chunks.

Recommended:
- chunks of 16 x 16 cells,
- duplicate vertices per tile/triangle as needed for flat polygon shading,
- one or two triangles per square tile,
- clearly visible faceted terrain,
- per-vertex or per-face colors,
- rebuild only dirty chunks when infection colors change.

Do not rebuild the full 128x128 terrain every frame.

Terrain colors:
- healthy land: varied greens based on height/slope,
- partly infected: brown/rust,
- heavily infected: red/dark red,
- water: deep blue/blue-gray,
- shoreline may be slightly lighter.

Keep textures absent or minimal. The terrain should look like colored polygons.

Generate collision that follows the terrain. It may be a static triangle mesh or another reliable collision representation. Collision does not need to be regenerated when infection changes because infection is visual/state-only.

### Retro depth treatment

Recreate the old solid-3D feel without intentionally harming playability:
- flat/low-poly shading,
- limited palette,
- simple directional light,
- mild distance fog that fades toward a pale sky/white,
- modest draw distance,
- minimal post-processing,
- no PBR-heavy materials,
- no photorealism.

At altitude, spawn sparse air/dust particles moving past the player to communicate speed when the ground is distant.

### Shadows

The original game's simple projected shadows were useful for judging altitude.

Implement cheap ground shadows for:
- player,
- flying enemies.

Preferred approach:
- downward ray to terrain,
- a flat translucent blob/polygon at the hit point,
- scale/fade subtly with altitude.

Do not depend solely on realistic shadow maps.

---

## Scenery

Populate healthy land procedurally with simple original low-poly objects:
- trees,
- small blocky buildings,
- radar/scanner towers,
- home landing pad.

Use primitive meshes or generated low-poly meshes only.

Use `MultiMesh` where it helps for large numbers of repeated static props.

### Trees

Trees should:
- appear mainly on healthy land,
- use a very small polygon count,
- be destructible by player fire,
- visually mutate as local infection rises: color toward red/brown, change scale/shape slightly,
- optionally emit small infection motes when heavily infected.

### Buildings

Buildings are simple geometric scenery. They may be destructible. Avoid complex interiors.

### Radar towers

Place multiple radar towers evenly across the world.

Each intact tower provides radar coverage over a region. When a tower is destroyed:
- its coverage disappears,
- the corresponding radar region becomes dark/unknown,
- enemies in that region are not shown on radar unless covered by another tower.

The player can accidentally destroy towers, so cannon discipline matters.

### Landing pad

Place a clearly readable home pad on flattened healthy terrain.
It is the respawn and refueling location.
Add a simple beacon/pole or light so it is findable from the air and visible on radar.

---

## Infection simulation

Store infection as a float `0.0 .. 1.0` per logical terrain tile.

Healthy = 0.
Fully infected = 1.

Infection sources:
- Seeder craft emitting virus droplets while hovering/landed,
- Bomber packets dropped from altitude,
- optional small local diffusion from infected cells.

Virus droplets/packets should be visible red particles/projectiles that fall and hit the terrain.

On impact:
- infect the impacted tile,
- infect a small falloff radius around it,
- mark affected terrain chunks dirty,
- update nearby trees,
- trigger a small red particle puff.

Use a modest fixed simulation tick (for example 5–10 Hz) rather than doing expensive infection work every rendered frame.

If diffusion is implemented, keep it slow. Enemy deposition must be the dominant infection source.

Compute and display:
- percent healthy land,
- percent infected land.

Do not count water as infectable land.

When a wave ends, award a survival bonus based on remaining healthy land.

If all or nearly all infectable land reaches full infection, trigger game over.

---

## Enemies

Use simple original polygonal craft with strong silhouettes and different colors. Do not imitate original art exactly.

All enemies must work with toroidal world distance.

Implement at least these four enemy roles:

### Seeder

Available from wave 1.

Behavior:
- slow and predictable,
- patrols at low altitude,
- periodically chooses a land tile,
- descends/lingers,
- emits visible red virus droplets,
- tries to move away after seeding,
- weak and easy to destroy.

Seeder destruction is the player's primary early objective.

### Fighter

Available from wave 2.

Behavior:
- actively attacks player,
- medium-fast,
- flies intercept paths,
- fires single lethal projectiles with telegraphed cadence,
- keeps moving rather than hovering directly in front of the player.

### Pest

Available from wave 3.

Behavior:
- small,
- agile,
- tries to ram the player,
- changes direction aggressively,
- low health,
- dangerous at close range.

### Bomber

Available from wave 5 or later.

Behavior:
- high altitude,
- fast crossing routes,
- drops virus packets over broad areas,
- not primarily focused on shooting player,
- hard to chase because matching its speed requires dangerous tilt.

Optional after the required game is complete:
- harmless water creature/fish that is worth bonus points and does not count for wave completion,
- mutant/aggressive enemy interactions with infected trees.

Do not add optional enemies until the four required enemies are reliable.

---

## Enemy spawning and wave progression

A wave is complete only when all required enemy craft in that wave are destroyed.

Use 4 waves per landscape.

After wave 4:
- calculate landscape bonus,
- show a short results panel,
- advance to a newly generated landscape,
- increase landscape index,
- increase water coverage,
- increase enemy count and/or aggressiveness,
- keep score/lives/weapons.

Suggested progression, tune as needed:

Wave 1:
- 3 Seeders.

Wave 2:
- 4 Seeders + 2 Fighters.

Wave 3:
- 5 Seeders + 3 Fighters + 3 Pests.

Wave 4:
- 6 Seeders + 4 Fighters + 4 Pests.

Landscape 2+:
- scale counts gradually,
- introduce Bombers,
- increase infection drop rate modestly,
- cap total simultaneous enemies at a sensible number for performance/readability.

Difficulty must rise, but avoid spawning everything directly on top of the player.

---

## Weapons and score

Required weapons:

### Cannon

- unlimited ammunition,
- each shot costs 1 score point,
- rapid fire,
- straight projectile or fast ray-assisted projectile,
- player can finish with a negative score.

### Homing missile

- limited stock,
- key M,
- locks nearest valid enemy within a sensible forward cone/range,
- steers over time rather than teleporting,
- can miss agile targets,
- visible smoke/trail,
- strong enough to destroy normal targets.

### Smart bomb

- limited stock,
- key B,
- affects only a limited radius around player,
- destroys or severely damages nearby enemies,
- large readable shockwave/particle effect,
- does not erase the whole map.

Suggested score values:
- Seeder: +250
- Fighter: +300
- Pest: +100
- Bomber: +600
- bonus creature if implemented: +1000
- cannon round: -1
- radar tower/tree/building friendly destruction: small negative score
- wave bonus: based on healthy-land percentage, roughly up to +2000

Centralize score constants.

---

## Radar and HUD

### Radar

Create a top-left radar/minimap showing the entire logical terrain.

At minimum display:
- healthy land in green,
- infected land in red/brown,
- water in blue,
- uncovered/no-radar regions in near-black,
- player as a bright marker,
- home pad,
- known enemies inside live radar coverage.

Radar updates do not need to happen every frame. 5–10 Hz is enough.

Tab toggles a larger map overlay.

### HUD

Keep the HUD compact and retro.

Show:
- score,
- lives,
- fuel bar,
- altitude,
- speed,
- missiles,
- smart bombs,
- current landscape,
- current wave,
- healthy land percentage,
- enemy count remaining.

Altitude should be useful to the player. Prefer height above local terrain/water rather than raw global Y, and optionally also use a ceiling indicator.

Show concise messages:
- WAVE 2
- LANDSCAPE 3
- REFUELING
- THRUST CEILING
- RADAR TOWER DESTROYED
- WAVE CLEAR
- EXTRA LIFE
- LANDSCAPE LOST
- GAME OVER

Create title/start, pause, wave-results, and game-over UI.

---

## Visual style and asset generation

The game must be visually coherent even without external art.

Use:
- flat colored polygons,
- a limited retro palette,
- low-poly craft and props,
- geometric UI panels,
- no texture-heavy materials,
- simple sky,
- strong green/blue/red color readability.

Procedurally construct meshes for:
- player lander,
- each enemy type,
- trees,
- radar tower,
- buildings,
- landing pad details if needed,
- bullets/missiles/bombs.

Meshes may be authored as `.tscn` scenes composed from Godot primitives or generated with `ArrayMesh`.

Do not leave default gray cubes as final enemies.

### Particles

Required particle effects:
- main thruster exhaust,
- cannon muzzle flash,
- cannon trail/tracer if useful,
- explosion debris,
- virus droplets/motes,
- terrain dust impact,
- water splash,
- missile trail,
- smart-bomb shockwave,
- high-altitude speed dust.

Prefer Godot particle systems with simple meshes/materials and no image textures.

### Audio

Provide simple original/generated sound effects:
- thrust loop,
- cannon,
- explosion,
- infection/drop,
- missile,
- smart bomb,
- warning/extra-life tone.

No downloaded copyrighted audio.

A small Python script using only the standard library may generate WAV files procedurally if Python is available. Keep the generator in `tools/` so assets are reproducible. If using generated WAVs, commit both the generator and generated files.

Music is optional. Do not delay the game for music.

---

## Suggested architecture

You may adjust filenames, but keep responsibilities similarly separated.

```text
project.godot
README.md
AGENTS.md

scenes/
  main.tscn
  game.tscn
  player/
    lander.tscn
  enemies/
    seeder.tscn
    fighter.tscn
    pest.tscn
    bomber.tscn
  world/
    world.tscn
  ui/
    hud.tscn
    title_screen.tscn
    pause_menu.tscn
    game_over.tscn

scripts/
  game/
    game_controller.gd
    wave_controller.gd
    score_manager.gd
  player/
    lander_controller.gd
    weapon_controller.gd
  enemies/
    enemy_base.gd
    seeder.gd
    fighter.gd
    pest.gd
    bomber.gd
  world/
    terrain_data.gd
    terrain_renderer.gd
    terrain_generator.gd
    infection_system.gd
    scenery_manager.gd
    radar_coverage.gd
    wrap_math.gd
  projectiles/
    bullet.gd
    enemy_bullet.gd
    homing_missile.gd
    virus_packet.gd
  ui/
    hud.gd
    radar.gd
  effects/
    blob_shadow.gd

assets/
  audio/
tools/
  generate_audio.py
tests/
  run_tests.gd
  smoke_test.gd
```

Avoid an enormous single `game.gd`.

Use signals for major game events where appropriate:
- player_died,
- enemy_destroyed,
- tile_infected,
- radar_tower_destroyed,
- wave_started,
- wave_completed,
- landscape_completed,
- score_changed.

Avoid unnecessary autoload singletons. One game-state/controller autoload is acceptable if it materially simplifies scene transitions.

---

## Data and code quality

Use typed GDScript where reasonable.

Prefer:
- `class_name` for reusable logic/data classes,
- small functions,
- explicit constants,
- clear naming,
- comments explaining non-obvious toroidal math or classic control math.

Avoid:
- excessive inheritance,
- deeply coupled node lookups,
- repeated `get_node()` in hot loops,
- rebuilding meshes every frame,
- allocating large arrays every physics tick,
- per-tile Nodes for all 16,384 terrain cells,
- thousands of individual tree nodes when a MultiMesh will work,
- magic numbers scattered across scripts.

Do not suppress errors to make tests appear green.

Warnings that indicate real bugs should be fixed.

---

## Performance targets

On a normal modern desktop:
- target steady 60 FPS at 1280x720,
- no obvious frame hitch every time infection changes,
- no full terrain regeneration during normal infection,
- enemy count should remain bounded,
- particles should have sensible caps.

Use chunk dirtying for terrain color updates.

Use MultiMesh for repeated scenery if needed.

Do not prematurely optimize tiny systems, but do not implement obviously pathological per-frame work.

---

## Implementation order

Follow this order unless the repository already contains working systems.

### Milestone 1 — bootable project
- project opens,
- main scene runs,
- title screen starts gameplay,
- camera and simple world visible.

### Milestone 2 — terrain engine
- deterministic tiled sine-wave landscape,
- water,
- chunked ArrayMesh rendering,
- collision,
- seamless wrapping,
- low-poly palette.

### Milestone 3 — lander
- classic virtual-mouse orientation,
- inertia,
- gravity,
- thrust,
- fuel,
- flight ceiling,
- camera,
- safe/bad landing detection,
- death/respawn.

### Milestone 4 — weapons/effects
- cannon,
- score cost per shot,
- impacts,
- explosions,
- missile,
- smart bomb,
- shadows,
- basic audio.

### Milestone 5 — infection/scenery
- per-tile infection,
- terrain recoloring,
- trees/buildings,
- mutated infected trees,
- landing pad/refuel,
- radar towers.

### Milestone 6 — enemies
- Seeder,
- Fighter,
- Pest,
- Bomber,
- toroidal AI.

### Milestone 7 — game loop
- wave controller,
- 4 waves/landscape,
- bonus,
- later landscapes,
- difficulty scaling,
- lives/extra lives,
- game over.

### Milestone 8 — radar/UI/polish
- radar coverage,
- HUD,
- map overlay,
- title/pause/results/game-over screens,
- tuning,
- generated audio,
- README.

After every milestone, run the project/tests and fix breakage before continuing.

Do not stop after any intermediate milestone.

---

## Testing and validation

First determine the Godot executable, trying sensible names such as:
- `godot`
- `godot4`

Record which one works.

Check version:
```sh
godot --version
```

Import/validate the project:
```sh
godot --headless --path . --import
```

Run a short headless smoke boot:
```sh
godot --headless --path . --quit-after 180
```

Create a lightweight project test runner in `tests/run_tests.gd`, using only Godot/GDScript. It should test logic that does not require visual rendering, including at least:
- wrap/toroidal delta math,
- deterministic terrain generation,
- terrain seam continuity,
- infection clamping,
- water excluded from infected-land percentage,
- wave progression rules,
- score cost for cannon shot,
- extra-life threshold progression.

Run it with a command appropriate for the script, e.g.:
```sh
godot --headless --path . --script res://tests/run_tests.gd
```

Also create a smoke test that loads the main gameplay scene, advances enough frames to initialize systems, checks important nodes/systems exist, and exits nonzero on failure.

If Godot supports script checking in the installed version, use it where helpful.

When a graphical display is available, launch the game and manually verify:
- mouse capture/release,
- classic flight feel,
- thrust direction while tilted,
- inverted thrust can cause a crash,
- cannon aims with craft,
- refueling works,
- infection is visible,
- wave can be cleared,
- radar updates,
- death and respawn work,
- pause and game over work.

Do not claim visual verification if it was not possible.

---

## README requirements

Create a concise `README.md` containing:
- project description,
- inspiration/clean-room note,
- Godot version,
- how to open/run,
- controls,
- gameplay objective,
- brief technical overview of terrain/infection/wrapping,
- testing commands,
- note that all bundled art/audio is original or procedurally generated.

Do not market the game as an official Zarch/Virus release.

---

## Definition of done

The task is complete only when all of these are true:

- Godot recognizes the repository as a valid project.
- The project boots without script errors.
- A title screen leads into a game.
- The player can fly using the classic mouse model.
- Left mouse thrusts; right mouse fires.
- Gravity, inertia, fuel, flight ceiling, crash behavior, and landing/refueling all work.
- Terrain is visibly tiled, undulating, low-poly, deterministic, and seamless at world edges.
- Terrain has land and water.
- Infection state exists per land tile and visibly changes terrain green -> brown/red.
- Seeders visibly deposit infection.
- Fighters attack.
- Pests ram.
- Bombers drop infection from altitude in later play.
- Player cannon, missile, and smart bomb work.
- Cannon shots cost score.
- Player/enemy explosions and thrust/infection/impact particles work.
- Trees/buildings/radar towers/landing pad exist and are not default placeholder cubes.
- Infected trees visibly mutate.
- Radar shows terrain/infection/player/enemies.
- Destroyed radar towers create radar blind regions.
- HUD shows score, lives, fuel, altitude, weapons, landscape/wave, health-of-land, enemies remaining.
- Waves end only after required enemies are destroyed.
- Four waves advance to a new, harder landscape.
- Later landscapes have more water and tougher enemy pressure.
- Lives, extra lives, respawn, and game over work.
- Project contains no required external downloads.
- Required test scripts pass.
- README is accurate.
- There are no required gameplay TODOs left.
- The result feels like a deliberate Zarch/Virus-inspired arcade game, not a generic Godot flying demo.

---

## Final self-review before stopping

Before concluding the task:

1. Run all validation commands again.
2. Read the Godot output for errors, not just exit codes.
3. Search the repo for `TODO`, `FIXME`, placeholder comments, broken resource paths, and missing scripts.
4. Remove temporary/debug files not needed by the project.
5. Confirm no external copyrighted game assets were added.
6. Confirm input actions are defined in `project.godot`.
7. Confirm the main scene is configured.
8. Confirm the game can be restarted after game over without reopening Godot.
9. Confirm pausing releases the mouse and resuming captures it again.
10. Confirm the game remains playable if audio is unavailable.
11. If a feature had to be simplified, simplify it into a working form rather than leaving it half-implemented.
12. Only then consider the implementation finished.
