# Handoff: Steal a Ride (Roblox) → Codex

## Read first
1. `steal-a-ride.md`: the game spec. **Parts 1–6 are already built. Do not rebuild anything.**
2. `steal-a-ride-build-log.md`: what was actually built, every ruling, and test results. Read the last two sections closely.

## Where the code is
- All code and assets live **inside Roblox Studio**, not on disk. There's no Rojo or git. Use the `Roblox_Studio` MCP server (already in your config.toml) to read and edit it: `script_read`, `script_grep`, `search_game_tree`, `multi_edit`, `execute_luau`.
- Studio must be open with the Steal a Ride place loaded. If several Studio windows are open, run `list_roblox_studios` and pick Steal a Ride. **Do not touch Power Core Incremental.**
- The layout follows spec §18: services in `ServerScriptService.Services`, shared modules in `ReplicatedStorage.Shared` (Config, Format, CreatureBuilder, WalkCycle), and the client in `StarterPlayerScripts.ClientMain` and `StarterGui.MainUI.UIController`.
- Edit-time tools are in `ServerStorage.BuildTools` (ScatterProps, FileCreatureMesh).

## Current state
- Walk cycles: every creature, guardian and mount moves its whole body as it walks. Legs don't move on their own.
- Trial: **only the Forest Rooster guardian** has real legs (segmented mesh + two Motor6D hips, driven by GuardianService). The old static Rooster is in `ServerStorage.Guardian_Forest_Static` for rollback.
- Open question: should leg rigging go to the other 6 guardians? Long-legged quadrupeds (Tiger, Hellhound) would need 4 legs and better hip placement.

## Rules
- Make small, targeted changes. Don't rewrite services that work.
- Never delete anything you didn't create; move it to ServerStorage instead.
- Guardian chase and catch math uses the real position `g.cf` and the `BodyRadius` attribute. Animation must never change either one.
- After each change, playtest with `start_stop_play`, read the Output with `get_console_output`, and fix every error before you stop.
- Run `generate_mesh`, `generate_material` and `segment_mesh` in **Edit mode** only, at most 3 at a time. They fail during Play or under load ("Too Many Requests").
- Guardian mesh prompts can't use the words "monster", "giant" or "angry"; they fail moderation.
- Add a section to `steal-a-ride-build-log.md` for your work, in the same style: Built / Tests / Rulings.

## User to-dos (not your job)
- File > Save to Roblox. Studio changes aren't published yet.
- Publish the game and enable Studio API access so DataStore saving can be tested.
- 2D art (icons and thumbnails) was skipped because there's no image-generation connector.

## Your task
<!-- Replace with the actual request, e.g. "Roll the leg rig out to the Lake Swan and Tundra Yeti guardians" -->
