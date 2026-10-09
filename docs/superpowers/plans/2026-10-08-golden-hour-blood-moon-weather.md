# Golden Hour and Blood Moon SFX/VFX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Golden Hour and Blood Moon distinct magical fantasy visuals and quiet audio while preserving gameplay and Thunderstorm effects.

**Architecture:** Extend the existing weather sections in ClientMain and Effects. ClientMain owns native lighting and particles; Effects uses independent local sound aliases with its existing loop/voice helpers. Workspace.Weather remains the sole event input; there are no server changes or new modules.

**Tech Stack:** Roblox Luau, native Lighting/Sky/SunRaysEffect/ParticleEmitter/Sound/TweenService, existing Python-driven Luau test harness, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-10-08-golden-hour-blood-moon-weather-design.md`. Read both documents before execution.

**Status:** Implementation complete and installed in Studio on 2026-10-08; unpublished. User approved "go with this" and deferred subjective listening. Final 27 groups PASS +48 source compile; both installed sources match local in full after CR normalization. Production Config exactly restored; baseline clock14.5/moon11, Edit mode, original desktop emulator restored. Original sources backed up locally and in ServerStorage.GoldenBloodVFXBackup20261008.

## Execution ledger

- Preflight: weather interfaces and budgets agree across both tasks/spec; native Sky exists; existing voice bounds cues and loop applies Mama SoundGroup. No source divergence.
- Task 1 complete locally: actual-source golden sunset assertion failed against original, then 27 groups PASS +48 sources compile. Evidence: before-golden-blood-vfx-20261008/task1-red.txt and task1-green.txt. Studio verification remains in Task 2.
- Task 2 audio RED→GREEN: golden audio assertion failed against original; aliases/cues then passed 27 groups +48 compile. Native moon preview is red and size16, native sparkles fetch Success.
- Ruling: user says "Use your best judgment; I'll listen later" because tools cannot hear Studio. Asset metadata rejects Cosmic rocket-engine ambience and favors approved Forest fallback (9112835068, volume0.06) plus Cosmic magic shimmer (9116418035, pitch1.25/0.6, volume0.18/0.12, bound3s); Blood uses loaded Blizzard4175285709 at0.09. Playback/load verification proceeds, subjective listening remains with user. Cost if wrong: retune these existing sound choices after listening.
- Ruling: native night plus old brightness-0.12 obscured Forest/Cosmic routes in Play screenshots. Keep crimson tint/clock21/moon16 and use brightness+0.03; same-position previews recover lane/guardian silhouettes without adding owned lighting properties. Spec readability takes precedence over initial tuning candidate. Cost if wrong: night may need further visual tuning on other displays.
- Task 2 complete: final cues/loops observed loaded/playing at chosen values; all candidate preloads/native texture fetch Success. Three real .2s cycles keep one holder/loop per name and restore baseline; actual R flight, nil/replaced camera and respawn checks pass for all3 weather. Real carried egg EscapeMusic dominates weather, native Mama group ducks all loops to0.2. Golden/Blood screenshots cover Forest/Tundra/Cosmic and native sun/red moon. iPhone17Pro emulation reports hybrid input; touch-only settings6/4,width24 previewed explicitly, actual-source harness covers touch-only branch. Final clear test waits17.2s without late thunder. Evidence: steal-a-ride/golden-blood-vfx-verification-20261008.json; six saved PNG previews under golden-blood-vfx-20261008.
- Final review: fresh read-only weather_review found no actionable correctness issues. Parent completed pending installed-source/config/emulator restoration checks; all passed. No deferred minor findings.
- Final Ruling: physical-device FPS and published-server asset permissions remain unmeasured; user listening deferred as above. Studio emulation checks/metadata/playback establish available evidence, with limits recorded. Cost if wrong: follow-up device or live-session tuning may be needed.
- Final Ruling: preserve already-playing Thunderstorm one-shot behavior; it may finish naturally, while queued thunder cancels (verified). Matches explicit storm-preservation scope. Cost if wrong: an existing clap may continue after weather changes.
- Authorized follow-up (2026-10-08): user screenshot judged too dark; user approved native ambient fill. ClientMain captures original Ambient/OutdoorAmbient and adds BloodMoon RGB150,130,140 /RGB160,140,150 to the existing Lighting tween. Other weather/clear/unknown restores originals. Actual-source assertions RED→GREEN,27 groups PASS +48 compile; native3 rapid cycles and all mood restoration paths pass; Home/Forest/Tundra/Cosmic/red moon previews checked. Production Config/source equality/normal Edit ambient confirmed. Evidence: steal-a-ride/blood-moon-visibility-verification-20261008.json. Original ambient/sky-only ownership constraint expanded by this explicit user request.
- Ruling: repository has no commits; use original-file backups/full-source guards and this ledger instead of commit-dependent skill scripts/worktree. Matches plan preparation; cost if wrong: rollback uses preserved files rather than Git.

## Global Constraints

- Keep exactly three weather events: Thunderstorm, GoldenHour, BloodMoon.
- Keep all existing mutation chances, income/speed bonuses, guardian multipliers and event timings unchanged.
- Keep production StealARide_v2 and legacy StealARide_v1 unchanged outside temporary isolated Play verification.
- Preserve Thunderstorm rain/clouds/lightning/thunder and F Get off / R flight controls.
- Use native Roblox effects and existing helpers; add no dependencies, new weather service or UI controls.
- Use touch-only detection TouchEnabled and not KeyboardEnabled; cap non-storm particles at 36 live desktop / 18 live touch-only by rate times maximum lifetime.
- Keep routes, guardians and warnings readable; no new flashes, camera shake or dense fog.
- Keep audio subordinate to escape/guardian cues and respect existing Mama ducking.
- Restore owned lighting properties and clean up owned effects on every weather transition, including rapid switches and nil/unknown weather.
- Verify in isolated test stores; preserve backups and do not publish or commit unrelated untracked files.

## Review Focus

1. Golden → Blood → Storm → clear before a fade completes: the newest mood wins, old particles disappear and original lighting returns. Task 1 transition assertions and Task 2 live sequence.
2. Joining during active weather / repeated sync: one holder/loop and no repeated arrival cue; effects initialize from the current attribute. Tasks 1 and 2 assertions.
3. Nil/replaced camera, respawn and flight: no follow-loop errors, no ground-attached effects at the wrong height. Task 1 coroutine checks and live camera/respawn checks.
4. Touch-only and hybrid input: touch-only stays at 18 live particles maximum; keyboard devices retain desktop budget. Task 1 budget assertions and touch preview.
5. Missing or failed audio, Mama and escape overlap: weather cannot block gameplay or mute warnings, stale cues stop and region templates remain unchanged. Task 2 mocks, preload observations and overlap Play checks.

---

## File map and execution preparation

- Modify `steal-a-ride/src/StarterPlayer/StarterPlayerScripts/ClientMain.luau`, existing `-- Weather:` section (~181–247): lighting, sun rays, non-storm particles and transition ownership.
- Modify `steal-a-ride/src/StarterPlayer/StarterPlayerScripts/Effects.luau`, existing `local thunderToken` → `local REGIONS` section (~696–725): local audio aliases, weather cues and cleanup; existing `loop` and `voice` helpers stay reusable.
- Modify `steal-a-ride/tests/run_feedback_checks.py`, existing `storm_harness()` (~532–616): extend the real-source boundary harness for all three events. Retain every Thunderstorm assertion, changing broad “no Part” checks to “no RainEmitter” when another weather legitimately owns a Part.
- Update `HANDOFF.md` and `steal-a-ride-build-log.md` at completion. Store local/Studio original-source backups and verification evidence alongside prior weather backups.
- No Config or EventService changes, no new SoundService assets installed in Edit: sound aliases are client-local copies of existing templates.

After plan review: refresh Studio inventory/state, select Steal a Mount place 123937616497204, compare both full sources with local CR-normalized content, back up originals to `steal-a-ride/before-golden-blood-vfx-20261008/StarterPlayer/StarterPlayerScripts` and disabled scripts in `ServerStorage.GoldenBloodVFXBackup20261008`. Stop on meaningful divergence and reconcile it before writing. The repository has no commits and all files are untracked: use file backups and full-source comparisons instead of creating an unrelated initial commit/worktree.

### Task 1: Native lighting and sparse weather particles

**Files:** ClientMain weather section; run_feedback_checks.py storm_harness.

**Interfaces:** Consumes `workspace:GetAttribute("Weather"): string?`, `UserInputService.TouchEnabled/KeyboardEnabled`, `Lighting`, `workspace.CurrentCamera`. Produces local `syncWeather(): ()` with unchanged Weather attribute subscription. It owns `WeatherMotes` (Part), `WeatherSunRays` (SunRaysEffect) and only ClockTime/MoonAngularSize in the existing Sky. It leaves biome Atmosphere/BiomeTint and Mama tint ownership intact.

- [x] **Step 1: Extend the boundary stubs and add failing behavior assertions.**

Add baseline `Lighting.ClockTime=14.5`, a Sky with `MoonAngularSize=11`, and `Lighting:FindFirstChildOfClass("Sky")`. Add `Enum.NormalId.Top`, `Enum.ParticleOrientation.FacingCamera`, and `Vector3.zero`. Add a name finder that scans the existing `objects` list. Test actual source, not a duplicate weather implementation:

```lua
local function named(parent,name)
 for _,obj in objects do if obj.Parent==parent and obj.Name==name then return obj end end
