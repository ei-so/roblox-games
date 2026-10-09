# Relentless guardians: leash chase (design)

Status: design approved in chat 2026-10-09 (all decisions below are the user's). Not implemented.
Trigger: user bug report: the Mystic Grove spider stops chasing once the player crosses into Cosmic, and its rage
only shows after it leaves its biome. User wants a "Steal an Egg" style chase: the guardian never lets go.

## Goals

- A guardian that has left its biome never falls more than X behind its target; past X it teleports back to X.
- Rage is one consistent state from leaving the biome to the end of the chase (no burst / winded / final charge, no tiredness).
- Escapes are decided by speed: a well-upgraded rider is slightly faster than the guardian.
- Applies to every guardian except the Forest Chicken.

## Current behaviour being replaced (confirmed in source)

- `GuardianService`: chase ends in the safe zone, on a usable escape patch (`huntable` returns nil, prey dropped, guardian
  goes home), or on a catch. Rage phases via `nextPhase`: 4 s burst x1.15 on leaving its biome, then winded x0.85,
  final surge x1.3 (deeper guardians: once the prey is in the Forest; Chicken: 60 studs from the safe line).
  `chaseFactor`: wind-up from patrol pace, tiredness after 12 s, Blood Moon (never stacked with burst/surge).
- Targeting: nearest huntable prey each frame (`findTarget`), switching freely.
- Speed does NOT stack across mounts (fastest only); abilities DO stack.
- Gear: Speed Soda +25% for 20 s; Net Gun / Slip Trap slow players.

## Design

### Chase phases (all guardians except the Chicken)

**Phase 1: target inside the guardian's own biome.** As today minus the rage stages: wake, wind-up, lunge, pathing,
catch-up-when-out-of-sight, tiredness, Blood Moon boost. The rider can build a lead.

**Phase 2: target outside the guardian's own biome** (the target's position decides, wherever the guardian is).
- On entering phase 2 the guardian snaps to X behind the target (if further than X) and enrages: red glow (existing
  `Raging` attribute + Highlight), full speed, no tiredness, no Blood Moon boost.
- Leash: every frame, if the horizontal distance to the target exceeds X, teleport to the point X from the target on the
  line from the target toward the guardian's current position. Flyers (Swan, Dragon) at the target's height; walkers at
  their home height.
- X = catch reach + `Config.Guardian.leashBuffer` (15, tuned by the sim). Catch reach = `catchRadius + g.radius`, so
  every guardian feels equally close regardless of size.
- Escape patches (any biome, ability must match that biome's lane): while the target stands on one, the guardian stays
  in the chase but holds position (no advance, no catch). Stepping off resumes the chase; the leash applies as normal.
  Patches are breathers, never escapes.
- Dash unchanged (2x for 1.5 s, 8 s cooldown): in phase 2 it cannot build a lead past X but pushes a closing guardian
  back out to X (clutch save).
- The chase ends only by crossing the safe line or a catch (drop egg, fling, stun, as today); then the guardian calms
  and walks home.

**Forest Chicken:** unchanged gentle chase inside the Forest: no leash, no rage (its burst/surge are removed too).

### Targeting

Lock-on: the guardian keeps its current target until that chase ends (home or caught), then picks the nearest remaining
carrier of its eggs. If that carrier is already outside the biome, phase 2 starts immediately (snap to X).

### Snap presentation

Instant teleport with the guardian's signature puff (its `Config.GuardianFX` step burst / aura colours) at the old and
new position plus a short sound. Server signals each snap through an attribute; clients play the effect.

### Speed retune ("speed decides")

- Phase-2 outcome: rider carry speed > guardian speed keeps the guardian at X all the way home; slower riders are caught
  after about (X - catch reach) / (speed difference) seconds unless they Dash, drink Soda or stand on a patch.
- "Well-upgraded" for biome b = the ride speed a typical player has when they FIRST attempt b (best mount from earlier
  biomes, its usual rarity, saddle level at that time), taken from the pacing sim.
- Normal egg weight (`carry`) per biome 2-8 set so well-upgraded speed x weight ≈ guardian speed x 1.05.
  If a biome would need weight > 1.0, flag it and lower that guardian's speed instead.
- Secret Egg weight: same formula using top upgrades (best rarity, high saddle) so only strong riders bring one home.
- Guardian speeds, mount speeds, saddle and arch signs unchanged.
- Blood Moon: boosts guardians in phase 1 only.
- Speed Soda: +10% for 20 s (was +25%). Player-facing text never shows the percentage: "Speed Boost for 20s".
  Nets and traps unchanged (counterplay: slow a rival into their guardian's reach).
- Pacing targets to keep: first Cosmic about 3 h real, first Mystic Grove about 30-45 min after it.

### Mystic Grove

Corridor and cap chain stay; caps become breathers. Unpublished What's New v3 line "Hide on the last cap, then slip out
of the grove before it softens" becomes wrong and is reworded.

### What's New

New entry v4 "Relentless guardians": the guardian follows you once you leave its biome and never falls far behind,
it stays enraged until you are home or caught, Dash can save you when it closes in, Speed Soda is now a Speed Boost
for 20s. v1-v2 are published and frozen; v3 is unpublished and may be edited.

## Components

- `ServerScriptService/Services/GuardianService.luau`: remove `nextPhase`, `nearHome`, burst/winded/surge; add lock-on
  target, phase decision, leash snap, patch hold; `huntable` no longer drops prey on a patch; `chaseFactor` applies
  tiredness and Blood Moon in phase 1 only. Pure helpers for testing: leash point, phase decision, target choice.
- `StarterPlayer/StarterPlayerScripts/Effects.luau`: snap puff + sound; drop the `Winded` tier.
- `ReplicatedStorage/Shared/Config.luau`: remove `burstMult/burstSeconds/windedMult/rageDistance/rageMult`; add
  `leashBuffer`; retuned `carry` per biome and Secret weight; `Gear.soda.boost = 0.10`; Guide tips that mention the old
  rage stages; What's New v3 rewording + v4.
- `ServerScriptService/Services/GearService.luau` (+ shop/gear UI text if it shows the soda %): "Speed Boost for 20s".
- `tools/pacing-sim`: phase-2 leash chase model; script that derives carry weights; pacing report.
- `tests/run_feedback_checks.py`: guardian harness rewritten for the new pure helpers; soda text check.

## Order of work

1. Pacing sim: leash model, derive carry weights, check pacing. Report numbers to the user BEFORE any game change.
2. Code changes with tests first (leash point, phase decision, lock-on, patch hold, soda).
3. Install in Studio (targeted edits, Studio == local), then Play checks: spider keeps chasing through Cosmic and
   beyond (the reported bug), leash snap + puff, hold at a patch, Dash save, Chicken unchanged, Blood Moon phase 1 only,
   soda text. Then the user publishes.

## Out of scope

Multiplayer decoy plays, new gear, changes to mounts/saddle/guardian base speeds (unless a biome is flagged by the sim),
the Mystic Grove map.
