# Steal a Mount account migration

The complete Studio place is saved as `Steal-a-Mount-original.rbxl`. Keep this original backup unchanged.

Saved from the original experience owned by **krgwsg** (user `11767417694`): place `91426156190208`, universe `10769593546`.

- `purchases.json`: the five passes and three developer products, descriptions, prices, original IDs, and fields for new IDs.
- `assets/purchases/`: all eight purchase icons.
- `assets/page/`: game icon and three thumbnails.
- `assets/ui/`: original UI icons and their uploaded asset ID mapping.
- `original-config.luau`: Config source read directly from Studio at backup time.
- `asset-references.json`: unique asset references and usage counts from the original place. These remain references; permission or availability must be checked in the new experience.

## Resume

1. The user signs into the old Roblox account in Chrome and Studio and supplies its username. Verify the account before publishing.
2. Open the saved `.rbxl` in Studio and publish it as a **new experience**, named Steal a Mount, under that account. Record its creator, universe, and place IDs in `purchases.json` and the root `HANDOFF.md`.
3. Recreate the five passes and three products in the new experience using the preserved icons, descriptions, and prices. Verify each ID belongs to the destination experience. Record each result immediately so an interrupted session does not create duplicates.
4. Update `Config.Monetization` in the destination Studio place and `steal-a-ride/src/ReplicatedStorage/Shared/Config.luau` with the verified new IDs. Preserve the original cloud experience and this backup.
5. Upload the game icon and thumbnails. Test gameplay boot, all eight shop entries, and image/model/audio access under the destination account. Check Roblox's current publishing requirements if public access is blocked.
6. Save a separate migrated `.rbxl`, publish the destination game, and record verification and its link in the shared handoff.

A fresh experience has a new universe: the original experience's player saves and purchased pass ownership do not move through the place file.

## Current status (2026-10-07)

Destination owner **eisoisoo** (`7908166657`), universe **10769659624**, start place **123937616497204**. Created from the full original backup; do not create a second destination.

All five passes and three products were recreated with their icons and verified prices, managed pricing off. `purchases.json` is the authoritative new-ID manifest. New IDs were applied only to destination Studio and the local working Config; guarded assertions passed. The destination version was published privately.

`Steal-a-Mount-migrated.rbxl` contains the migrated game: 1,234,091 bytes, SHA256 `50CA849E81A2FDBD8CB1CB51258F288FF4304B1FE34CBEC417B38F2122A7A951`. Original backup remains unchanged. Main icon, all three active Home thumbnails, and all three detail-page thumbnails are saved. Proof: `artwork-saved.png`.

Remaining release work:

1. Restore access to 104 existing mesh/image asset references listed in `blocked-assets.json`. Studio Output confirms permission failures and creature-rig CSG failures. The destination game's Permissions > Assets rejected two representative IDs with "You cannot give permission to this asset type"; no grants were saved. User was asked whether krgwsg sign-in is available. No `.fbx`, `.obj`, `.glb`, `.gltf`, `.rbxm` or `.blend` source files were found in `C:/Users/Desktop/Documents/Roblox Games`. Original owner access or source uploads are needed; do not replace the user's art with placeholders.
2. Enable Studio API access manually or with explicit action-time authorization, then repeat persistence/play tests. Current Studio test reaches the game UI but data loading is rejected by the disabled API setting.
3. Paid Lucky pass/Luck Potion/Server Luck currently lack policy restrictions and numerical odds disclosures. A bounded fix was proposed to the user: existing-style Hatch odds panel with item probabilities/current and paid-boost chances; PolicyService restrictions for paid luck; preserve free hatching/balance. Approval is pending; no compliance changes implemented yet. Live purchase handler snapshot is `original-monetization-service.luau` (actual service is **MonetizationService**, not PurchaseService).
4. Finish maturity questionnaire. Current draft: repeated mild violence and fear; no blood, crude humor, gambling depictions, strong language, romance, alcohol, social-hangout focus, free-form creation, sensitive primary issue, cross-experience media, or runtime generative AI. Paid random items = Yes. Pending question asks whether ArePaidRandomItemsRestricted is respected; do not falsely answer Yes before implementing it. Trading/media/feed sections and final submission remain.
5. Complete public release and verify the live listing/play link. Account currently supports ages 16+ and trusted friends, verified in Audience Reach. No publishing fees were paid.

Root `HANDOFF.md` contains live browser/Studio handles and the latest resume instructions.
