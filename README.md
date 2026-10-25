# CHRONO: Shattered Timeline

A third-person, open-world time-travel game built in **Godot 4.3**, set in
**New Meridian**, a Manhattan-style grid city. It has numbered avenues and
streets, a river, a clock-tower landmark and Founders' Square. The city exists
in five eras on the same block footprints:

| Key | Era | Look | Traffic |
|---|---|---|---|
| 1 | Cretaceous, 66,000,000 BC | Jungle, Sentinel Rock, volcano, pterosaurs | Triceratops herds |
| 2 | 1890 | Brownstones, gas lamps, top hats and bonnets | Horse-drawn carriages |
| 3 | 2025 | Skyscrapers, yellow cabs | Yellow cabs |
| 4 | 2150 | Neon megatowers, implants and visors | Hover-cars |
| 5 | AD 30,000 | Ruined stumps, toxic river, wastelanders | Scrap crawlers |

What you change in the past persists. If you plant the oak seed in 1890 Founders'
Square, the 2025 parking garage is never built, 2150 grows a biodome, and the
far-future wasteland keeps the last living trees on Earth.

## Mechanics and inspirations

- **Time Pad bracer (Tab)** on your left forearm. A radial dial jumps you between
  the five eras, and the world slows while it's open.
- **Back to the Future:** in a vehicle, set a destination on the Time Pad and hit
  **88 mph**. Your own **Chrono Cruiser** (stainless gull-wing, flux core) is
  parked by the square in 2025 and stays wherever and whenever you leave it.
  Showing up in the wrong era in a car is an anachronism.
- **GTA:** hijack anything on the road with **F**: cabs, carriages, hover-cars,
  crawlers, even a triceratops. There's a wanted-style threat level from 0 to 5.
- **Quantum Break:** **Q** Stop Time on the target in your sights, **C** Time
  Dodge, **R** hold to rewind objects. Periodic time stutters freeze the city
  around you.
- **Watch_Dogs:** **T** hacks whatever is under the crosshair. It stalls cars,
  jams a Bureau agent's tracking, or siphons energy from 2150 implants. Aiming at
  a citizen shows a **Profiler** readout.
- **Terminator:** at threat 3+, the Chrono Enforcement Bureau sends the
  **HK-800 Hunter-Killer**, a chrome endoskeleton that can't be destroyed. You
  can only stagger it, freeze or jam it, or escape it through time.
- **Legends of Tomorrow:** the Bureau polices the timeline, and **aberrations**
  (a smartphone in 1890, a dinosaur egg in 2150, a clockwork gear in the
  wasteland) can be carried home and restored to calm the hunt.
- **Weapons (1-4):** Chrono Blade, Pulse Pistol, Stasis Grenade (freezes a 9 m
  area), Phase Blink.

## Play

Builds for **macOS (universal: Intel + Apple Silicon)** and **Linux (x86_64)** are
produced by the `Build` GitHub Actions workflow on every push. Download them
from the workflow run's *Artifacts* section.

- **Linux:** `tar -xzf CHRONO-linux-x86_64.tar.gz && ./CHRONO.x86_64`
- **macOS:** unzip, then drag the app to Applications. The app is ad-hoc signed,
  not notarized, so the first launch needs a right-click on the app and then
  **Open** → **Open**. If macOS still says the app is "damaged", run
  `xattr -cr "/Applications/CHRONO- Shattered Timeline.app"` once.

Or open `project.godot` in the Godot 4.3 editor and press F5.

## Controls

| Input | Action |
|---|---|
| WASD, Shift, Space | Move, sprint, jump |
| Mouse | Look and aim (click to capture) |
| Tab | Time Pad era dial (1-5 / wheel + click) |
| 1-4 / wheel | Weapons and gadgets |
| Left click | Attack, or throw what you're holding |
| E | Pick up / drop / plant / talk / restore aberration |
| F | Hijack or exit a vehicle (W/S throttle, A/D steer, Space brake) |
| Q / R / C / T | Stop Time / Rewind (hold) / Time Dodge / Hack |
| L / H / Esc | Timeline ledger / help / pause |
| F5 / F9 | Save / load |
| [ / ] | Game speed (accessibility) |

## Project layout

| Path | Purpose |
|---|---|
| `scripts/main.gd` | Orchestrator: Time Pad, powers, weapons, vehicles, hacking, causality, threat, Bureau AI, save/load |
| `scripts/era_data.gd` | Authored data for every era: palettes, layouts, outfits, NPCs, aberrations, profiler bios |
| `scripts/city.gd` | Builds an era's city, square, crowd and colliders |
| `scripts/humanoid.gd` | Procedural jointed human with a walk cycle (player, agents, HK unit, citizens) |
| `scripts/vehicle.gd`, `scripts/mesh_kit.gd` | Vehicle models (extruded silhouettes), traffic and animation |
| `scripts/player.gd` | Third-person controller, driving, dodge, bracer and weapon rig |
| `scripts/time_cop.gd` | Bureau agent / Hunter-Killer: portal, street-grid pursuit, freeze/stun/jam |
| `scripts/hud.gd` | Futuristic HUD: holo-panels, compass, minimap, Time Pad dial, speedometer, profiler |
| `scripts/prop.gd` | Rewindable physics objects |
| `tests/milestone_test.gd` | Headless end-to-end test (78 checks) |
| `fonts/` | Orbitron and Rajdhani (SIL Open Font License) |

Every model and visual is generated in code, so the project has no imported 3D
assets.

## Develop

```sh
godot --headless --import                                 # first run: import fonts
godot --headless -s tests/milestone_test.gd               # run the test suite
godot --headless --export-release "Linux" build/linux/CHRONO.x86_64
godot --headless --export-release "macOS" build/macos/CHRONO.zip
```

Exports need the Godot 4.3 export templates installed.
