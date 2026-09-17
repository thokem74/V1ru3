# Vector Plague code guide

This guide explains the game's structure, state, and algorithms. Each GDScript function also has a `##` documentation comment immediately above it; exported flight settings have comments describing their units and purpose. Python functions use docstrings. Start with the controller to understand execution order, then follow the system you want to change.

## Where to find things

| File under `scripts/` | Responsibility |
|---|---|
| `game/game_controller.gd` | Builds the scene, runs the simulation, changes screens, handles campaign events |
| `player/lander_controller.gd` | Mouse/keyboard steering, angular response, forces, fuel, landing, death |
| `world/wrap_math.gd` | Shared toroidal position, displacement, and tile-index calculations |
| `world/terrain_data.gd` | Deterministic height field, collision queries, infection, terrain colors |
| `world/terrain_renderer.gd` | Chunk meshes, flat normals, periodic placement, dirty-color rebuilds |
| `world/scenery_manager.gd` | Trees/buildings/pad, radar towers, prop collision, coverage mask |
| `enemies/enemy.gd` | Four role-specific flight/attack behaviors and shared damage handling |
| `projectiles/projectile_system.gd` | Weapon input, targeting, projectile movement, collision, infection impacts |
| `game/score_manager.gd` | Score, lives, weapon stocks, extra-life thresholds |
| `game/wave_controller.gd` | Wave rosters and campaign progression |
| `effects/models.gd` | Original craft and primitive mesh construction |
| `effects/effects.gd` | Bounded particles, sound requests, engine loop |
| `ui/hud.gd` | Radar, flight instruments, aiming markers, title and modal screens |

`scenes/main.tscn` attaches the controller to the root Node3D. Most scene content is constructed in code, so geometry and system relationships are explicit in the scripts. There are no autoload managers or external services to discover.

## Coordinates, time, and ownership

World positions and distances are in **meters**. X/Z form the ground plane, +Y is up, and a craft's local **-Z is forward**. Linear velocity is meters/second. `dt` is the duration of one simulation step in seconds, normally 1/60.

Stored angles and angular velocities use **radians** and radians/second. Exported angle limits and mouse heading sensitivity use degrees for readable tuning; code converts them at the boundary with `deg_to_rad`. `basis.y` is the craft's local up axis expressed in world coordinates. Multiplying it by thrust acceleration produces upward, sideways, or downward force depending on attitude.

The controller owns the world, player, enemies, projectile system, effects, camera, and HUD. `TerrainData`, `ScoreManager`, and `WaveController` are reference-counted logical objects rather than scene nodes. Player/enemy shadows are children of the game root, not of the rotating craft. Their `dispose()` methods therefore explicitly remove both the craft and its separately owned shadow.

Dictionary records are shared by reference. For example, a tower's record appears in both the scenery `props` and `towers` arrays. Setting its `alive` flag through collision also updates what radar coverage sees. The dictionary fields are described beside the owning arrays.

## Controller and simulation order

`_ready()` builds shared infrastructure and a landscape to show behind the title. `reset_campaign()` replaces score and progression. `build_landscape()` replaces the physical world and its actors while retaining the current score/progression objects.

The `mode` string selects the state:

- `title`: show instructions and orbit the camera; no enemy simulation.
- `playing`: run the game.
- `pause`: stop simulation and release the pointer.
- `results`: show bonuses after all required enemies are destroyed.
- `gameover`: show defeat after lives run out or healthy land falls below 2.5%.
- `victory`: show success after the final landscape's results are confirmed.

`start()` means “confirm the current screen,” not always “reset everything.” It resumes a pause, advances results, launches from the title, or restarts after victory/defeat.

During `playing`, `_physics_process()` performs these operations in order:

1. Update the player, then poll weapons.
2. Move and attack with each enemy.
3. Advance projectiles and resolve hits.
4. About every 0.15 seconds, apply queued infection deposits, check landscape loss, and refresh radar imagery.
5. Update particles, engine sound, and terrain placement/dirty chunks.
6. Every 0.1 seconds, update scenery placement and infected tree appearance.
7. Update the chase camera, respawn a dead player when appropriate, check wave completion, and redraw the HUD.

Order matters: weapons and enemies see the player's latest position; infection impacts are collected before the slower infection tick consumes them. Arrays are copied when a destruction signal can remove an item during iteration. Projectile and particle arrays instead iterate backward, allowing safe removal by index.

