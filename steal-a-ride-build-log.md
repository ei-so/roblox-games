# Steal a Ride: build log
plan: steal-a-ride.md · Studio window id: 619034c6-d2cc-4b21-b38e-48bcf5c1bfcc (blank "Place1")

## 2026-10-08: HUD/Menu/mobile cleanup and overhead shield — installed, unpublished

Removed nest egg-count billboards, Shop/Fuse Menu entries and empty-gear shop shortcut. Friend bonus now briefly uses the existing toast; flight instructions expire after4s and repeated tutorial copy after6s (beam/progress unchanged). Base-only status sits on the right; replicated Shielded tag sits above the Head and stacks with the existing OG tag, updating on shield expiry/respawn. Mama has a separate gold YourHits counter, with portrait/desktop layout accounting for simultaneous weather and damage leaderboard.

Menu keeps movement/jump and navigation active; selecting a tab replaces the previous one. Unclaimed Daily reward reopens after switching tabs and clears after claim. Gear cash purchases require a live character within30 studs of the Gear stall on the server; existing Fuse server gate remains. Index and other non-stall navigation remain available.

Final33 actual-source groups PASS +48 sources compile. Native phone7 clicks verify Stable→Index/Quests, both stall prompts and soda buying, active touch controls, empty Net, friend/flight expiry. Far gear buys fail without charging. Real MamaHit requests update count6;50/75/100 layout previews fit phone17 landscape/portrait and desktop. Shield expiry/restoration and respawn with OG replicate. Desktop Daily→Stable→Daily→claim passes. Isolated concurrent Mama+BloodMoon portrait has separated bar/weather/base and TextFits true. Review findings (obsolete Fuse button reference, lost unclaimed Daily, simultaneous-event overlap) fixed; final review clean.

All10 changed sources equal Studio in full; NestStatus deleted. Preserved concurrently completed Stable typography. Config v2/v1 fully restored, temporary backup absent, Studio Edit/HD1080/LandscapeLeft/DPI96/FitToWindow. Evidence: steal-a-ride/hud-menu-verification-20261008.json and6 PNGs under hud-menu-20261008. Originals: before-hud-menu-20261008/ and ServerStorage.HUDMenuBackup20261008. Physical phone/multiplayer untested; notched-emulator tool clicks unreliable, its panels verified through existing handlers/render. No publish/commit/push.

## 2026-10-08: Blood Moon surface visibility — installed, unpublished

User's Home screenshot still looked too dark; authorized more ambient fill while retaining dark sky/red moon. ClientMain captures original Ambient/OutdoorAmbient and adds BloodMoon RGB150,130,140 /RGB160,140,150 to its existing cancellable2s Lighting tween. All other/clear/unknown weather restores original values. No competing ambient writer; no additional effects/modules/audio/gameplay/UI changes. Initial110,95,105 /135,115,125 fill was too subtle; native Home/Forest/Tundra/Cosmic and red-moon previews checked stronger final values.

Actual-source lift/join/nonuniform-baseline restoration assertions RED→GREEN;27 groups PASS +48 sources compile. Isolated SAMBloodVisibility /Final stores: final native values observed, exact ambient restoration for Golden/Storm/unknown/clear and3 rapid0.2s cycles, dark sky/red moon preserved. Final console only known CAS warnings/onboarding analytics. Studio Edit, exact production Config restored, temporary Play backup absent, installed ClientMain fully equals local; baseline ambient70/70 and clock14.5 restored. Originals: before-blood-moon-visibility-20261008/ClientMain.luau and ServerStorage.BloodMoonVisibilityBackup20261008. Evidence: blood-moon-visibility-verification-20261008.json;6 PNG previews under blood-moon-visibility-20261008. No publish/commit/push.

## 2026-10-08: Golden Hour and Blood Moon SFX/VFX — installed, unpublished

User approved the implementation plan. Only ClientMain/Effects weather sections changed: sunset17.5/gentle rays/gold motes versus night21/red native moon16/crimson motes. Desktop live budget36/24, touch-only18/12; holder follows current camera at10Hz and tolerates nil/replacement/flight/respawn. Retained/cancelled tint/clock/moon tweens restore baseline14.5/11 and remove owned effects on transitions. Storm/gameplay/F Get off/R flight unchanged.

Final audio reuses existing assets through independent client aliases: Forest9112835068 at0.06, Blood Blizzard4175285709 at0.09; Cosmic magic shimmer9116418035 cues pitch1.25/0.6, volume0.18/0.12, bounded3s and Mama ducking. Roblox metadata rejected proposed rocket-engine ambience; user deferred listening. Native night plus old brightness-0.12 obscured Forest/Cosmic routes: final brightness+0.03 retains red night and recovers visibility without new lighting ownership.

Actual-source visual/audio tests each RED→GREEN; final27 groups PASS +48 Luau sources compile. Isolated SAMGoldenBlood_1791433483 / SAMGoldenBloodOld_1791433483 Play: native texture/all audio fetch Success, final loops/cues actually playing, native sun/red moon and Forest/Tundra/Cosmic route previews,3 rapid0.2s cycles keep one holder/loop per name and restore baseline, actual R flight + nil/replaced cameras for all3 weather,3 respawns, real egg escape soundtrack dominates weather and shares Mama duck0.2, final17.2s clear wait has no late thunder. iPhone17Pro emulation keeps keyboard=true: hybrid path checked; touch-only rate6/4,width24 explicitly previewed and real touch-only branch covered by harness. Physical FPS and published asset permissions unmeasured; already-playing storm clap may finish naturally. Fresh read-only review found no actionable issues.

Final Studio Edit; both sources match local in full (CR normalized), exact production Config restored, temporary backup/Play objects absent, original HD1080/LandscapeLeft/DPI96/FitToWindow restored. Backups: steal-a-ride/before-golden-blood-vfx-20261008 and ServerStorage.GoldenBloodVFXBackup20261008. Evidence: steal-a-ride/golden-blood-vfx-verification-20261008.json;6 PNG previews in steal-a-ride/golden-blood-vfx-20261008. No publish/commit/push; publication stays with user.

