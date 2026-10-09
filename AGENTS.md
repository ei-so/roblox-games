# Project instructions

## Shared handoff

- Before working, read `HANDOFF.md` in this project root. It is the shared checkpoint for Codex and Claude Code.
- Verify its notes against the current files, `git status --short`, and Roblox Studio when relevant. A checkpoint can be stale after an abrupt credit cutoff.
- At task start, record the active agent, current user request, and next action in `HANDOFF.md`. Before a substantial change, mark it in progress; after each meaningful milestone, record changed files, Studio changes, verification results, and the next concrete step.
- Update the checkpoint before ending a session or switching agents. Do not rely on being able to write one last update after credits run out.
- Keep confirmed facts, user decisions, proposals, and untested assumptions distinct. A proposal is not authorization to implement it.
- Resume unfinished authorized work without repeating completed steps. Preserve existing edits and do not overwrite another agent's work. Use one writing agent at a time in this shared workspace.
- Keep `HANDOFF.md` concise and current; replace stale status instead of accumulating full transcripts. Never store credentials or secrets there.

## UI work preference

Whenever creating, adding, updating, restyling, polishing, or redesigning a user interface, use the personal `impeccable` skill at `C:/Users/Desktop/.codex/skills/impeccable/SKILL.md`. Read it before making UI changes, including small component updates. Apply it alongside project instructions and preserve the user's explicit scope and design choices. Backend-only and other non-UI work do not require this skill.

## Implementation preference

Prefer the smallest correct change, existing helpers, standard libraries, and native platform features. Avoid speculative abstractions and dependencies. Preserve validation, error handling, accessibility, and explicitly requested features. Verify changes with checks appropriate to their scope and record the actual outcome.