end
weatherName="GoldenHour";syncWeather()
local gold=named(workspace,"WeatherMotes")
assert(gold and Lighting.ClockTime==17.5,"golden sunset and particles")
local rays=named(Lighting,"WeatherSunRays")
assert(rays and rays.Enabled and rays.Intensity==.06,"gentle golden sun rays")
local particles=find(gold,"ParticleEmitter")
assert(particles.Rate*particles.Lifetime.Max<=36,"desktop live budget")
syncWeather();assert(named(workspace,"WeatherMotes")==gold,"duplicate sync reuses holder")
weatherName="BloodMoon";syncWeather()
assert(gold.Parent==nil and sky.MoonAngularSize==16 and Lighting.ClockTime==21,"blood replaces golden")
assert(not rays.Enabled,"blood has no sun rays")
weatherName="Thunderstorm";syncWeather()
assert(not named(workspace,"WeatherMotes") and sky.MoonAngularSize==11 and Lighting.ClockTime==14.5,"storm restores base sky")
weatherName=nil;syncWeather()
assert(not named(workspace,"WeatherMotes") and not rays.Enabled,"clear removes nonstorm effects")
```

Add checks for touch-only rates/lifetimes, hybrid keyboard budget, nil and replaced cameras by resuming the captured follow coroutine, unknown weather restoring baseline, and active-weather initialization by running the extracted block with `weatherName="BloodMoon"` before its initial `syncWeather()`. The Sky stub must be declared before the extracted block. Native tween cancellation is additionally checked in Play because the boundary stub applies goals immediately.

- [x] **Step 2: Run the red check.**

```powershell
python -X utf8 steal-a-ride/tests/run_feedback_checks.py --runtime "$env:TEMP/steal-a-mount-luau-0.741"
```

Expected: new GoldenHour assertions fail against the current tint-only source. Preserve the failed output as red evidence; fix stub incompatibilities separately from implementation defects.

- [x] **Step 3: Add mood ownership next to WEATHER_LOOK and integrate into syncWeather.**

Use a small local table for the two visual parameters, not a new Config subsystem:

```lua
local sky = Lighting:FindFirstChildOfClass("Sky")
local baseClock = Lighting.ClockTime
local baseMoonSize = sky and sky.MoonAngularSize
local rays = Instance.new("SunRaysEffect")
rays.Name, rays.Enabled, rays.Intensity, rays.Spread = "WeatherSunRays", false, 0.06, 0.8
rays.Parent = Lighting
local MOODS = {
 GoldenHour = {clock=17.5, color=Color3.fromRGB(255,215,110), rate=12},
 BloodMoon = {clock=21, color=Color3.fromRGB(230,65,95), rate=8},
}
local activeMood, motes, clockFade, tintFade, moonFade
```

At the start of the existing syncWeather, read Weather once. Return on an identical normalized weather after first initialization. Before replacing a tween call `:Cancel()` on its retained handle. Keep existing WeatherTint goals, and tween ClockTime to `MOODS[weather].clock` or `baseClock` over 2 seconds. Tween native MoonAngularSize to 16 only for BloodMoon, otherwise `baseMoonSize`, if Sky exists. Enable rays only for GoldenHour. Destroy the previous motes holder before creating the next; clear weather, unknown weather and Thunderstorm create none. Preserve the existing rain/cloud branch verbatim apart from using the already-read weather value. Use a separate initialized boolean so initial nil weather still initializes.

The actual particle creation block is:

```lua
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local width = touchOnly and 24 or 32
motes = Instance.new("Part")
motes.Name = "WeatherMotes"
motes.Anchored, motes.CanCollide, motes.CanTouch, motes.CanQuery = true, false, false, false
motes.Transparency, motes.Size = 1, Vector3.new(width, touchOnly and 10 or 12, width)
local cam = workspace.CurrentCamera
if cam then motes.Position = cam.CFrame.Position end
local emitter = Instance.new("ParticleEmitter")
emitter.Name, emitter.Texture = "WeatherDrift", "rbxasset://textures/particles/sparkles_main.dds"
emitter.Color = ColorSequence.new(mood.color)
emitter.Rate, emitter.Lifetime = mood.rate * (touchOnly and 0.5 or 1), NumberRange.new(2,3)
emitter.Speed, emitter.Acceleration = NumberRange.new(0.3,0.8), Vector3.new(0,0.15,0)
emitter.EmissionDirection, emitter.SpreadAngle = Enum.NormalId.Top, Vector2.new(180,180)
emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,0.25),NumberSequenceKeypoint.new(1,0)})
emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.2,0.45),NumberSequenceKeypoint.new(1,1)})
emitter.LightEmission, emitter.LightInfluence = 0.65, 0
emitter.Parent, motes.Parent = motes, workspace
local holder = motes
task.spawn(function()
 while holder.Parent do
  local current = workspace.CurrentCamera
  if current then holder.Position = current.CFrame.Position end
  task.wait(0.1)
 end
end)
```

Here `mood` is the current `MOODS[weather]`; execute this block only when it exists. Do not instantiate a second Sky or mutate moon texture/star count/latitude. If Sky is missing, retain color/particles safely and report that the requested visible moon needs Studio's native Sky restored.

- [x] **Step 4: Run the green check and inspect the focused diff.**

Run the same Python command. Expected: all existing groups plus the expanded weather assertions pass and all Luau files compile. Verify only the weather section changed and particle holders cannot collide/query/touch. Save test output; do not commit unrelated untracked files.

### Task 2: Quiet weather audio and integrated Studio verification

**Files:** Effects weather section; run_feedback_checks.py storm_harness; HANDOFF.md and build log after verification.

**Interfaces:** Consumes the unchanged Weather attribute and `SFX` templates. Reuses `loop(name:string,on:boolean,volume:number?): Sound?`, `voice(entry,part:BasePart?,volumeScale:number?): Sound?`, and `mamaMix`. Produces local `syncWeatherSound(): ()`, independent aliases `GoldenWeatherLoop` and `BloodWeatherLoop`, and at most one active weather arrival Sound. No changes to region/escape loop names or original template volumes.

- [x] **Step 1: Add failing audio assertions to the real-source harness.**

Extend the SFX boundary with cloneable templates and use a `voice` stub recording entries and returning destroyable Sounds. Update the loop stub to record each name separately instead of asserting only Rain. Keep play("Thunder") assertions unchanged. Define `Config.Sounds.RarityReveal=1841391669` in the boundary and a dummy `mamaMix`. The new checks include:

```lua
weatherName="GoldenHour";syncWeatherSound()
assert(loopStates.GoldenWeatherLoop and not loopStates.BloodWeatherLoop and not rainLoop,"golden audio only")
local firstCue=weatherCue
local firstCount=#cues
syncWeatherSound();assert(#cues==firstCount,"identical weather does not replay cue")
weatherName="BloodMoon";syncWeatherSound()
assert(firstCue.Parent==nil and loopStates.BloodWeatherLoop and not loopStates.GoldenWeatherLoop,"blood replaces golden cue/loop")
assert(cues[#cues][2]<cues[firstCount][2],"blood entry tone lower than golden chime")
weatherName=nil;syncWeatherSound()
assert(not loopStates.GoldenWeatherLoop and not loopStates.BloodWeatherLoop and weatherCue==nil,"clear stops weather audio")
```

Also run the extracted section with missing ambience templates and assert no exception; assert original template volumes are unchanged. Task 1's join-during-weather case also initializes audio once. Run the Python command and confirm the new audio checks fail before implementation.

- [x] **Step 2: Reuse local audio aliases and add once-per-transition cues.**

Insert setup within the harness extraction boundaries, after `local thunderToken = 0` and before syncWeatherSound:

```lua
for name, sourceName in {GoldenWeatherLoop="AmbienceCosmic", BloodWeatherLoop="AmbienceTundra"} do
 local source = SFX:FindFirstChild(sourceName)
 if source then
  local alias = source:Clone()
  alias.Name, alias.Volume = name, name=="GoldenWeatherLoop" and 0.06 or 0.09
  alias.Parent = SFX
 end
end
local lastWeather, weatherCue, weatherSoundInitialized
```

At the beginning of syncWeatherSound, read Weather, return for an identical value after initialization, then destroy `weatherCue` if present and clear it. Call `loop("GoldenWeatherLoop", weather=="GoldenHour",0.06)` and `loop("BloodWeatherLoop",weather=="BloodMoon",0.09)`. Retain the storm token/flash/thunder logic, which must still cancel on every real transition. Add:

```lua
if weather=="GoldenHour" or weather=="BloodMoon" then
 weatherCue = voice({Config.Sounds.RarityReveal, weather=="GoldenHour" and 1.25 or 0.6,
  weather=="GoldenHour" and 0.18 or 0.12, 3})
 if weatherCue then weatherCue.SoundGroup = mamaMix end
end
```

Aliases exist only in the client copy of SFX; regional loop templates remain untouched. The existing voice helper bounds the arrival sound lifetime to 3 seconds even on load/play failure. No new asset IDs, installer or dependencies. These exact initial assets/pitches are audition candidates, not claims about their character.

- [x] **Step 3: Run offline checks and install with full-source guards/backups.**

Run the Python command. Expected: expanded weather behavior and all previous groups pass; all 48 current Luau sources compile. Install both sources only after comparing current Studio originals to the backup baseline. Record installed source equality (normalize CR only), not just matching lengths. Leave Config untouched until the isolated Play setup.

- [x] **Step 4: Start an isolated Play session and validate assets/audio character.**

Back up Config Source in Edit, replace only DataStoreName and LegacyDataStoreName with fresh `SAMGoldenBlood_<timestamp>` / `SAMGoldenBloodOld_<timestamp>` names, then start Play. Wait for client initialization. Force Weather on the Server; inspect native effects/real Sound clones on Client. Preload actual weather Sound objects with ContentProvider and record fetch status, IsLoaded, TimeLength and actual IsPlaying.

Audition Golden ambience and pitched chime, then Blood wind and lower tone. Acceptance: quiet magical/airy gold, soft wind/low tone for blood; no spoken voice, alarming chase cue or dominant melody. If a candidate fails, audition the already-installed AmbienceForest and AmbienceDesert templates as the respective ambience alternatives, and the existing Cosmic hatch accent (Config.EggFX.themes.Cosmic.sound) as the cue alternative. Use the first candidate that satisfies the stated character and loads; record the exact chosen source/ID/pitch/volume in the spec, plan and evidence. If none fits, report the asset-selection limitation before claiming audio complete rather than substituting a guessed asset.

- [x] **Step 5: Verify transitions, appearance and overlap in Studio.**

Preview Golden and Blood with a camera aimed at the native sun/moon and along escape routes. Verify the moon appears red under the actual composed tint; verify shadows/text/guardians stay readable across Forest, Tundra and Cosmic. Test gold→blood→storm→clear with 0.2-second gaps, then wait 2.2 seconds: ClockTime14.5, moon size11, no motes/clouds/rain, rays disabled, lightning0, weather loop volume0/no late thunder. Repeat three cycles and confirm one holder/loop maximum. During each event respawn, fly, replace camera and briefly set CurrentCamera nil, then restore it; no console errors or stale holder. Preview touch-only rates6/4 and widths24, preserving emulator settings. Test while carrying an egg and while MamaPhase is active: warnings remain audible and weather loops share Mama ducking. Record screenshots/evidence and limitations; do not claim physical phone FPS or live permission checks if not measured.

- [x] **Step 6: Restore and finalize verification.**

Stop Play, restore exact production Config Source, remove temporary verification scripts/attributes from Edit, and confirm Edit mode plus full equality of both final sources. Re-run the Python suite after any tuning. Update HANDOFF/build log, mark both plan tasks complete, store evidence in `steal-a-ride/golden-blood-vfx-verification-20261008.json`, and request a focused final review under the implementation workflow. Report installed/unpublished status and any unmeasured device/live-audio checks. Publication stays with the user.

## Plan self-review

Checked: all approved visual/audio requirements map to Tasks 1–2; interfaces retain the existing weather attribute/functions; five review risks have explicit checks; no server/profile/UI expansion. Initial sound/brightness tuning was resolved through the execution rulings above. Only the two client weather sections changed; gameplay, production stores and Thunderstorm remain preserved. No publish, commit or push.
