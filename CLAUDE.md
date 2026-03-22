# CLAUDE.md - WhoGotLoots

## What is this?

A World of Warcraft addon that tracks and displays looted items shared between party and raid members. It shows real-time loot notifications with stat comparisons, upgrade detection, and one-click interactions (trade, whisper, equip).

- **Version**: 1.5.3
- **Interface**: 110002 (Dragonflight), 120000 (The War Within)
- **License**: GPLv3
- **No external dependencies** — pure WoW API, no Ace/LibStub

## Project structure

```
WhoGotLoots.toc          # Addon manifest — defines load order
WhoGotLoots.lua          # Core: event handling, loot processing, item comparison
UIBuilder.lua            # UI framework: main frame, 9-slice backgrounds, stat frames
ItemBox.lua              # Item frame pool (10 pre-allocated frames, recycled)
CacheHandler.lua         # Async player gear inspection with retry logic
ItemsDB.lua              # Class/spec gear compatibility database
OptionsMenu.lua          # Settings panel UI (13 options, saved to WhoGotLootsSavedData)
util.lua                 # Shared utilities (stat math, GUID lookups, lerp, debug)
Localization.lua         # i18n strings (currently enUS only)
Art/Fonts.xml            # 7 virtual font definitions (loaded first)
Art/UIElements.xml       # 7 virtual UI frame templates (checkboxes, buttons, slider)
Art/                     # TGA textures for backgrounds, borders, icons
Fonts/                   # OpenSans and HK Grotesk font files
docs/                    # Architecture and module documentation
```

## Key namespaces

| Namespace | File | Purpose |
|-----------|------|---------|
| `WhoLootData` | WhoGotLoots.lua | Global addon state (`ActiveFrames`, `MainFrame`, `OptionsFrame`) |
| `WGLU` | util.lua | Utility functions |
| `WGLUIBuilder` | UIBuilder.lua | UI creation |
| `WGL_FrameManager` | ItemBox.lua | Frame pool factory |
| `WGLCache` | CacheHandler.lua | Async inspection handler |
| `WGLItemsDB` | ItemsDB.lua | Gear equippability checks |
| `WGLL` | Localization.lua | Localization strings |

## File load order (from .toc)

1. Art/Fonts.xml → 2. Art/UIElements.xml → 3. ItemsDB.lua → 4. util.lua → 5. UIBuilder.lua → 6. ItemBox.lua → 7. CacheHandler.lua → 8. WhoGotLoots.lua → 9. OptionsMenu.lua

Load order matters — later files depend on namespaces from earlier ones.

## Coding conventions

- Lua 5.1 (WoW embedded) — no `goto`, no bitwise operators, no `//` division
- All WoW API calls are global (no `local WoW = ...` wrappers)
- Namespaces are plain global tables (e.g., `WGLU = {}`, `WGLUIBuilder = {}`)
- Frame methods are added directly to frame objects (e.g., `frame.Reset = function(self) ... end`)
- Async item loading uses `Item:CreateFromItemLink()` + `item:ContinueOnItemLoad(callback)`
- UI uses a custom 9-slice system (`DrawSlicedBG`) — not the built-in WoW backdrop API
- Settings persist via `WhoGotLootsSavedData` (WoW SavedVariables)
- No semicolons, tabs for indentation

## Important patterns

- **Frame pooling**: 10 item frames are pre-allocated at load. Never create/destroy frames at runtime — use `WGL_FrameManager` to acquire and `.Reset()` to recycle.
- **Three-value equippability**: `ClassAndGearDB` returns `true` (appropriate), `false` (equippable but wrong type), or `nil` (cannot equip). All three states have distinct UI treatment.
- **Async inspection**: Player gear data may not be cached. `WGLCache` queues sequential `NotifyInspect()` calls with max 5 retries at 2-second intervals.
- **Event-driven**: Core logic is driven by `CHAT_MSG_LOOT` and `INSPECT_READY` events. No polling for loot.

## Testing

There is no automated test framework. Testing is done in-game:
- `/wgl` — toggle the main window
- `/wgl add [itemLink|itemID]` — manually inject a loot item for testing
- `/wgl debug` — toggle debug mode (verbose chat output + cache overlay)

## Docs

See `docs/` for detailed reference:
- `ARCHITECTURE.md` — high-level overview, data flow, design decisions
- `MODULES.md` — per-file function reference
- `DATA-STRUCTURES.md` — saved variables, runtime state, frame properties
- `UI-SYSTEM.md` — templates, 9-slice system, animations, layout
- `EVENTS-AND-INTERACTIONS.md` — event handling, loot pipeline, user interactions
