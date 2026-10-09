# Top Players board (design)

Status: design approved in chat 2026-10-09 (all decisions below are the user's). Not implemented.
Reference: user's mockup (wooden board, crown, lanterns, 2-1-3 podium of gold/silver/bronze cards) is a reference,
not a pixel target.

## Goal

A centrepiece board in the Plaza showing the top 3 players currently in the server, each as a real 3D figure in
their own outfit with their name, rebirth title, index count and income. The three existing leaderboards get the same
wooden look.

## Ranking (current server only)

- Players in this server only; no DataStore, no cross-server data.
- Order: most rebirths, then larger creature index (number of discovered species + rarity combos, the keys of
  `data.Index`), then higher income per second. Remaining ties: stable by join order.
- Recomputed every 3 s and on join/leave; the board is touched only when the top 3 or a shown value changes.

## Board content

- Header "TOP PLAYERS" with a gold crown.
- Three cards in podium order left to right: #2, #1, #3; #1 taller and raised.
- Each card, top to bottom: number badge (gold 1, silver 2, bronze 3), the player's 3D figure on a ledge in front of
  the card, display name, rebirth title, "Index N", income per second shortened (e.g. 126.4M).
- Fewer than 3 players: the missing cards stay up, dimmed, reading "Waiting for a challenger", with no figure.

## Rebirth titles: Squire

- `Config.rebirthTitle(n)` returns "Squire" for 0 and 1 rebirths (today it returns nil below 2). Squire then appears
  everywhere titles appear: rebirth menu, rank-up toast, base sign, Most Rebirths board, Top Players board.
- Every caller is checked for code that relied on nil below 2 rebirths.

## Look (style B: wooden notice board)

- Top Players board at the centre back of the Plaza, about (0, 210), screen facing the arch (-Z), the same way the
  spawn faces: wooden posts and frame about 30 studs wide and 20 tall, header plank, glowing gold crown, two hanging
  lanterns with real light, three card panels with gold/silver/bronze frames, text in FredokaOne (the game's font).
- Figures: life-size (about 5-6 studs) on small wooden ledges in front of their cards, facing the arch, #1's ledge
  higher; anchored, no collision, not hit by queries, a simple idle pose.
- Existing boards (Top Income left at x -30; Most Rebirths x 30 and Top Bases x 60 on the right; z 211, facing the
  arch): positions and data unchanged (all-time top 10), restyled with the same wooden frame, posts and header plank;
  list on a dark wood panel, rows 1-3 gold/silver/bronze; Most Rebirths rows read "12 · Divine Overlord".
- Index stall (Professor Page, books, prompt) moves from the centre (0, 208) to the back-left corner, about (-62, 205),
  facing the arch.
- Spawn keeps facing the arch; its yellow pad becomes invisible (Transparency 1) but stays the spawn point (deleting it
  would make players spawn at random places).

## Components

- `ServerScriptService/Services/TopPlayersService.luau` (new): pure `TopPlayersService.rank(entries)` returning the
  top 3 in order; loop + join/leave hooks; writes card text; builds figures with
  `Players:CreateHumanoidModelFromUserId` once per player and reuses them until the player leaves the top 3; failed
  avatar loads leave the card without a figure and retry later. Started from `Main`.
- `ServerStorage/BuildTools/BuildTopPlayers.luau` (new, rerunnable, Studio-only like BuildPlaza): builds the board
  parts, ledges and lanterns; restyles the three leaderboards' frames; moves the Index stall; hides the spawn pad.
  Map changes live in the place file.
- `ServerScriptService/Services/PlazaService.luau`: leaderboard text drawn on the dark wood panel style; Most
  Rebirths rows with titles.
- `ReplicatedStorage/Shared/Config.luau`: Squire in `rebirthTitle`; board settings (refresh interval, labels);
  What's New version 5 with lines for the Top Players board and the Squire title (v1-v4 are published and frozen).

## Error handling

- Avatar load failure: card shown without a figure, retried on a later refresh.
- Player leaves: their card and figure go on the next refresh (immediately on leave).
- A player whose save has not loaded yet (no data) is skipped until it loads; a DataLoadFailed player is ranked from
  their in-session data like anyone else.

## Testing

- Unit tests first (tests/run_feedback_checks.py harness): rank order, every tie-break, fewer than 3 players,
  `rebirthTitle(0) == rebirthTitle(1) == "Squire"`, titles from 2 rebirths unchanged.
- All 7 test runners pass; every Luau source compiles.
- Studio Play (fake store): one player shows #1 with two waiting cards; a stat change reorders/updates; a figure
  loads in full outfit; leave clears the card; screenshots of the board close up and at phone size for the user;
  Studio == local signatures for every changed script.

## Out of scope

All-time or cross-server Top Players, rewards for being #1, turning the spawn, other Plaza changes.
