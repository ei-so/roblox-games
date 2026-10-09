# Steal a Mount Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the authorized feedback improvements while preserving progression and Secret Eggs.

**Architecture:** Extend the existing services and UI in place. Carry one optional species field along existing egg transfers; use a single validated damage handler for both Mama click and hold. HANDOFF.md is the shared execution ledger.

**Tech Stack:** Roblox Luau; official standalone Luau compiler/runtime; Python standard library for offline harness generation and deployment packaging.

**Spec:** `docs/superpowers/specs/2026-10-07-steal-a-mount-feedback-design.md`

## Global Constraints

- Destination place 123937616497204; universe 10769659624; owner eisoisoo.
- Secret Eggs and existing paid-luck restrictions/purchase IDs stay unchanged.
- One writing agent; preserve existing untracked files and original backups.
- Source parity and live backup precede Studio writes; no publication until verified.
- Stop starting tasks at 5% remaining account usage and checkpoint the safe state.
- User authorized inline implementation; review assumptions against the written spec while executing.

## Review Focus

- Returned egg after a refill: do not replace the new occupant or reroll the returning species.
- Older/special saved eggs: valid fallback without changing Secret/Lucky behavior.
- Concurrent Mama click and hold: combined rate limit, alive/range/active-orb/view validation.
- Touch held while camera moves or UI opens: no stuck attack or invisible input capture.
- Narrow screen with long money values and Mama warning: preserve controls and readable objectives.

### Task 1: Species identity and nest supply

**Files:** HatchService.luau, EggService.luau, MamaService.luau under `steal-a-ride/src/ServerScriptService/Services/`; `steal-a-ride/src/ReplicatedStorage/Shared/{Config,CreatureBuilder}.luau`; `steal-a-ride/tests/run_feedback_checks.py`.

**Interfaces:** `HatchService.assignSpecies(egg) -> string?` mutates only a normal egg's species; `CreatureBuilder.buildEgg(biomeId, mutation?, secret?, species?) -> Model` keeps the original three arguments compatible. Persistent egg records add `species: string?`.

- [x] Preserve current sources in `steal-a-ride/before-feedback-20261007`.
- [x] Write and run the offline real-service test; observe chosen Fox egg incorrectly rolling Chick.
- [x] Add normal-egg species assignment and honor valid identities in hatch rolls. Retain special/legacy fallback and existing rarity/luck calculations.
- [x] Include species in deposit, take, pending and Mama loose/hoard paths. Give nest models an internal species attribute; retain it on catch returns.
- [x] Extend egg rendering using existing species palette/features, no name label; verify Secret rendering has no new branch effects.
- [x] Set deeper refill interval to 300 seconds and publish accurate nest stock/deadline attributes for countdown rendering.
- [x] Run `python steal-a-ride/tests/run_feedback_checks.py --runtime "$env:TEMP/steal-a-mount-luau-0.741"`; expected persistence/special/legacy checks and all-source compilation pass. Record the actual outcome in HANDOFF.md.

### Task 2: Mama hold input and contribution clarity

**Files:** MamaService.luau; new `steal-a-ride/src/StarterPlayer/StarterPlayerScripts/MamaInput.luau`; RetentionUI.luau; Config.luau; offline checks.

**Interfaces:** `MamaService.hit(player, orb, origin?, direction?) -> boolean`; RemoteEvent `Remotes.MamaHit` accepts the exact orb and aim ray, server never accepts a damage amount. Player attribute `MamaDamage` reflects accepted hits.

- [x] Add failing service checks for dead/out-of-range/inactive/foreign orbs and combined rolling rate cap.
- [x] Route click and hold through validated hit logic. Add RemoteEvent once in start; require a view ray for hold pulses; raycast must reach the active orb without a solid obstruction.
- [x] Add cancellable mouse/touch hold input, repeat at the configured cap, raycast through current aim and pass ray origin/direction. Exclude consumed UI input and clear on release/focus/phase/character changes.
- [x] Resize Mama status for narrow screens and display personal damage plus conditional reward eligibility; preserve actual reward formula.
- [ ] Run the offline checks and compile. In live Studio, test real mouse/touch, switched spots, release, loss of aim, UI overlays and defeat/escape on isolated data; document unperformed checks explicitly.

### Task 3: Onboarding and responsiveness

**Files:** ClientMain.luau, TutorialUI.luau, Effects.luau, Config.luau; live cash HUD source captured before editing.

**Interfaces:** Existing Tips/TipSeen, Cash/CashPerSecond and SpeedService remain authoritative; no new profile fields.

- [x] Add a pen-income/affordability goal before the saddle instruction; preserve tutorial completion and veteran bypass.
- [x] Fit the hint and Mama/tip cards to available width and defer optional cards during guided onboarding/combat.
- [x] Inspect the live cash hierarchy and source, save it locally, then compact the existing HUD at that owner. Do not guess a second cash controller.
- [x] Set the initial movement calibration from the spec; verify normal mount, dash/soda/water/stun and carrier speed allowance in real service checks.
- [x] Improve clarity of existing chase cues without enabling unrelated guardian pursuits.
- [ ] Compile all scripts; check fresh/returning players and phone/tablet/desktop in Studio. Reproduce the reported collision before changing any map geometry.

### Task 4: Apply and verify

- [x] List Studios, choose the authorized destination, compare touched live sources against the preserved baseline, and stop on drift rather than overwrite it.
- [x] Back up touched Studio sources and apply local source changes in Edit; preserve new modules' intended classes.
- [ ] Run isolated Studio checks and inspect console/rendered input; save a local place backup. Keep live publishing separate from partially verified work.
- [x] Perform one final independent review and correct material findings; update HANDOFF.md with files, exact checks and outstanding device checks.

No blanket commits are planned: the shared repository has no commits and all existing content is untracked. Work in place with snapshots; preserve the other project's files.

Wrap checkpoint: code installed and 13-source Edit parity passed; isolated runtime startup was invalidated by an overlong temporary datastore name. Production Config restored, Studio Edit, update unpublished. See root HANDOFF.md for exact failures and next checks.
