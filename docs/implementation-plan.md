# Power Core Incremental implementation

Spec: C:/Users/Desktop/Downloads/power-core-incremental.md
Goal: implement the complete playable game in the connected Place1 through Studio MCP.

Use the supplied module/service layout, exact economy numbers, player attributes, three validated purchase remotes and a server ClickDetector. Build only Roblox primitives. Preserve the existing baseplate/spawn; mark all created objects. UI uses dark navy, cyan, restrained amber for reboot, legible Gotham text, scrollable panels and structural phone layout.

1. Create behavioral tests for bulk buying, upgrades, tapping, reboot, save failure protection and offline rewards. Verify missing implementation fails.
2. Implement shared config/formulas/formatter and server services. Install via execute_luau assigning Instance.Source. Playtest service assertions.
3. Implement the complete responsive UI, attribute-driven state, confirmation and feedback. Test real UI remote path.
4. Build the facility, local reactor stages, terminals, energy screen and stage effects. Inspect desktop and phone layout, test stage transitions.
5. Verify all behavioral assertions, inspect Output, remove temporary test scripts, stop playtest and retain local source/install script.

Review focus: failed DataStore loads must block all saves; nonfinite or malformed remote arguments must not buy anything; Max rounding must never overspend; runtime visuals must leave the hitbox untouched; offline rewards count toward RunEnergy exactly once per loaded snapshot.

No publishing is requested. Actual DataStore round-trip requires a published place with Studio API access; exercise failure handling and save serialization without overwriting live accounts during tests.
