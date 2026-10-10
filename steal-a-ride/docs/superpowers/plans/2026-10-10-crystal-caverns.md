# Crystal Caverns + Climb Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Biome #9 Crystal Caverns beyond Mystic Grove, guarded by a Crystal Golem, with the new Climb ability as shortcut walls, plus a per-biome checklist test that every current and future biome must pass.

**Architecture:** A checklist test pins every per-biome hook first. Climb splits into a pure shared module (`Shared/Climb.luau`: decisions and landing spots, unit-tested), server enforcement in `AbilityService` (wall-top timer and push-offs) and client movement in a new `ClimbController` LocalScript. Art is made in Blender, imported into Studio, and wired through the existing `CreatureRig` / `CreatureBuilder` paths. The map comes from an edit-time Build tool, like Mystic Grove's.

**Tech Stack:** Roblox Luau (Studio via Roblox MCP), Python test runners that generate Luau and run it with the local runtime (`--runtime <luau dir>`), Python pacing sim (`tools/pacing-sim`), Blender via the Ahuja `mcp-for-blender` connector on port 9877 (new session only), computer use for Studio's 3D Importer.

**Spec:** `steal-a-ride/docs/superpowers/specs/2026-10-10-crystal-caverns-design.md`

## Global Constraints

- Biome id `CrystalCaverns`, guardian display "Crystal Golem", appended after `MysticGrove` in `Config.Biomes`; new field `shortcuts = true` (no escape patches). Lane ability `"Climb"`.
- Species ids `CrystalBeetle` (ability nil), `GemGecko` (`"Climb"`), `CrystalPangolin` (nil, large like Mammoth); weights stay `{ 50, 35, 15 }`.
- `Config.Abilities.Climb = { speedMult = 0.6, crackAfter = 1.5 }`.
- Tags `ClimbWall` (wall faces) and `ClimbTop` (zone on each wall top). Player attribute `ClimbSince` = server time when the crack timer started, nil otherwise.
- Copy (exact): crack toast "The crystal cracks!"; non-Climb toast "Only Climb riders can cross the crystal"; `Config.Patch.messages.CrystalCaverns = "The crystal cracks!"`.
- Walls: 3-4 per biome, gaps alternate sides, every gap fits the Golem's `Config.Guardian.pathRadius` and leads toward the exit (+Z = toward home). Height starts at 40 studs and is set from the Task 2 measurement (must exceed best Jump + Glide height by >= 6 studs).
- Pacing target: first CrystalCaverns median ~37 real min after first MysticGrove (accept 30-45); Dash rider without Climb can escape; Climb adds 10-20 percentage points of escapes at equal ride speed. Numbers go to the user before applying.
- Models: Golem <= 10k tris, pets <= 4k, props <= 2k. Materials/colours only (Glass / semi-transparent quartz, Neon accents), no baked textures.
- Never move, rebuild or retune existing biomes. Port 9876 Blender belongs to another AI: never connect to it.
- Workflow (AGENTS.md): update `HANDOFF.md` at task start and after each task; back up Studio scripts to `ServerStorage.CrystalBackup20261010` and local `steal-a-ride/before-crystal-20261010/` before overwriting; Studio source must equal local (LF djb2) after each install; Play tests use TestHooks `fakeStore` + attr `DataLoadFailed` true. Commit each finished task on `main` (no push); the user publishes.

## Review Focus

1. A rider who climbs, then jumps or Dashes off the top before 1.5 s, must have `ClimbSince` cleared, so the next wall starts a fresh 1.5 s. → Task 3 test `leaving the top resets the timer`.
2. A rider standing exactly on the wall's centre line when cracked or slipped must land on a defined side (exit side for crack, nest side for slip), never inside the wall. → Task 3 test `centre line lands outside the wall`.
3. A Climb rider carrying a Secret Egg (slower carry) still climbs: climb speed comes from current ride speed, with a floor so a slow carrier doesn't stall halfway. → Task 3 test `slow carrier still climbs` (floor 12 studs/s).
4. A future biome added to `Config.Biomes` with no entries must fail the checklist with a message naming the biome and the missing hook. → Task 1 test with an injected fake biome.
5. The Golem must not get stuck at a wall gap while chasing; if a gap is too narrow it falls back to stuck handling and the run becomes unwinnable or trivial. → Task 8 Play check plus a Build-tool assert that each gap width >= `2 * pathRadius + 8`.