## Flight input and angular motion

Horizontal mouse motion changes `requested_heading` by 0.10 degrees per pixel. It is **relative steering**: a small movement requests a small turn, and stopping the mouse stops adding turns. This avoids the old polar-control problem where a tiny sideways offset near upright could request a quarter-turn.

Vertical mouse motion changes the length of `virtual_mouse_offset`. The vector points along the requested heading for the HUD; its radius represents requested declination. Keyboard input adjusts the same requested attitude. `R` clears tilt input and requests the current heading; it does not remove translational velocity.

`requested_tilt()` converts radius into tilt in three stages:

1. Divide by `virtual_mouse_radius` to obtain a fraction of full travel.
2. Remove `mouse_deadzone`, rescale the remaining range, and clamp to 0..1.
3. Raise that value to `tilt_curve`, then multiply by the maximum angle in radians.

The exponent above 1 makes small inputs gentler while keeping the full inversion range. `update_attitude()` uses damped angular springs: angle error accelerates angular velocity, and damping opposes that velocity. Rate caps bound fast turns. It integrates heading and tilt, then builds a yaw/pitch basis with no persistent roll.

The player `step()` function is deliberately short: update grace time, attitude, movement, then visual effects. Those phases are named `update_attitude()`, `update_motion()`, and `update_flight_effects()` so flight behavior can be read in order.

## Forces, contact, and landing assistance

`update_motion()` determines whether thrust is requested, available, and below the ceiling. Requested thrust consumes fuel. Actual acceleration follows local up. Gravity acts downward during flight. Multiplication by `exp(-linear_drag * dt)` applies drag consistently across time-step sizes; the speed cap limits extreme velocities.

After forces and optional assistance, position advances by velocity times `dt`. Contact compares the craft underside against `terrain.ground()`. Away from home, contact is lethal. Over the marked home area, speed and tilt must meet touchdown limits; then `settle_on_pad()` clears motion and tilt. While landed, fuel refills. Thrust can lift the craft again.

Landing assistance is local to home, not a global autopilot. `can_assist_landing()` checks approach distance, clearance, descent/horizontal speed, tilt, and whether thrust is released. If eligible:

- Attitude gradually returns upright.
- Horizontal velocity approaches a slow direction toward home.
- Vertical velocity approaches a gentle -2.5 m/s descent.

Acceleration limits keep these changes gradual. Thrust disengages the assist immediately, and excessively fast or inverted approaches are not rescued. The assistance works with empty fuel because it models guidance from the home pad. Exported touchdown limits are separate from the wider approach eligibility limits.

`die()` is idempotent: an already dead craft cannot cost another life. Spawn grace blocks enemy hits, but terrain crashes bypass it. The controller spends the life and schedules respawn; player code does not reset enemies or infection.

## Toroidal world and terrain

The logical map is 128×128 tiles, each 8 m wide: a 1024 m torus. `WrapMath.delta(a, b)` chooses the shortest X/Z displacement, while preserving ordinary Y distance. `canonical()` maps X/Z into the logical range. `near()` places an equivalent copy of an object nearest a reference position. `index()` wraps tile coordinates and returns `z * 128 + x`.

Gameplay positions need not be forcibly teleported into 0..1024 every frame. Nearest periodic representations and wrapped distances keep rendering, pursuit, targeting, and collision continuous across seams. The camera's 420 m far plane remains below half the world width; chunk placement includes its local center offset.

`TerrainData.generate()` creates nine sine waves with integer X/Z frequencies, random phase, and decreasing amplitude. Integer frequencies complete whole cycles across the map, so opposite edges join. The height bias falls on later landscapes to increase water coverage. A smooth distance-based blend flattens the home area.

Heights live at grid corners. Each square uses two triangles separated by the diagonal from corner b to c. `surface()` interpolates the appropriate triangle using fractional cell coordinates. With `clamp_water=true`, it clamps each corner to sea level **before** interpolation, matching the renderer's shoreline geometry. `ground()` uses that visible surface; raw `surface()` can still identify submerged terrain.

The renderer creates 64 chunks, each containing 16×16 tiles. Each triangle gets its own vertices and normal, producing flat shading. Infection changes tile colors only. A dirty set identifies affected chunks, and at most two chunks rebuild per update; normal play does not regenerate the full map.