## 2026-10-08: Thunderstorm rain, clouds and lightning — installed, unpublished

Updated ClientMain and Effects weather sections: visible built-in rain streaks, dark native Terrain clouds, stronger storm tint, moderate intermittent lightning followed by varied thunder. Touch-only rain uses a smaller area and lower rate. Weather changes remove rain/clouds, reset lightning and cancel delayed thunder. Existing F get-off/R flight bindings, biome looks, Golden Hour and Blood Moon retained.

Added actual-source storm_harness: final 27 groups pass and48 game sources compile. Isolated SAMStormVFX_1791408602 Play verified loaded rain texture, rain/thunder actually playing, observed lightning, previews of rain/clouds, rapid-transition cleanup, and unchanged other weather tints. Preview caught sideways streaks and sparse lower-budget rain; final rotation90/larger brighter streaks correct both. Read-only reviewer found no actionable issues. Physical-device frame rate not measured.

Final sources match Studio; Play stopped, v2/v1 restored, temporary test objects absent. Originals: steal-a-ride/before-thunderstorm-vfx-20261008 and ServerStorage.ThunderstormVFXBackup20261008. No publish/commit/push. User reports nobody online, so publication needs no server restart.

## Part 1: Foundation
Pre-flight: Part 1's tasks share Config (consumed by CreatureBuilder, DataService, PlotService, the map and the HUD) and the plot layout (consumed by PlotService). Both are built first.

- Ruling: built in Studio window 619034c6, the first of two identical blank "Place1" windows. The third window holds Power Core Incremental and isn't touched. Cost if wrong: the work sits in the other blank window; Save As fixes it.
- Ruling: the template Baseplate and SpawnLocation are moved to ServerStorage.TemplateBackup instead of deleted. They clash with the map at the origin, and the spec says not to delete what we didn't create. Cost if wrong: none; they can be moved back.
- Ruling: the place is unpublished (GameId 0), so DataStore saving can't be verified until the user publishes it and enables Studio API access. The load-fail guard is verified instead. Cost if wrong: saving stays untested until the user publishes.
- Ruling: no subagent final review (session rule: no subagents unless the user asks). Final review is a self-review.

Task 1 (folders, remotes, Config, Format): complete. Tests: the Format test failed with "Shared is not a valid member", then passed all 15 cases. The Config test passed (21 species, odds add up to 100, depth = 10 × guardian speed, rebirth and pen-slot costs).
- Ruling: Config holds every spec number for all 6 parts now, not just Part 1's. It's a single data file, and filling it later would mean re-reading the spec. Cost if wrong: unused values until later parts.
- Ruling: added the Frog's "Squat" body shape, and the bellyColor, footColor and "tail:feather" recipe fields, to keep the Penguin, Parrot and Frog recognizable. Cost if wrong: none (cosmetic).

Task 2 (CreatureBuilder): complete. Tests: the build test failed with "CreatureBuilder is not a valid member", then passed all 504 builds (21 species × 6 rarities × 4 mutation states: every part welded and non-colliding, attributes set, Legendary bigger than Common). Screenshots checked: all 21 species are distinct. Fixed the Monkey's tail (it read as an antenna) and re-ran: 504/504. Test models removed.
- Ruling: ellipsoids are Block parts with a sphere SpecialMesh, because Ball parts must be uniform in size. Cost if wrong: none.

Task 3 (DataService): complete. Tests: failed with "DataService is not a valid member", then passed using fake stores: a failed load gets defaults and save() never writes; a healthy load fills in missing fields (Gear.trap, SaddleLevel) and save writes the live table with LastOnline set; get and release work.
- Ruling: added DataService._setStore(fake) as a test-only seam, because the real DataStore can't run in an unpublished place. Cost if wrong: one unused function in production.

Task 4 (map skeleton): complete. Built Home Row (8 plots with signs and spawn pads), Plaza (spawn, title arch, Fuse, Gear and Index placeholders), Biome Road (ground, road, invisible boundary) and all 7 biome zones (floor, exit line, arch with "Escape speed N+"). Forest and Lake are full: nest, egg spots, guardian spot, props, and the Lake's water Swim lane. Checked with screenshots.
- Ruling: built the map before PlotService (the spec lists it after), because plots must exist to be assigned. Cost if wrong: none.
- Ruling: nests sit at x=+50 and each escape lane runs in the carrier's direct path home, so players without the ability have to route around it. Biomes store EntranceZ, FarZ, NestZ and LaneStartZ attributes for later parts. Cost if wrong: Part 3 moves the lanes.
- Ruling: SurfaceGuis use PixelsPerStud 16, because TextScaled caps at 100px. Changing that value at runtime left stale layouts, so the guis were replaced with clones. Cost if wrong: none; checked with screenshots.

Task 5 (PlotService and Main): complete. RED wasn't run separately (nothing sets the Plot attribute before this code). Playtest checks passed: player joined; got Plot1; owner attribute set; sign reads "<name>'s Base"; spawned 3 studs from the plot pad; Speed 16; Cash and CashPerSecond 0; exactly one plot owned; release resets the sign and owner; reassign works.

Task 6 (HUD and client lighting): complete. The playtest screenshot shows "$0", "+$0/s", "⚡ 16" and the red data warning (correct: load failed because the place is unpublished). Client test passed: Lake atmosphere on entering, last look kept in the gap between biomes, Home look on return.

Playtest Output: only the 3 expected "You must publish this place to the web to access DataStore" warnings (the load-fail guard working). No script errors.