---

### Task 1: Biome checklist test

**Files:**
- Create: `steal-a-ride/tests/run_biome_checks.py`

**Interfaces:**
- Consumes: `run_feedback_checks.module`, `run_stick_checks.PRELUDE` (same as `run_nest_checks.py`).
- Produces: `checklist(config_src, vfx_keys) -> str` (a Luau script) and a CLI `python tests/run_biome_checks.py --runtime <dir>`; later tasks re-run it.

- [ ] **Step 1: Write the test.** Python parses `BiomeVFX.luau` for the keys of `local AIR`, `local LIGHT`, `local PATCH` and injects them as Luau sets. The Luau part loops `Config.Biomes` and asserts, each message naming `b.id` and the hook:
  - `#b.species == 3`; each `Config.Species[s]` exists; its `ability` is nil or in `Config.Abilities` and `Config.Icons.Abilities`
  - `Config.Guardians[b.id].recipe`; `Config.GuardianFX.guardians[b.id]` with layers + step; `Config.GuardianSounds[b.id]` idle/alert/chase/step; `Config.guardianRage(b.id)` complete (the same checks as `guardian_fx_harness`)
  - `Config.EggFX.themes[b.id]`; `Config.EscapeMusic.tracks[b.id]`; `Config.Sounds["Ambience" .. b.id]`
  - `AIR[b.id]` and `LIGHT[b.id]`
  - if `b.lane`: `Config.Patch.messages[b.id]` and `Config.Icons.Abilities[b.lane]`; if `b.lane and not b.shortcuts`: `PATCH[b.id]`
  - `Config.Events.secretOddsByBiome[b.id]` unless `b.id` is in `LEGACY_NO_SECRET = { Forest = true, Lake = true }`
  - a `Config.Guide` entry whose `title` equals the spaced id (`b.id:gsub("(%l)(%u)", "%1 %2")`), unless in `LEGACY_NO_GUIDE` = the first 7 biomes

  A header comment lists every hook so the next biome has the list in one place.
- [ ] **Step 2: Add the fake-biome negative check.** A second script appends `{ id = "Fakeland", lane = "Swim", species = {} }` to `Config.Biomes`, `pcall`s the checklist, and asserts it fails with an error containing `"Fakeland"`.
- [ ] **Step 3: Run.** `python tests/run_biome_checks.py --runtime <luau dir>` should print `PASS: 8 biomes complete` and `PASS: a bare new biome fails the checklist`. If a current biome fails, fix the gap in Config, or add it to a `LEGACY_*` set with a comment only if it's a genuine historical exception, and report it.
- [ ] **Step 4: Commit.** `git add steal-a-ride/tests/run_biome_checks.py` with message "Per-biome checklist test".

### Task 2: Climb spike (throwaway, Studio)

**Files:** none kept. Studio only: `Workspace.ClimbSpike20261010` (deleted at the end).