## Infection, scenery, and radar

`land` is a byte mask identifying infectable tile centers. `infection` stores 0..1 per tile, and `infection_sum` tracks the total so `healthy()` is constant-time. `infect()` ignores water, clamps additions, adjusts the total by the actual change, dirties the relevant chunk, and emits a signal.

A virus impact queues a world position and radius. `deposit()` distributes infection over a circular tile neighborhood with distance falloff. Deposition is the infection source; there is no background diffusion in this implementation.

Trees use one MultiMesh. Each tree record stores its original scale and instance index. Infection changes its color, width, and height during scenery updates. Destroying a tree collapses its instance transform; buildings and towers hide their visual roots.

Scenery collision uses wrapped 32 m bins. A projectile segment gathers nearby bins, then performs precise segment-to-prop-center distance tests on those candidates. Neighbor bins cover prop radii; a visited set avoids testing a bin repeatedly.

Each living tower contributes a 190 m coverage circle. Rebuilding the coverage mask after tower loss leaves genuinely uncovered regions dark. The radar terrain texture is refreshed at the infection cadence; player/home/enemy markers are drawn over it. Enemy markers require coverage, while player and home remain visible.

## Enemies and weapons

Role IDs are shared by models, rosters, and rewards: **0 seeder, 1 fighter, 2 pest, 3 bomber**. Their switch branches explain the steering decisions inline. Seeders slow near land targets and drop droplets; fighters combine interception with tangential movement; pests pursue with oscillation; bombers follow high crossing routes and drop packets. A fighter's visible warning appears shortly before its next shot when close enough.

Projectile kinds are a separate numbering scheme: **0 cannon, 1 hostile round, 2 missile, 3 seeder droplet, 4 bomber packet**. Do not confuse these with enemy role IDs.

The cannon fires along local -Z and adds player velocity. Every round immediately costs one point. Missile acquisition selects the nearest enemy within range and a forward dot-product cone; steering has a finite rate, so the missile can miss. Smart bombs damage only enemies within a wrapped 145 m radius.

Rounds test their traveled segments against enemies and props rather than testing only the final point. Terrain collision samples intermediate points along that segment. Virus packets apply gravity and queue infection on ground impact. Other impacts choose dust or splash based on raw terrain elevation. Lifetime expiration removes a projectile without an impact.

## Score, progression, and effects

`ScoreManager.add()` accepts positive or negative changes. A while-loop awards every newly crossed threshold, including multiple thresholds in one large bonus. `next_life` never decreases, preventing repeated rewards for losing and regaining points.

`WaveController.roster()` returns enemy IDs; it does not spawn nodes. `advance()` returns a transition label; it does not decide whether the wave was cleared. Those decisions belong to the controller, which requires no enemies remaining and a living player before entering results.

Mesh factories only construct visuals. Particles have bounded counts and lifetimes; damage is never inferred from a particle touching something. Audio requests are coalesced each rendered frame and assigned to a finite voice pool. The engine sound loops separately. The Dummy audio driver disables playback without affecting gameplay.

`tools/generate_audio.py` builds signed 16-bit mono WAV samples from sine waves and seeded noise. `sample_value()` defines the waveforms; `generate_effect()` encodes samples and writes a file; `main()` supplies the fixed effect order and seed. Refactoring this generator preserved the existing WAV files byte-for-byte.

## HUD and validation

HUD drawing uses a fixed 1280×720 coordinate system scaled to the actual window. Camera-projected markers are converted back into those design coordinates. The HUD reads state; it does not advance enemies, award bonuses, or decide when to respawn. Temporary announcements override persistent flight status while their timer remains active.

The test runners are documented at their entry points:

- `run_tests.gd`: deterministic logic assertions, without a game scene.
- `smoke_test.gd`: live-system regression checks, including controls, assisted landings, weapons, death, victory, and restart. Pointer capture and renderer color checks require a graphical run.
- `endurance_test.gd`: accelerated late-wave simulation and bounded entity checks.
- `visual_check.gd`: deterministic rendered screenshots for inspection.
- `performance_test.gd`: real rendered-frame timing after warmup.

Commands are listed in the main README. After changing flight or collision behavior, run the logic and smoke tests; after changing rendering, also inspect the visual captures. Test code that advances many simulation ticks without real-time waits allows queued audio to finish before shutdown.
