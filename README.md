# Power Core Incremental

The complete game is installed in Roblox Studio's **Place1** through the official Roblox MCP. Press Play to run it and save the place in Studio to keep the build.

## Included

Eight generators with Buy 1/10/100/Max, seven upgrades, server production and tap limits, permanent Power Cores, a two-activation Reboot confirmation, stats, offline rewards, DataStore persistence, a primitive-built facility, five local reactor stages, terminals, responsive UI and purchase/evolution feedback.

All costs and production values follow `C:/Users/Desktop/Downloads/power-core-incremental.md`. Placeholder sounds intentionally have empty SoundId values; supply audio assets later.

## Saving

The connected place has no usable DataStore access during testing. Publish the place and enable Studio access to API services to test real saves. Failed loads set a warning and block saves for that session, preserving existing progress. Playtests still run the complete economy, but those failed-load sessions do not persist.

DataStore: `PowerCore_v1`; key: `u_` followed by UserId. Autosave runs every 60 seconds and saving also runs on Reboot, player exit and server shutdown. Offline rewards cap at eight hours and pay half of production.

## Source and installation

`src/Modules` contains shared balance, formulas, formatting and stages. `src/Services` contains server economy/data services. `src/UIController.client.luau` builds the UI, and `src/ReactorVisuals.client.luau` renders each player's own reactor. `src/WorldBuild.luau` builds the common facility.

Run `python tools/build_install.py` to regenerate `build/InstallScripts.luau`. In Studio Edit mode, execute `src/WorldBuild.luau`, then `build/InstallScripts.luau` through Roblox MCP. The installer assigns each script's Source and marks created scripts as owned. It refuses to overwrite unrelated scripts. Stop play mode before reinstalling.

`tests/EconomyChecks.luau` is a runnable Luau test module. The development installer temporarily creates `ServerScriptService.PowerCoreChecks`; require it in a temporary server test Script, then remove both test Instances after testing. Test source remains here locally.
