# Steal a Mount feedback update

The user explicitly authorized implementation on 2026-10-07 after reviewing the roadmap and correcting the egg design. Work inline, with frequent shared HANDOFF.md checkpoints. At 5% remaining usage in either account window, finish a safe checkpoint and stop starting new work.

## Intent and scope

Improve the confusing first session, mobile visibility, responsiveness, guardian danger readability, regular nest egg selection and Mama input fatigue. Preserve the existing economy, rebirth progression, monetization IDs, paid-luck restrictions, save data and Secret Eggs. Species effects remain a later update.

## Regular eggs

Assign a species on the server when a regular guardian egg spawns, using its biome's existing 50/35/15 species weights. Each physical egg can be selected independently. Its shell uses the creature's palette and small recipe-derived features as clues; do not label the species. The chosen species must hatch. Rarity remains random under existing luck rules, and mutation still rolls when a nest egg is grabbed.

Keep the species through catch/drop/return, PvP, incubation, saves, pending returns, and Mama's hoard/loose eggs. Never reroll a caught egg's species or overwrite a refilled slot. Old eggs without a species retain a valid weighted fallback. Secret and Lucky reward eggs keep existing species/rarity rules and visuals.

Deeper nests have six spots and refill missing spots together every 300 seconds, even if depleted sooner. Forest keeps eight spots and its one-egg-per-20-second trickle. Expose accurate stock/refill status near each basket. Refill does not replace occupied eggs.

## Mama

Hold mouse/touch over the active weak spot to repeat attacks while aiming and dodging. Releasing, losing focus/aim, death, UI capture, range loss or the fight ending stops attacks. A switched spot must be aimed at again. Both old click input and hold pulses go through one server handler: validate the exact active orb, alive character, 80-stud range, view ray and eight-hit-per-second rolling limit. One accepted pulse does one damage; preserve HP, duration, contribution rewards, PvP pause and egg returns.

Show the player's accepted damage and whether they qualify for Lucky Eggs if Mama is defeated. Reward count remains dependent on final damage share; do not promise an unconditional egg award.

## First session and mobile HUD

Reuse ClientMain/TutorialUI and saved completion. Give one primary objective at a time: choose/steal -> return -> hatch -> ride -> maintain a creature earning in the pen -> affordable saddle upgrade, then the existing protection/gear/Lake goals. Completed/veteran players are not restarted. Defer large optional tip cards during guided onboarding or active combat.

Compact the existing cash HUD at its actual source after inspecting live Studio. Use the established playful palette/font, abbreviated cash and touch-safe margins. Tutorial/Mama overlays fit narrow screens and leave controls and the playfield visible. Preserve purchase odds disclosures and their visibility.

## Movement and escape

Initial calibration: walking 16 -> 20, biome mount bases and guardian speeds both +25%, rarity/mutation/saddle bonuses preserved. Keep SpeedService and its anti-speed allowance authoritative. Treat these as tuning values requiring live escape checks. Reuse existing chase audio/heartbeat and identify the egg's actual pursuing guardian. Do not restore unrelated guardian chases.

Reproduce obstacle collisions with the biggest relevant mount and camera before moving props. Carried eggs are already noncolliding. Keep biome borders and intentional escape hazards; do not scatter or regenerate the whole map speculatively.

## Verification

Run real Luau code offline for chosen-species persistence, old/special eggs and server hit validation; compile every current source. In Studio, verify source parity before applying, create a backup of each touched source, use isolated test data, then check real selection/refill/drop/hatch and Mama input, fresh/returning tutorial states, phone landscape/tablet/desktop layouts, speed allowances and obstacle escapes. Report offline, Studio and actual-device evidence separately. Do not publish a partially verified update.