- [ ] **Step 1: Measure the jump ceiling.** In Play, ride the best Jump mount with a Glide mount stacked (for example Glow Deer + Snow Owl); script repeated jumps from flat ground and log the max root Y gain. Record it in HANDOFF.
- [ ] **Step 2: Prove climbing.** Place a 40-stud anchored test slab tagged `ClimbWall`. In a temporary client script, raycast forward from the root (length = half the mount's depth + 2) and set `AssemblyLinearVelocity.Y` to `max(12, rideSpeed * 0.6)` while the ray hits the tagged face and move input points into it. Try a small mount (Chick), a large one (Mammoth) and a flyer (Baby Dragon, grounded while carrying). Record whether each reaches the top and steps onto it.
- [ ] **Step 3: Decide.** Wall height = max(40, ceiling + 6). If a large mount can't crest the edge, note the fix (for example a 2-stud forward nudge at the top) for Task 3. Delete the spike objects, update HANDOFF with the numbers. No commit.

### Task 3: Climb ability (shared rules, server, client)

**Files:**
- Create: `steal-a-ride/src/ReplicatedStorage/Shared/Climb.luau`
- Create: `steal-a-ride/src/StarterPlayer/StarterPlayerScripts/ClimbController.luau`
- Modify: `steal-a-ride/src/ServerScriptService/Services/AbilityService.luau` (`check`, `PlayerRemoving`)
- Modify: `steal-a-ride/src/ReplicatedStorage/Shared/Config.luau` (`Config.Abilities.Climb`, `Config.Icons.Abilities.Climb`)
- Modify: `steal-a-ride/src/StarterPlayer/StarterPlayerScripts/Effects.luau` (crack warning on `ClimbSince`)
- Create: `steal-a-ride/tests/run_climb_checks.py`

**Interfaces:**
- Produces:
  - `Climb.step(since: number?, now: number, onTop: boolean, hasClimb: boolean, crackAfter: number): (string, number?)` returns action `"none" | "start" | "wait" | "crack" | "slip"` and the new `since`
  - `Climb.landing(top: CFrame, size: Vector3, pos: Vector3, action: string): Vector3`: `"crack"` lands 6 studs past the +Z face (exit side), `"slip"` lands 6 studs past the face nearer `pos` (centre line goes to -Z, the nest side), at ground height (`top.Y - size.Y/2 + 3`), same X as `pos`
  - `Climb.lift(rideSpeed: number): number` = `math.max(12, rideSpeed * Config.Abilities.Climb.speedMult)`
- Consumes: `MountService.hasAbility(player, "Climb")`, `inAny` / `inside` in AbilityService.

- [ ] **Step 1: Write failing tests** in `run_climb_checks.py`:
  - `step(nil, 10, true, true, 1.5)` returns `"start", 10`
  - `step(10, 11, true, true, 1.5)` returns `"wait", 10`
  - `step(10, 11.5, true, true, 1.5)` returns `"crack", nil`
  - **leaving the top resets the timer:** `step(10, 11, false, true, 1.5)` returns `"none", nil`
  - `step(nil, 5, true, false, 1.5)` returns `"slip", nil`
  - **centre line lands outside the wall:** for a wall at z = 0 with depth 8, `landing(..., pos at z = 0, "crack").Z == 10` and `"slip"` gives `-10`
  - `"slip"` from z = 3 gives `10`
  - **slow carrier still climbs:** `lift(10) == 12`, `lift(100) == 60`
- [ ] **Step 2: Run, expect FAIL** (module missing): `python tests/run_climb_checks.py --runtime <dir>`.
- [ ] **Step 3: Implement `Climb.luau`** with the three functions above.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Server.** In `AbilityService.check`, find the `ClimbTop` part under the root with `inside`. Call `Climb.step` with a per-player `climbSince` table, mirror it into attribute `ClimbSince` (server time on `"start"`, nil when it clears), and on `"crack"` / `"slip"` call `PlotService.teleport(player.Character, CFrame.new(Climb.landing(...)))` plus the exact toast. Egg kept, no `onPenalty`. Clear the table on `PlayerRemoving`.
- [ ] **Step 6: Client.** `ClimbController`: on `RenderStepped`, if the rider has Climb (`player:GetAttribute("Abilities")` contains "Climb", same check as the other ability scripts), the forward ray hits a `ClimbWall` part and move direction · wall normal < -0.3, set root velocity Y to `Climb.lift(root speed)`. Apply the Task 2 edge fix. Effects: on `ClimbSince` set, play a short crack sound and a white shard burst at the feet.
- [ ] **Step 7: Config.** Add `Climb = { speedMult = 0.6, crackAfter = 1.5 }`. Upload a Climb icon PNG with the Roblox MCP `upload_image` (a gem hand-hold glyph in the ability-icon style) and set `Config.Icons.Abilities.Climb`.
- [ ] **Step 8: Install in Studio and Play-check** on a temporary tagged wall: climb, cross, crack at 1.5 s, land on the exit side with the egg; the same with a non-Climb mount gives a slip toward the nest side; all suites pass.
- [ ] **Step 9: Commit** with message "Climb ability: shared rules, server wall-top timer, client climbing".

### Task 4: Pacing sim (STOP for user approval)

**Files:**
- Create: `steal-a-ride/tools/pacing-sim/crystal.py`, `crystal_gap.py`, outputs `crystal-out.txt`, `crystal-gap-out.txt`

**Interfaces:**
- Consumes: `progress` (`BIOMES`, `NESTZ`, `SPECIES`, `MOUNTBASE`, `run`, `report`, `escapeProb`, `HUMAN`), `rage`, and the installed Mystic values (guard 88, carry .927, mountBase 84, hatch 240, income 16000; leash buffer 30).
- Produces: `crystal.P(guard, income, carry, hatch, mountBase, leadPerWall)` and the chosen numbers for Task 7.

- [ ] **Step 1:** `crystal.py` registers CrystalCaverns after MysticGrove (start: nest depth 700, species with GemGecko = Climb, mountBase 90). It models Climb riders by starting the in-biome race `WALLS * leadPerWall` studs further ahead (`WALLS = 4`), with no change for non-Climb riders.
- [ ] **Step 2:** `crystal_gap.py` sweeps guard speed (from 92 to 100 in steps of 2) and `leadPerWall` (20, 35, 50). For each it prints reached/200, the Mystic→Crystal real-minute gap (p10/median/p90), and escape odds with Dash and without, with and without Climb.
- [ ] **Step 3:** Pick the combination nearest the targets in Global Constraints. **Show the table to the user and wait for approval.** Record the approved numbers in HANDOFF.
- [ ] **Step 4: Commit** the sim and outputs with message "Crystal Caverns pacing sim".

### Task 5: Blender models (new session, STOP for user approval of the look)

**Files:**
- Create: `steal-a-ride/assets/crystal-caverns/*.fbx`, `steal-a-ride/assets/crystal-caverns/previews/*.png`

- [ ] **Step 1:** Confirm the 9877 connector answers (`get_objects_summary` or ping). Work only in the 9877 instance and save it as `steal-a-ride/assets/crystal-caverns/crystal-caverns.blend`.
- [ ] **Step 2: Golem.** Separate objects `Body`, `LeftLeg`, `RightLeg`, `LeftArm`, `RightArm`, with origins at the hinge points (hips and shoulders). Faceted quartz: a low-poly icosphere/box base, beveled, with crystal spikes on the shoulders and a core gem. Under 10k triangles total.
- [ ] **Step 3: Pets.** One joined mesh each for `CrystalBeetle`, `GemGecko`, `CrystalPangolin`. Legs fully below one cut height (record the fraction of height per creature for `CreatureRig.legCuts`). Pangolin about Mammoth size. Under 4k triangles each.
- [ ] **Step 4: Props.** `QuartzWallA/B/C` (sized to the Task 2 height, roughly 60 wide and 10 deep, faceted), `CrystalCluster1-4`, `Boulder1-2`, `CeilingCrack`. Under 2k triangles each.
- [ ] **Step 5:** Render a preview of each into `previews/`, send them to the user, and **wait for approval** of the look. Revise until approved.
- [ ] **Step 6:** Export one FBX per object group (`Golem.fbx` keeps its 5 parts; one FBX per pet; `Props.fbx`), with Y-up and a scale where 1 Blender unit = 1 stud. Commit the assets and the .blend with message "Crystal Caverns models".

### Task 6: Import and rig in Studio (computer use)

**Files:** Studio only (place file). Local record in HANDOFF.

**Interfaces:**
- Produces: `ReplicatedStorage.CreatureMeshSources.CrystalBeetle / GemGecko / CrystalPangolin` (single-mesh models with PrimaryPart); `ReplicatedStorage.CreatureMeshSources.Guardian_CrystalCaverns` (authored model, attributes `Articulated` = true, `Rigged` = true, `RestHeight`; Motor6Ds Body→limb with attributes `Side` ±1, `Front` 0 for legs and 1 for arms, `MotionKind` "Leg"); `ServerStorage.CrystalCavernsAssets20261010` (props).

- [ ] **Step 1:** Load the computer-use skill and get access from the user. Import each FBX with Studio's 3D Importer (File → Import 3D), with anchoring on and the default materials.
- [ ] **Step 2:** Via the Roblox MCP: set the materials/colours (quartz Glass 0.2-0.35 transparency, pale grey/white; Neon core and gems) and move the models into the folders above. For the Golem, add the Motor6Ds and attributes listed under Interfaces (arms use `Front = 1` so `WalkCycle` swings them opposite the same-side leg; no WalkCycle change).
- [ ] **Step 3:** Add `legCuts` entries for the three pets in `CreatureRig.luau` (fractions from Task 5); install the change in Studio.
- [ ] **Step 4:** In Play, run `CreatureRig.install` (or check `CreatureRigsReady`): no `[CreatureRig]` warnings, and `CreatureMeshes` holds all four. A Golem and each pet walk with `WalkCycle` without visible seams. Commit `CreatureRig.luau` with message "Crystal Caverns creature rigs".

### Task 7: Config, effects and sound (checklist RED → GREEN)

**Files:**
- Modify: `steal-a-ride/src/ReplicatedStorage/Shared/Config.luau` (`Biomes`, `Species`, `Guardians`, `GuardianFX.guardians.CrystalCaverns` incl. `rage`, `GuardianSounds`, `EggFX.themes`, `EscapeMusic.tracks`, `Sounds.AmbienceCrystalCaverns`, `Patch.messages`, `Events.secretOddsByBiome`, `Guide`)
- Modify: `steal-a-ride/src/StarterPlayer/StarterPlayerScripts/BiomeVFX.luau` (`AIR`, `LIGHT`, plus rainbow floor spots)
- Modify: `steal-a-ride/tests/run_feedback_checks.py` (movement table row for CrystalCaverns, like MysticGrove's)

- [ ] **Step 1:** Add the `Config.Biomes` entry with Task 4's numbers, `lane = "Climb"`, `shortcuts = true`, the look (pale grey floor, Slate, accent white/cyan, bright atmosphere), and species `{ "CrystalBeetle", "GemGecko", "CrystalPangolin" }`. Run `run_biome_checks.py` and **expect FAIL** naming CrystalCaverns and its first missing hook.
- [ ] **Step 2:** Fill every hook until it passes.
  - `Species`: three entries; Pangolin sized like Mammoth.
  - `Guardians.CrystalCaverns`: gait `biped`, scale chosen so the Golem stands about 20 studs tall.
  - `GuardianFX`:
    - layers: a quartz glint (sparkles, white) and a rainbow sparkle (`color` red→violet via `color2`)
    - step: quartz dust (smoke, pale grey)
    - `rage` overlay: a rainbow shard onset and layer; `rage.sound` = a grinding-stone roar
  - Sounds: pick licensed ids with the Roblox MCP `search_asset` and check each one loads in Play. Ambience: cave drips + crystal chimes. Escape track: an existing APM id.
  - `EggFX` theme: quartz sparkle.
  - `secretOddsByBiome.CrystalCaverns`: from Task 4 (start `{0,0,0,50,30,20}`).
  - `Patch.messages.CrystalCaverns`: the exact copy from Global Constraints.
  - `Guide` entry:
    - title "Crystal Caverns"
    - body: the Crystal Golem guards Crystal Beetle, Gem Gecko and Crystal Pangolin eggs; Climb riders run up the quartz walls and cross the top, which cracks after 1.5 seconds; no Climb? Take the gaps and race home.
  - `BiomeVFX`:
    - `AIR`: slow dust motes and faint rainbow sparks
    - `LIGHT`: bloom ~0.8, threshold ~0.8, rays ~0.2
    - floor spots: a few tinted Neon decals/particles placed by the Build tool, coloured by BiomeVFX
- [ ] **Step 3:** Run all suites (`tests/run_*.py --runtime <dir>`): **expect PASS**, including `PASS: 9 biomes complete`.
- [ ] **Step 4:** Install in Studio (backups first), hash-check against local, commit with message "Crystal Caverns config, effects and sound".

### Task 8: Map Build tool

**Files:**
- Create: `steal-a-ride/src/ServerStorage/BuildTools/BuildCrystalCaverns.luau`
- Modify: `steal-a-ride/src/ServerStorage/BuildTools/BuildPatches.luau:105` (skip biomes with `b.shortcuts`)

**Interfaces:**
- Consumes: `Config.BiomeById.CrystalCaverns`, `workspace.Biomes.MysticGrove` FarZ attribute, `ServerStorage.CrystalCavernsAssets20261010`, `B.buildGuardian("CrystalCaverns")`.
- Produces: `workspace.Biomes.CrystalCaverns` with attributes `EntranceZ`, `FarZ`, `NestZ`, `CrystalBuildVersion = 1`; walls tagged `ClimbWall`, tops tagged `ClimbTop`; Nest; Guardian; `SFX.AmbienceCrystalCaverns`.

- [ ] **Step 1:** Write the tool, following `BuildMysticGrove`:
  - asserts the biome is absent and Config is installed; entrance = Mystic FarZ; depth from Config
  - road extension into a cave mouth; stone floor/walls/ceiling with crack openings + `CeilingCrack` props and light-shaft parts
  - nest at `NestZ`, quartz clusters, boulders kept clear of a 28-stud centre corridor except where the walls cross it
- [ ] **Step 2: Walls.** Place `WALLS` (3 or 4, from Task 4) evenly between the nest and the entrance, using `QuartzWallA/B/C` at the Task 2 height. Gaps alternate left/right; assert each gap width >= `2 * Config.Guardian.pathRadius + 8`. Tag the faces `ClimbWall` and add a `ClimbTop` part (wall footprint, 1 stud high, transparent, CanCollide false, `Headroom` 8).
- [ ] **Step 3:** Run the tool in Studio Edit (ChangeHistory waypoint). Confirm that the older biomes' pivots are unchanged (compare `GetPivot` of each biome model before/after) and the Golem is placed.
- [ ] **Step 4: Golem pathing.** In Play, script a carrier (as in the Mystic playtests) that grabs and takes the gaps, and check the Golem follows through every gap with no stuck fallback. Then do a Climb run over all walls. Log the leads.
- [ ] **Step 5:** Commit the tool and the BuildPatches change with message "Crystal Caverns map build tool".

### Task 9: Verification and release prep

**Files:**
- Modify: `steal-a-ride/src/ReplicatedStorage/Shared/Config.luau` (What's New), `HANDOFF.md`

- [ ] **Step 1: Play checklist** (fakeStore):
  - climb, cross, crack at 1.5 s, exit-side landing with the egg
  - non-Climb slip toward the nest side
  - Golem through every gap
  - Dash escape without Climb
  - Climb run lead vs the Task 4 model
  - Golem patrol/chase/rage FX + all four sounds
  - hatch + Index for all three species
  - Jump + Glide can't reach a wall top
  - 0 new console errors
- [ ] **Step 2:** Ask the user: a new What's New entry v6 "Crystal Caverns!" or lines folded into v5 (if v5 is still unpublished). Add the lines (new biome + Golem, Climb on the Gem Gecko, walls crack after 1.5 s).
- [ ] **Step 3:** All suites pass, Studio == local for every changed script, HANDOFF updated (what's done, what's not verified). Commit with message "Crystal Caverns release prep". The user publishes.
