# Golden Hour and Blood Moon weather design

Status: implementation approved and installed in Studio on 2026-10-08; unpublished. User deferred listening ("Use your best judgment; I'll listen later"). Native playback/load, visual previews and lifecycle checks passed; physical-device performance and published audio permissions are unmeasured. Evidence: steal-a-ride/golden-blood-vfx-verification-20261008.json.

## Intent

Make the two remaining weather events immediately recognizable through their atmosphere and sound, matching Steal a Mount's magical fantasy style. Keep escape routes, guardians, pet silhouettes and gameplay warnings readable. There are exactly three events: Thunderstorm, GoldenHour and BloodMoon.

## Approved direction

| Event | Visuals | Audio |
| --- | --- | --- |
| GoldenHour | Warm sunset, gentle sun rays, sparse floating golden sparkles | Soft arrival chime and quiet airy ambience |
| BloodMoon | Dark crimson night, larger red-looking moon, sparse drifting crimson particles | Low arrival tone and soft wind/rumble |

Use native Sky, SunRaysEffect, ColorCorrectionEffect and ParticleEmitter objects, plus existing audio helpers. No ground fog, camera shake or repeated flashes for either event. Audio remains below regional music, escape music and guardian warnings. Effects are local to each client.

## Final implementation parameters

- GoldenHour: ClockTime 17.5, existing warm WeatherTint RGB255,225,160 / brightness +0.05; SunRays intensity 0.06 and spread 0.8.
- BloodMoon: ClockTime 21, red WeatherTint RGB255,120,120 / brightness +0.03; MoonAngularSize 16 (baseline11). Native moon appears red in Studio. Old brightness-0.12 plus native night obscured Forest/Cosmic; +0.03 recovers route and guardian visibility in same-position previews.
- User-requested visibility follow-up (2026-10-08): Home screenshot still looked too dark. BloodMoon now tweens Ambient toRGB150,130,140 and OutdoorAmbient toRGB160,140,150, lifting surfaces while keeping the night sky/red moon. Capture initial Ambient/OutdoorAmbient and restore them on every other/clear/unknown weather using the existing cancellable2s Lighting tween. Mild initial fill was too subtle; stronger final values inspected in Home/Forest/Tundra/Cosmic. Evidence: steal-a-ride/blood-moon-visibility-verification-20261008.json;27 checks PASS +48 compile.
- Native sparkles texture for both events, with golden RGB255,215,110 versus crimson RGB230,65,95. Golden rate 12/s desktop, 6/s touch-only; Blood rate 8/s desktop, 4/s touch-only. Lifetime 2–3 seconds, size 0.25 fading to zero, slow upward drift; no world lights or collidable parts.
- Camera-following invisible emitter box 32x12x32 desktop / 24x10x24 touch-only. Follow current camera at 10Hz, tolerate nil/replaced cameras and respawns. Capture the exact emitter in its follow task.
- Visual transitions take 2 seconds; existing loop helper crossfades audio over 1.2 seconds. Keep at most one non-storm particle holder, one weather sun-rays object and one weather arrival sound.
- Final audio: Golden uses AmbienceForest9112835068 (Neighborhood Birds2) at0.06; Blood uses AmbienceTundra4175285709 (Blizzard) at0.09. Both arrival cues use the existing Cosmic hatch accent9116418035 (Magic Tone Falling Shimmer Flanged3), pitches1.25/0.6 and volumes0.18/0.12, bounded to3s. Roblox asset metadata rejected initial Cosmic ambience (rocket-engine rumble) and favored the approved fallback/cue. Actual final loops/cues loaded and played. Subjective listening is deferred by the user. Distinct client-local aliases preserve all regional template volumes and share Mama ducking.
- Capture original ClockTime, Ambient, OutdoorAmbient and Sky moon size before applying weather. Clear/Thunderstorm restore these values; GoldenHour also restores ambient fill. Remove non-storm particles and disable sun rays when appropriate. Cancel replaced visual tweens and destroy an old arrival sound on weather change. An identical sync must not replay the arrival cue or duplicate particles.

## Global constraints

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

## Acceptance

The native sun/moon and color mood distinguish each event in actual Studio previews. Particle textures and audio load and play. No stale particles, cues, loops, lightning or clouds survive switching/end. Missing optional audio templates cannot block visual/gameplay setup. Respawn, flight, camera replacement and touch-only checks pass. Existing offline regression suite and Luau compile checks pass. Physical phone performance and published-server audio permissions require separate live checks if unavailable locally.