Part 1 checklist:
- [x] A joining player gets a plot
- [x] Data saves and loads: published as "Steal a Ride" (PlaceId 91426156190208, private) with Studio API access on. Real cycle passed: playtest 1 loaded with DataLoadFailed=false and saved on leave (LastOnline set); a seeded Cash=123 loaded back in playtest 2. Test save removed afterwards.
- Ruling: at publish, turned Team Create off (it changes how scripts save, which could get in the way of MCP edits) and Data Sharing off (opted out of Roblox using the game's data for AI training). Both can be changed in Experience Settings. Cost if wrong: one toggle each.
- [x] All 21 species build without errors (504/504)
- [x] Playtest Output clean (only the expected DataStore warnings)

Final review: self-review (no subagent tool by session rule). No Critical or Important findings.
- Final: minor (deferred): PlayerRemoving and BindToClose can both save the same player at shutdown. Harmless (2 writes).
- Final: minor (deferred): the one-time map build script isn't stored in the place. Part 3 adds new build code for biomes 3–7 anyway.
- Final: minor (deferred): phone-size HUD not checked in the device simulator yet. Part 5's testing pass covers it.

## Part 2: The heist loop
Built:
- Plots: 6 incubator pads and 20 pen pedestals on every plot; the spawn moved just inside the entrance.
- Server services:
  - EggService: nests, grab prompt, egg welded above the head, drop-off on your own plot, refills (Forest +1 every 20 s; other nests every 3 min with a toast).
  - GuardianService: anchored PivotTo movement; sleep, wake after 1.5 s, chase, catch, fling, stun, give up at the exit line, return home.
  - HatchService: os.time() timers, species and rarity rolls, egg queue for full incubators.
  - CreatureService: pen, stable, income tick, pen models with $/s labels, Pen/Unpen/Sell remotes, GetInventory.
  - SpeedService: WalkSpeed and stuns.
- Client:
  - Toasts, including "You hatched a Rare Fox!".
  - Guardian fling, applied on the client because the client owns its character's physics.
  - Stable panel (ViewportFrame cards with Pen/Unpen/Sell; Epic and above ask twice before selling).
  - Tutorial beam and hint.
- Shared: Config.income and Config.mountSpeed; designs for all 7 guardians; CreatureBuilder.buildGuardian and buildEgg.

Tests (playtest, end to end with real input):
- Builder regression 504/504, plus guardians, eggs and formulas: PASS.
- Grab a Forest egg with E: egg on head. Drop-off at home: incubator timer 0:09. The Uncommon Chick hatched into the pen at $10/s, and cash rose 30 in 3 s: PASS.
- Swan chase at the Lake (real character movement): speed 16 CAUGHT after 7.5 s; speed 18 ESCAPED after 10.2 s: PASS (spec: the Swan catches walkers, not Forest Common riders).
- Lake egg dropped off with a 0:19 timer, then hatched a Frog: creatures 2, CashPerSecond 40, BestBiome 2: PASS.
- Stable UI clicks: Unpen lowered CashPerSecond 40 to 30 and showed "Pen 1/6 · Stable 1/50"; Sell removed the creature and added $600: PASS.
- Output: no errors.
- Ruling: added a Notify RemoteEvent (toasts, hatch messages, fling). The spec calls for alerts but lists no remote for them. Cost if wrong: none.
- Ruling: a guardian catches within catchRadius (5) of its body length, not its wingspan (the Swan's wings would make it catch from too far away). Cost if wrong: catches slightly easier or harder; the 16/18 chase test still passes.
- Ruling: removed the "Locked" labels on unused pen pedestals because they were visual clutter; locked pedestals are faded instead.
- Note for testing: Roblox shows one ProximityPrompt per key (the nearest), and scripted InputHoldBegin is unreliable, so grabs are tested with real E keypresses.
- Test data is still in the user's save. It gets reset at the end of the build.

## Part 3: The riding twist
Built:
- Biomes 3–7 in full: nest, guardian, props, and an escape lane (x 34..74, from 30% of the way out from the nest to the exit line):
  - Desert: 10-stud mesa (Jump)
  - Jungle: river (Swim)
  - Tundra: ice ramp, then a 30-stud chasm with a Pit zone, then a raised shelf (Glide)
  - Volcano: lava river (Fireproof)
  - Cosmic: energy-walled corridor (Phase)
- Lake lane tagged Water.
- MountService: equip, unequip and swap; the fastest mount is welded under the root with HipHeight raised; Abilities and Riding attributes; Jump doubles JumpHeight; 2nd slot at Rebirth 3 or with the pass.
- AbilityService: Dash on the server (2× for 1.5 s, 8 s cooldown); zone loop (water slows non-swimmers to 6; lava and pit drop the egg and send the player back to the exit arch); the canEscape lane check used by guardians.
- SpeedService: mount speed, saddle, Dash, multipliers, water, stun.
- ShopService: Saddle, Incubator and Pen Slot purchases.
- Client: Ride/Get off on Stable cards; Shop panel; Dash on Q, gamepad X and a mobile touch button (ContextActionService); Glide VectorForce while falling; Phase walls non-collidable locally; a "ride it" tutorial step.
- Studio-only TestHooks BindableFunction in ServerStorage (give, mount, grab, cash, wipe, canEscape, guardian, json). It's only created when RunService:IsStudio() is true.

Tests (real character movement in playtests):
- Each biome's Common mount escapes the next biome on the main road: Desert @23 ESCAPED 10.7 s, Jungle @29 ESCAPED 10.9 s, Tundra @35 ESCAPED 11.0 s, Volcano @42 ESCAPED 11.1 s, Cosmic @51 ESCAPED 11.2 s: PASS. Negative check: Desert @18 CAUGHT: PASS.
- Lanes count as an escape only with the right ability: Lake, Desert, Jungle, Tundra and Cosmic with the ability true and without it false; Volcano with a Salamander true: PASS.
- Water: Chick rider 6, Duckling rider 23. Lava penalty (egg lost, back at the exit arch). Chasm penalty, same. Jump 14.4 vs base 7.2: PASS.
- Client: Phase walls passable with a Star Jelly and solid without one. Glide fall -46 vs about -110 without. Dash with a real Q press: 36, then 18. Shop UI clicks: Saddle (19 speed) and Incubator 3/6, cash correct: PASS.
- Output: no errors.
- Ruling: turned Workspace.StreamingEnabled off. Streaming kept far-away Phase walls and nests off the client, which breaks Phase and the tutorial arrow. The map is about 1.2k parts, which is fine without streaming. Cost if wrong: higher memory if the map grows a lot; Part 6 meshes should be re-checked.
- Ruling: the Tundra chasm's Glide jump is tuned for a 30-stud gap with an 8-stud-high ramp. Very fast non-gliders (46+ speed) can clear it without Glide; they'd outrun the Yeti anyway. Cost if wrong: the Tundra lane matters less for late-game riders.
- Ruling: skipped the client mount-bob tween. The mount is welded rigidly, and animating a WeldConstraint isn't possible; it's cosmetic. Cost if wrong: mounts look a bit stiff. Part 6 polish can add it.
- Not testable here: mobile touch buttons (ContextActionService creates them automatically on touch devices).

## Part 4: PvP and events
Built:
- StealService:
  - Steal Egg prompt on every carrier's HumanoidRootPart (0.7 s hold).
  - Raid prompt on every incubating egg (2 s hold; blocked while the base is locked). A raided egg loses its progress and goes back to its owner if the thief drops it.
  - Take Back prompt on the thief for 10 s, visible only to the victim.
  - Lock button (60 s + 10 s per rebirth; 30 s join lock). Locked bases push non-owners out, and the barrier shows while locked.
  - New-player shield for the first 15 minutes of playtime (can't steal or be stolen from; base always locked).
  - Rob cooldown 60 s per victim; no stealing within 3 s of being caught.
- GearService: Net Gun (target within 40 studs, 50% slow for 3 s, 20 s cooldown); Slip Trap (max 2, 60 s, slows the first player or guardian on it); Speed Soda (+25% for 20 s). Price = 30 s of income (min $50).
- EventService:
  - Weather every 10 min for 2 min. Grabbed eggs roll the matching mutation; Blood Moon makes guardians 1.15× faster.
  - Secret Egg every 5 min from the Desert onward, with a map-wide beacon. It wakes the biome's guardian and returns to its spot if dropped.
- RebirthService: requirements, resets and rewards per the spec; saves immediately after a rebirth.
- Fuse Machine: Plaza prompt opens the Stable; a "Fuse 3" button appears on cards when you have 3 of a kind. The result keeps the best mutation.
- Anti speed-hack: carriers sampled every 0.5 s; faster than the allowed speed × 1.4 + 5 drops the egg.
- Client: gear hotbar (keys 1-2-3, Shop rows), Rebirth panel, raid alarm (red flash + toast + blank Sound), status line (shield or lock timer), event banner, weather tint + rain, own prompts hidden.

Tests (single player, in a playtest):
- Shield on at 0 playtime and off at 1 h: PASS. Join lock 27 s left and barrier shown: PASS.
- Raid prompt on the incubator egg, owner-tagged and hidden on the owner's client: PASS.
- Steal prompt on carriers, removed after drop-off: PASS (first attempt failed because of my test: the egg was grabbed while standing on my own plot, so it went straight into an incubator).
- Gear buys: PASS. Soda 16→20 via a real key 3 press: PASS. Trap (key 2) sprung by the Chicken: PASS.
- Mutation odds: Golden Hour 14.6% Golden (spec 15%); Blood Moon 10.8% Cursed (spec 10%): PASS.
- Secret Egg: spawns with beacon; real E grab carries a secret egg and wakes the Volcano guardian; dropped in lava, it returns to its spot: PASS.
- Fuse: 3 Common Foxes (one Golden, one Shocked) became 1 Uncommon Golden Fox: PASS.
- Rebirth: blocked without a Jungle creature; once allowed, Rebirths 0→1, cash 0, only the ridden Rare Fox kept, incubators 3→4: PASS.
- Anti speed-hack: client WalkSpeed 150 while carrying dropped the egg in 0.9 s: PASS.
- Output: no errors.
- Fixed: the Rebirth panel was blank because the RebirthUI text() helper ignored its props. Re-checked in Part 5.
- Ruling: fusing stops at Legendary. Mythic stays exclusive to Secret Eggs, as the rarity table says. Cost if wrong: one condition.
- Ruling: lock barriers don't block physically. A server loop pushes non-owners out of locked bases instead, so owners can always walk in. Cost if wrong: none.
- Needs a real 2-player test (Studio → Test → Clients and Servers → 2 players), listed below.

## Part 5: Retention and polish
Built (continued from the earlier session):
- Main wires RetentionService and MonetizationService. The pre-save LastOnline is read on join, and passes are applied before the offline summary so VIP counts.
- MamaService (section 12):
  - Every 20 min, and never during weather. 30 s warning: sky darkens, siren, banner.
  - Mama = the Cosmic guardian recipe at scale 8. She walks road end to Plaza and back in 2 min, with a stomp camera shake.
  - Every 6 s she snatches one incubator egg from the nearest unshielded plot (claw beam; the egg lands on her back).
  - 3 neon weak-spot orbs with ClickDetectors (range 80; 8 clicks/s cap per player); HP = max(300, 150 × players); flinch on hit.
  - Defeated: eggs go home with their progress, plus Lucky Eggs (10+ damage gets 1, top 3 get 2), and a burst. Escaped: eggs are lost.
- RetentionUI (client):
  - Index panel: species × rarity grid, black silhouettes until discovered.
  - Store panel: passes and products; placeholder IDs say "Coming soon"; shows the luck timer.
  - Daily reward popup (7 tiles) and offline summary popup.
  - Mama HP bar with countdown, eggs-snatched count and top 3 damage.
  - VIP chat tag (TextChatService).
- Effects (client): hatch burst at the incubator in the rarity color, catch burst plus camera shake, stomp shake, Mama defeat burst, MamaTint, and the SFX helper.
- SoundService.SFX: 24 named Sounds with blank SoundIds, plus a looping ambience per biome. Part 6 fills them.
- Epic+ pen creatures get a rarity-colored light beam.
- TestHooks: mama, mamaDamage, fillIncubators, setIncubators, hatchRolls, offline, setDaily, receipt.

Tests (playtest):
- Hatch odds over 10,000 Forest rolls: Common 54.4 / Uncommon 28.7 / Rare 12.0 / Epic 4.0 / Legendary 0.94%; species 51/34/15%. With luck, Legendary doubles to 2.1%: PASS.
- Daily: a real Claim click paid day 1. Yesterday at day 6 gives day 7 (Luck Potion, stacked on existing luck); a missed day resets to 1; day 7 wraps to 1: PASS.
- Offline: 2 h away at $30/s paid +$108,000 (50%); 27 h away capped at 8 h; the popup shows: PASS.
- ProcessReceipt: the same PurchaseId twice grants once (luck unchanged on retry): PASS.
- Mama escaped (Lake eggs, 40 s test run): snatched eggs lost, model removed, attributes cleared: PASS.
- Mama defeated with incubators full: 5 snatched eggs went to PendingEggs with progress kept, plus 2 Lucky Eggs from the deepest owned biome (Lake). After Instant Hatch, 4 pending eggs moved into incubators: PASS.
- Mama skips shielded players (0 snatched while shielded): PASS.
- Rebirth panel re-checked: renders with requirements and rewards: PASS.
- Phone (iPhone 17 Pro, device simulator): the Mama bar overlapped the toast and the Store button sat on the thumbstick. Fixed (toast moved down, left menu buttons 46 px, top-anchored), then re-checked: PASS.
- Output: no errors.
- Ruling: Mama's scale is 8 (2× the Cosmic guardian). The spec's "4× scale" equals the Cosmic guardian's own scale, which would make her no bigger than an ordinary guardian. Cost if wrong: one Config number (Events.mamaScale).
- Ruling: the offline summary is a Player attribute, not a remote. It's sent during join, before client scripts listen, and only the first listener receives queued remote events. Cost if wrong: none.
- Ruling: rewarded video ads skipped (spec section 20). They need Roblox's ad setup on the published experience; there's nothing to test in Studio. Cost if wrong: one Store row later.
- Not verified with real input: clicking Mama's weak-spot orbs. Simulated 3D clicks don't reach ClickDetectors. The hit path was tested through the same damage code via a hook. Click an orb yourself in a playtest.
- Still needs a 2-player local server (from Part 4): steal from a carrier, raid an unlocked base, Take Back within 10 s, locked-base push-out, Net Gun on another player, shielded players can't be robbed, 60 s rob cooldown, and Mama's HP scaling with 2 players.
- Test data is still in the user's save. It gets reset at the end of Part 6.

## Part 6: Polish pass
- User request: riders sit on their mount instead of running on top of it.
  - Client (ClientMain): while the Riding attribute is set, loops the avatar's own sit animation at Action4 priority, which overrides run/jump/fall. Falls back to the default R15/R6 sit IDs.
  - Server (MountService): the rider's thighs rest on the top of the mount's Body part (or a SeatHeight attribute, for Part 6 meshes). The mount is still placed on the ground.
  - Tested: the sit track plays on spawn and stops when you get off; HipHeight 4.45 riding a Hellpup vs 2.10 on foot. Side screenshot shows the rider seated on its back. Gameplay speeds and the mount's ground clearance are unchanged.
  - Fixed a race: the initial character's Animator didn't exist yet, so the pose never started on the first spawn.
  - Ruling: the seat drop (1.6 studs for R15) was measured on a default-scale avatar. Cost if wrong: unusually scaled avatars sit slightly high or low.

## Part 6: Polish pass (continued)
Built:
- Ground: generated MaterialVariants on all 7 biome floors: ForestMossyGrass, LakeShoreSand, DesertCrackedSandstone, JungleMud, TundraPackedSnow, VolcanoGlowingBasalt, CosmicStarfield. The Desert mesa also uses the sandstone.
  - Floors widened to the full 220-stud map and stretched over the 20-stud gaps, so no default green shows around the biomes.
  - The shared ground uses the Forest grass.
- Props: 35 generated mesh props (5 per biome) in ServerStorage.PropMeshes.
  - Scattered by ServerStorage.BuildTools.ScatterProps, an edit-time tool you can re-run per biome.
  - Big props: east/west edges only, and they collide.
  - Small props: walk-through, on the west field.
  - Kept clear: the road, the run strip (x 20..34), lanes, nests and exit lines.
  - Novelty props are weighted rare.
  - The primitive props are in ServerStorage.PrimitiveProps as the fallback.
- Creatures: generated meshes for all 21 species, the 7 guardians and Mama (the Cosmic guardian mesh at 2×), in ReplicatedStorage.CreatureMeshes.
  - Filed by BuildTools.FileCreatureMesh.
  - CreatureBuilder uses the mesh when it exists and the primitive recipe otherwise. Rarity scale applies.
  - Golden/Cursed get a tinted Highlight plus the particles (textures ignore part Color).
  - Glow species get their PointLight.
- Mounts: a SeatHeight (SeatFrac × height) and SeatForward (rider behind the head) per mesh.
  - Rarity-colored Trail on mounts, plus a foot-dust emitter the client switches on while moving.
- Guardians: scaled to 1.1× the primitive height, and they carry BodyRadius = the primitive's half-length. GuardianService uses it, so catch distances are unchanged from the Part 2/3 tests.
- Mama: weak spots fall back to bounding-box spots (head, chest, tail) when the mesh has no named parts.
- Sound: all 24 SFX filled with free Creator Store audio, mostly Pro Sound Effects and APM. IDs are recorded in Config.Sounds; one roar, pitched per guardian (Config.RoarPitch).
- Game feel (Effects):
  - Egg-grab pop.
  - Roar + chase sting when the guardian wakes.
  - Heartbeat volume and a red screen-edge vignette scaled by guardian distance while carrying.
  - Purchase / lock / unlock sounds.
  - Rain loop + random thunder during storms.
  - Per-biome ambience and Home Row music, crossfaded by position.
  - Hatch cinematic: egg wobble 1.5 s, crack, camera eases in when within 45 studs, burst in the rarity color, creature pops with a 0.2 → 1.15 → 1 scale bounce. One cinematic at a time.
  - Stable card models rotate.
- Lava lane: back to glowing Neon orange, plus floating embers. CrackedLava read as a rock path, and lava must be obvious.
- Toast grammar fixed: "an Uncommon / an Epic".

Tests (playtest):
- Mesh mount: a Baby Dragon rider sits on its back behind the head (side screenshot).
- Mesh guardian: real walk at speed 16 from the Lake nest gave CAUGHT after 6.2 s; the vignette peaked at 0.59.
- Mama spawns as the mesh dragon (44×43×33) with 3 weak spots; the sky darkens.
- Hatch cinematic plays; four simultaneous hatches no longer fight over the camera.
- All pens full: 160 mesh creatures on 8 plots, viewed down the avenue, ran at 47–60 fps in Studio (empty pens: 47). No measurable drop, and meshes already use RenderFidelity Automatic, so the primitive fallback isn't needed. Check on a real phone.
- Output: no errors.
- Screenshots: screenshots/ folder (Home Row, all 7 biomes, creatures, guardians, riding, Mama, and a "before" Volcano).
- Test save reset: added DataService._deleteSave (tests only, via TestHooks "deleteSave"). The next join was a fresh player (0 creatures, Rebirths 0, shielded).

Rulings:
- Ruling: props use generate_mesh, not generate_procedural_model. The user's complaint was the primitive look, and procedural models are also built from primitives. Cost if wrong: re-run ScatterProps with other templates.
- Ruling: guardian meshes keep the primitive catch radius (BodyRadius). Some meshes are shorter than their primitive (the sitting Tiger), so the Tiger catches from slightly ahead of its nose. Cost if wrong: one attribute per guardian.
- Ruling: creature meshes face -Z as generated. Checked in a lineup and a top-down shot; no rotation needed.
- Ruling: some Creator Store sounds come from community uploaders, not the official libraries (cork pop, coin, sirens, blizzard). If any won't play in the live game, swap the ID in SoundService.SFX and Config.Sounds.

Skipped / for the user:
- 2D art (icons, thumbnails): no image-generation connector is set up, so it's skipped per the spec.
- Guardian prompts with "monster/giant/angry" failed Roblox moderation; the plain species-style prompt passed.
- Material and mesh generation fail during Play mode and under heavy parallel load ("Too Many Requests"). Run them 3 at a time, in Edit mode.
- Studio changes are not saved to Roblox yet: File > Save to Roblox (or Publish) to keep them.

## Walk cycles (user request: creatures should look like they're walking, not sliding)
Built:
- ReplicatedStorage.Shared.WalkCycle: a cartoon gait for single-mesh models.
  - One bounce per step; the body rolls toward the stepping side; a forward lean and a small nod.
  - Gaits: quad, biped (rooster, swan, yeti), heavy (Mama), float (Star Jelly, Ember Bat).
  - Also an idle "breathing" pose.
- GuardianService: the real position (g.cf) is now separate from the rendered pose, so the bounce never changes chase or catch math.
  - Steps follow distance travelled (stride = 0.45 × the model's footprint).
  - Each footfall sets the guardian's Step attribute.
  - Sleeping guardians breathe.
- MamaService: heavy gait timed to the stomp interval, so every stomp (camera shake) lands on a footfall.
- MountService: the mount is held by a Weld (was a WeldConstraint) with BaseC0/Gait/Stride/Height attributes. Every client animates C0 locally from the rider's ground speed, so other players see it too.
- Effects (client): mount walk/idle for riders within 250 studs; pen creatures breathe (plots within 180 studs).
  - Guardian footfalls make a dust puff and a pitched-up thud.
  - Mama's stomps make a big dust ring.

Tests (playtest): Swan chase rolled ±10° and bounced 0.8 studs per step, with footfalls firing; a Fox mount at speed 27 rolled ±5°; Mama swayed ±4° on a 1.2 s step; pen Duckling bobbed. Output: no errors.
- Ruling: whole-body motion only (legs don't move separately). Separate leg animation needs re-generated, segmented meshes; the user chose this option first.
- Note: this test added a Rare Fox (now a mount) to the user's save, and a test Mama defeat granted 2 Lucky Eggs.

## Option 2 trial: real legs on one guardian (Forest Rooster)
Built:
- segment_mesh split the Rooster mesh into body + left leg + right leg. The new Guardian_Forest template has two Motor6D hips (LeftHip/RightHip, Side = ±1), placed at the top of each leg piece, 30% toward its back.
  - Only the body is anchored; the legs hang off it by the joints.
  - The old static template is in ServerStorage.Guardian_Forest_Static (to roll back, move it back to ReplicatedStorage.CreatureMeshes as Guardian_Forest).
- Fixed: the Rooster mesh faced +Z (backwards; it chased tail-first). It now has a 180° PivotOffset.
  - Checked all 7 guardians top-down: the others face -Z correctly.
- CreatureBuilder keeps Motor6D joints on rigged templates (no weld). GuardianService anchors only the body of rigged guardians and swings the hips ±35° per step with the walk cycle (opposite legs, opposite directions).

Tests (playtest): real chase: the left hip swung 35 → -35 → 35 over one stride; the screenshot catches it mid-stride (screenshots/13-rooster-legs-midstride.jpg). Legs stay attached; at rest both feet sit under the body. Output: no errors.
- Note: segment_mesh only cut the shin + foot (legs are short on this model), so the motion reads as stepping feet, not full legs.
- Note: this approach suits short-legged models. Long-legged quadrupeds (Tiger, Hellhound) need 4 legs and better hip placement.

## Codex handoff audit (6 October 2026)
Built:
- Reviewed the complete game spec and build log, including the whole-body walk cycles and Forest Rooster leg trial. Inspected only Steal a Ride (Studio 619034c6-d2cc-4b21-b38e-48bcf5c1bfcc, PlaceId 91426156190208, GameId 10769593546).
- Confirmed the current place has 17 server services, all 4 shared modules, ClientMain and UIController, 8 plots, 21 species mesh templates and 7 guardian mesh templates, biome materials/props, and the 2 edit-time BuildTools.
- Confirmed only Guardian_Forest is rigged (2 Motor6D hips). The other 6 guardians use whole-body motion. Guardian_Forest_Static and PrimitiveProps backups are present.
- No gameplay scripts, UI or assets changed. This section records the audit and remaining work.

Tests:
- Fresh single-player startup smoke checks: all 7 guardians spawned with BodyRadius attributes; player assigned Plot1; DataLoadFailed=false. Output contained no errors on startup or after the first stop. Returned Studio to Edit mode.
- Read the active profile through the existing TestHooks json action: profile available, 12 creatures, 0 mounts, 0 PendingEggs, 0 rebirths and 2334 seconds of saved playtime. This is not a fresh-player save; no reset was performed.
- Sound inventory: all 24 Sounds have nonempty SoundIds. This does not verify audio permissions in a live Roblox server.
- No full gameplay regression, 2-player test, device performance test or purchase failure simulation was run in this audit. Earlier PASS entries remain historical results.

Rulings:
- Publishing correction: Part 1 already recorded a private publication and successful real DataStore save/load cycle with Studio API access enabled. Current PlaceId/GameId and successful profile loading support that setup. Later Studio edits still need Publish to Roblox; this audit did not publish or change the audience.
- Current GuardianService differs from spec section 8 and the recorded Part 2/3 tests: it now hunts carriers passing through a biome and continues across biome boundaries until Home Row's safe line, a usable escape lane, or a catch. Treat the old per-biome speed tests as insufficient for this behavior; test full return trips and document the intended rule before release. No behavior was reverted.
- Purchase safety finding (static code inspection): processReceipt grants the product before saving. If save fails, it removes the receipt marker without undoing the grant, so a retry can grant again. Repair and test failed-save/retry and failed-load cases before enabling paid products. All 5 pass IDs and 3 product IDs remain 0 in Config.Monetization.
- DataService explicitly has no session locking. Assess cross-server save races before paid/live progression is relied on; the normal load-fail save guard is present.
- Remaining validation: 2-player carrier steal, unlocked-base raid, Take Back, locked-base push-out, Net Gun, shield/cooldown rules and Mama HP scaling; real clicks on Mama weak spots; touch ability controls and performance on a real phone; live audio and live save/offline-hatch behavior.
- Remaining setup/polish: create passes/products and enter real IDs if monetization is wanted; icon/thumbnails remain absent from the documented work; rewarded ads were deliberately deferred; balance milestones still need timed playtests.
- Additional guardian leg rigs are optional polish, pending the user's choice. Tiger/Hellhound need four segmented legs and appropriate hips; preserve existing templates and chase coordinates if that work is requested.

## Balance review follow-up (6 October 2026)
Built:
- Read AbilityService, ShopService, CreatureService and HatchService for the balance question. No balance values or gameplay behavior changed.
- Created art/raw beside this spec and log for the user's already-generated Part A PNG icons; no images uploaded or UI changed.
Tests:
- Checked actual map attributes: Lake nest to Home Row safe line is 346 studs; Cosmic is 2496 studs. Ability lanes can end chases earlier.
- Recomputed from current Config source: one Jungle Common earns $800/s and reaches the $100K first-rebirth cash requirement in 125 seconds, ignoring prior cash and spending. Its first discovery pays $48K, leaving 65 seconds of income; a Jungle Rare discovery pays at least $192K, above that requirement.
- Fusing 3 Common creatures into 1 Uncommon reduces their combined base income from 3x to 2x (one-third loss) in exchange for speed and freed slots.
- An Edit-mode arithmetic probe using require(Config) hit a nil helper in the cached module and logged AssistantCommand:13. Re-ran the arithmetic successfully from values read in current Config source, without using the Edit-mode module cache. This was a diagnostic command error, not a gameplay startup error.
Rulings:
- Balance is not validated. Full-return chase behavior invalidates reliance on the old per-biome escape tests, and first-discovery rewards can make the first-rebirth cash requirement trivial after a lucky Jungle hatch.
- Need clean-player timed sessions for first hatch/ride, Lake, first Rebirth and Cosmic, plus multiplayer PvP tests. Preserve the current player save; no test cash/creatures were granted or removed.

## User-supplied 2D art (6 October 2026)
Built:
- Checked all 19 user PNGs in art/raw. Prepared 15 transparent 256x256 UI icons, a 512x512 game icon and three 1920x1080 thumbnails. Originals are unchanged; art/prepare_art.py repeats the preparation and validates dimensions/alpha.
- Uploaded all 15 UI icons to Roblox. Asset IDs are in art/roblox-icons.json and ReplicatedStorage.Shared.Config.Icons (6 abilities, 3 gear items, 6 rarities).
- Added images beside existing text in Stable cards and Index discovery rows/chips, plus Shop gear rows, the gear hotbar and the native Dash touch button. Undiscovered Index badges remain dimmed; undiscovered abilities remain hidden.
- Kept gear key/count labels and all existing actions. Raised Stable/Shop panels to ZIndex 5, matching the existing Retention panels, so the hotbar cannot cover their content. Enlarged the Dash touch button to 64x64 and separated its icon/title; moved it clear of the panels and above Jump.
- Saved original copies of the 6 changed scripts in ServerStorage.ArtIntegrationBackup_20261006. No gameplay services, economy values, guardian positions/radii or save logic changed.
- Prepared Part B in art/page: page_icon.png, thumb_heist.png, thumb_riding.png and thumb_mama.png. Contact sheets are art/icons-preview.jpg and art/page-preview.jpg.

Tests:
- File preparation assertions passed: exactly 15 icons and 4 page images, correct output dimensions, transparent alpha on every UI icon. Visually inspected both contact sheets.
- First startup exposed Config.Icons being inserted inside Config.income by an overly broad text match. Corrected the insertion to the module's final return; subsequent startup and UI checks have empty Output.
- A temporary runtime image grid displayed every uploaded icon: all 15 reported IsLoaded=true and rendered correctly. Removed that test overlay afterward. PreloadAsync from the MCP command context reported Failure, so actual runtime loading/rendering was used as the evidence.
- Desktop: opened Index with a real mouse click; checked discovered badges/ability art and dimmed unknown badges. Inspected Stable cards, Shop images and gear hotbar. Final Shop check: net/trap/soda images loaded and existing titles/prices present.
- iPhone 17 Pro landscape simulation: TouchEnabled=true; native Dash icon loaded; screenshots confirm a readable separate Dash label, gear icons in Shop and ability/rarity icons in Stable. Shop/Stable content no longer sits behind the hotbar.
- MCP mouse input did not activate menus in touch simulation; used existing panel-open/refresh paths for phone visual checks. Actual touch gameplay and phone performance remain unverified; this is not a full responsive or gameplay regression test.
- Final playtest Output: no errors. Returned Steal a Ride to Edit mode and restored the default viewport. Stopped the temporary localhost image-upload server.

Rulings:
- User's gear_banana.png is the Slip Trap icon; the prepared/uploaded copy is gear_trap.png. The raw filename is preserved.
- Part B is prepared for the user to upload in Creator Dashboard: Steal a Ride > Configure > Places > start place > Icon / Thumbnails. Thumbnail pages have separate Home Page and Experience Detail Page tabs.
- The 15 image assets are uploaded, but the Studio script/UI changes still need Publish to Roblox. This work did not publish the place, change its audience, or upload the game-page art.
- No test cash, creatures or gear were granted, removed or reset. Normal passive income/offline hatching can persist during playtests against the existing profile.

## Restore missing icon references (6 October 2026)
Built:
- Restored Config.Icons at the module's final return using the existing 15 uploaded IDs from art/roblox-icons.json. The open place had no icon mapping, so the existing UI assigned empty image strings.
- Preserved the user's original PNG artwork, labels and UI layout. Backed up Config as ServerStorage.ArtIntegrationBackup_20261006.ConfigBeforeIconsRestore; added ServerStorage.BuildTools.IconChecks for checking all referenced gear, abilities and rarities.

Tests:
- IconChecks failed before the mapping was restored and passed afterward. A temporary client image grid verified all 15 original uploads have IsLoaded=true; removed the grid afterward.
- Desktop screenshots confirm the three original hotbar images, Index ability/rarity art and all three Shop gear images. Scrolled Shop to show the gear rows before checking image loading. Hidden/offscreen rows initially reported IsLoaded=false and generated diagnostic assertion messages, not gameplay errors.
- Stable was empty in this playtest, so populated Stable cards were not visually verified. No profile or inventory changes were made by the icon fix.
- Final fresh startup: all three hotbar PNGs loaded, Output empty. Returned Studio to Edit mode.

Rulings:
- Reuse the original uploaded assets; art/roblox-icons.json remains the authoritative manifest. The unnecessary replacement set is not connected to the game, and its duplicate local manifest/generator were removed.
- Save/publish the Studio changes to update the live game. Game-page icon and thumbnails are separate and were not uploaded by this repair.

## Likes, quests and friends (8 October 2026)
Built:
- Implemented in the user's order: daily visitor likes with persistent totals and a third Top Bases board; three daily/three weekly quests with authoritative claims and one-time weekly Luck; native same-server friends income bonus (+10% each, capped at 30%) and invite prompt.
- Reused existing gameplay hooks and Menu style. Quests scroll on small screens with 44px actions; all nine Menu entries fit landscape phones. Daily/Offline popups wait for open panels and restore touch controls after closing.
- Review fixes: final leaderboard score flush before profile release, monotonic all-time likes updates, profile save before board I/O, and steal quest progress only after egg attachment succeeds.

Tests:
- 25 actual-source groups PASS; 48 Luau files compile. All 15 changed/new game sources match Studio after CR normalization.
- Isolated stores verified actual deposit/hatch/chest/fuse/earn events, daily and three weekly mouse claims, Luck once, save/rejoin state, final OrderedDataStore flush, simulated friend cap/income/HUD, native invite screen, phone/tablet geometry and popup locking/restoration. See steal-a-ride/engagement-verification-20261008.json.

Rulings:
- Studio returned to Edit; production StealARide_v2 and legacy StealARide_v1 restored; no temporary probes remain. Original iPad emulator restored. No publish, commit or push.
- Real multiplayer likes/steals and positive native same-server friendship still need two real players; no invitations sent. Physical-device play/performance untested. Known CAS warnings remain.
- Rollback originals: steal-a-ride/before-engagement-20261008/src and ServerStorage.EngagementBackup20261008. OG migration and Cosmic gift preserved.

## PC Get off shortcut (8 October 2026)
Built:
- R invokes the existing all-mount dismount action while riding; focused text input passes through. Existing touch button and server Stable-capacity checks retained. Guide basics explain R and touch Get off.
Tests:
- Test-first real-source keyboard guard/lifecycle check; full suite 26 groups PASS and48-source compile. Isolated desktop Play verified real R returns both mounts with pets preserved, no dismount while a TextBox has focus, R resumes after releasing focus, and Guide text fits. Source equality verified for ClientMain/Config.
Rulings:
- Studio Edit, production v2 and legacy v1 restored, iPad emulator restored; unpublished. Originals: steal-a-ride/before-getoff-key-20261008 and ServerStorage.GetOffKeyBackup20261008.
