# CHRONO: Shattered Timeline

An open-world time-travel sandbox prototype built in **Godot 4.3**. This is the
**first playable milestone** from the CHRONO game design bible:

> A player can rewind a thrown object, freeze a moving hazard, jump between three
> versions of one street, plant an item in the past that appears changed in the
> present, and trigger a Time Cop who follows them through an era jump.

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
| WASD / arrows | Move |
| Mouse | Aim |
| E | Pick up / drop / plant / talk |
| Left click | Throw the held object |
| R (hold) | **Rewind** tracked objects near you |
| F | **Stop Time** on the target under the cursor |
| 1 / 2 / 3 | **Era Jump** to 1890 / 2025 / 2150 |
| L | Timeline Ledger |
| H | Help |
| F5 / F9 | Save / load |
| [ / ] | Game speed (accessibility) |
| Esc / P | Pause |

## The milestone loop

1. Throw a crate into the canal, then hold **R** to bring it back.
2. Freeze the vehicle on the road with **F** to cross safely.
3. Jump to **1890** with **1**, grab the oak seed from the market stall, and plant it
   in the Old Square soil.
4. Jump to **2025** with **2**. The parking lot is now Founders' Oak Park. In **2150**
   the ruined plaza is the Oak Biodome.
5. Altering history raises your threat to *Wanted Across Time*, and a Chrono
   Enforcement Bureau agent comes through a telegraphed portal. If it's close and
   able to track you when you jump, it follows you into the next era.
6. To lose it, outrun it, or stun it with a thrown crate or freeze it and then jump.
   If it catches you, you are arrested.

## Project layout

| Path | Purpose |
|---|---|
| `scripts/main.gd` | Orchestrator: powers, era jumps, causality events, threat, Bureau AI, save/load |
| `scripts/era_data.gd` | Authored era snapshots (layouts, palettes, NPC lines, props) |
| `scripts/world_view.gd` | Draws the current era and owns its colliders |
| `scripts/prop.gd` | Rewindable objects (5-second rolling state buffer) |
| `scripts/hazard.gd` | Freezable road vehicle |
| `scripts/time_cop.gd` | Bureau agent: portal → chase, freeze/stun states |
| `scripts/hud.gd` | ChronoCore UI: era/branch, energy, threat (text + shapes), ledger, help |
| `tests/milestone_test.gd` | Headless end-to-end test of the whole milestone |

All visuals are drawn in code, so the project has no art assets yet.

## Develop

```sh
godot --headless -s tests/milestone_test.gd              # run the milestone test
godot --headless --export-release "Linux" build/linux/CHRONO.x86_64
godot --headless --export-release "macOS" build/macos/CHRONO.zip
```

Exports need the Godot 4.3 export templates installed.
