# Engineering Guide

## Product boundary

This addon is a runtime compatibility layer. Never copy, replace, or edit dependency files. Keep every Chattynator-specific frame signature and optional persistence call in `Adapter.lua`.

## Module ownership

- `Database.lua`: SavedVariables defaults, validation, and geometry storage.
- `Adapter.lua`: dependency discovery and optional Chattynator-facing seams.
- `Background.lua`: texture selection and solid/gradient rendering.
- `Geometry.lua`: position and size capture/application.
- `Unlock.lua`: EllesmereUI registration callbacks.
- `Settings.lua`: native Settings controls and slash commands.
- `Core.lua`: lifecycle and event routing.

## Invariants

- Never change frame geometry during combat lockdown; defer it to `PLAYER_REGEN_ENABLED`.
- Never poll for windows. Rescan on lifecycle events, Unlock Mode entry, or explicit user action.
- Do not make the monkeypatch database dependent on Chattynator's internal configuration schema.
- Preserve Lua 5.1 compatibility and four-space indentation.

## Upgrade audit

After a Chattynator update, verify that `Adapter:Scan()` still detects every window, a native background texture is selected when available, and the fallback overlay remains behind message content. After an EllesmereUI update, verify mover registration, dragging, width/height controls, reset, save, and discard.

## In-game regression checklist

- First login and `/reload` retain colors and geometry.
- Solid and gradient colors update live.
- Both gradient opacities render independently.
- Every Chattynator window appears in Unlock Mode.
- Drag, nudge, resize, reset, save, and discard behave correctly.
- Entering combat does not produce a blocked-action or taint error.
- Creating a new window followed by Rescan registers it once.
