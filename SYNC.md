# Working on another computer

Private repository: https://github.com/ei-so/roblox-games

This repository keeps the local Roblox Games folder: source code, assets, tests, backups, plans, and shared agent instructions. Read AGENTS.md and HANDOFF.md before making changes. The root src/README belong to Power Core Incremental; steal-a-ride/ contains Steal a Mount.

## First time on another computer

Sign in to GitHub as ei-so, then clone:

```powershell
git clone https://github.com/ei-so/roblox-games.git
cd roblox-games
```

Open that folder in Codex or Claude Code. Continue using Roblox Studio as eisoisoo and open the game from Roblox. Local place backups may be older than the current published game; Git does not synchronize the live Studio place or player data.

## Each time you switch

On the computer you are leaving, update HANDOFF.md and save the local work:

```powershell
git add .
git commit -m "Save project progress"
git push
```

On the computer you are switching to, pull before editing:

```powershell
git pull --ff-only
```

Use one writing agent/computer at a time. If the pull reports conflicting local changes or divergent history, preserve the work and resolve it before continuing; do not force-push or reset it away.

## Local-only files

.env, private key files, Python caches, dependency folders, and virtual environments are excluded from Git. They remain on the original computer. For art generation on a new computer, create your own local .env with GEMINI_API_KEY; transfer the key securely, never through a commit. Codex/Claude account sign-ins, machine settings, and memory outside this folder are not included.
