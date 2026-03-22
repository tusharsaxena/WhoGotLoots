# WhoGotLoots - Architecture Overview

## Addon Identity

| Field | Value |
|-------|-------|
| **Name** | Who Got Loots |
| **Version** | 1.5.3 |
| **Purpose** | Tracks and displays looted items shared between party and raid members |
| **License** | GNU General Public License v3 |
| **Interface** | 110002 (Dragonflight), 120000 (The War Within) |
| **SavedVariables** | `WhoGotLootsSavedData` |
| **Dependencies** | None (pure WoW API, no embedded libraries) |

## Directory Structure

```
WhoGotLoots/
├── WhoGotLoots.toc          # Addon manifest
├── WhoGotLoots.lua           # Core event handling & loot processing (843 lines)
├── UIBuilder.lua             # UI framework & main frame creation (974 lines)
├── ItemBox.lua               # Item frame pool manager (307 lines)
├── CacheHandler.lua          # Async player inspection queue (268 lines)
├── ItemsDB.lua               # Class/spec gear compatibility DB (577 lines)
├── OptionsMenu.lua           # Settings panel UI (394 lines)
├── util.lua                  # Shared utility functions (200 lines)
├── Localization.lua          # i18n strings (23 lines)
├── Art/
│   ├── Fonts.xml             # 7 virtual font definitions
│   ├── UIElements.xml        # 7 virtual UI frame templates
│   ├── MainWindowBG.tga      # Main window background
│   ├── OptionsWindowBG.tga   # Options panel background
│   ├── ItemBG.tga            # Item entry & stat frame background
│   ├── ItemBox_Upgrade.tga   # Upgrade glow texture
│   ├── EdgedBorder.tga       # Standard border
│   ├── EdgedBorder_Sharp.tga # Item entry border
│   ├── EdgedBorder_Sharp_Thick.tga # Button/stat border
│   ├── SelectionBox.tga      # Cursor frame selection box
│   ├── CloseBtn.tga          # Close button
│   ├── InfoButton.tga        # Info/help button
│   ├── OptionsGear.tga       # Settings gear icon
│   ├── checkbox.tga          # Checkbox background
│   ├── checkbox_check.tga    # Checkbox tick mark
│   ├── checkbox_hover.tga    # Checkbox hover state
│   ├── RightArrow.tga        # Arrow separator (player -> item)
│   ├── SliderThumb2.tga      # Slider handle
│   └── LoadingIcon.tga       # Animated loading spinner
└── Fonts/
    ├── OpenSans-Bold.ttf
    ├── OpenSans-BoldItalic.ttf
    ├── OpenSans-SemiBold.ttf
    ├── OpenSans-SemiBoldItalic.ttf
    ├── hk-grotesk.bold.ttf
    └── hk-grotesk.medium.ttf
```

## File Loading Order

Defined in `WhoGotLoots.toc`, files load in this sequence:

```
1. Art/Fonts.xml         # Font definitions (must load first for UI)
2. Art/UIElements.xml    # Virtual frame templates
3. ItemsDB.lua           # Class/gear database (no dependencies)
4. util.lua              # WGLU namespace (no dependencies)
5. UIBuilder.lua         # WGLUIBuilder namespace (uses WGLU)
6. ItemBox.lua           # Frame pool (uses WGLUIBuilder, WGLU)
7. CacheHandler.lua      # Inspection cache (uses WGLU)
8. WhoGotLoots.lua       # Main addon core (uses all above)
9. OptionsMenu.lua       # Settings panel (uses WGLUIBuilder, WGLU)
```

## Namespace Map

| Namespace | File | Purpose |
|-----------|------|---------|
| `WhoLootData` | WhoGotLoots.lua | Global addon state: `ActiveFrames[]`, `MainFrame`, `OptionsFrame` |
| `WGLU` | util.lua | Utility functions: stat math, GUID lookups, debug |
| `WGLUIBuilder` | UIBuilder.lua | UI creation: frames, stat displays, 9-slice backgrounds |
| `WGL_FrameManager` | ItemBox.lua | Item frame pool factory |
| `WhoGotLootsFrames` | ItemBox.lua | Array of all pooled item frames |
| `WhoLootFrameData` | ItemBox.lua | Animation constants and frame config |
| `WGLCache` | CacheHandler.lua | Async player inspection request handler |
| `WGL_Request_Cache` | CacheHandler.lua | Active inspection request table |
| `WGLItemsDB` | ItemsDB.lua | Item equippability checks |
| `ClassAndGearDB` | ItemsDB.lua | Class/spec/gear compatibility matrix |
| `class_specs` | ItemsDB.lua | Class-to-spec-ID mappings |
| `WhoLootsOptionsEntries` | OptionsMenu.lua | Options panel controls and callbacks |
| `WhoLootsOptionsFrame` | OptionsMenu.lua | Options frame reference |
| `WGLL` | Localization.lua | Localization string table |
| `FrameTextures` | UIBuilder.lua | 9-slice texture configuration |

## Cross-File Dependencies

```
                    Fonts.xml ─────────────┐
                    UIElements.xml ─────────┤ (loaded first as XML)
                                            │
ItemsDB.lua ───────────────────────────────┐│
util.lua (WGLU) ──────────────────────────┐││
                                           │││
UIBuilder.lua (WGLUIBuilder) ─────────────┤│├─→ Main UI Framework
  uses: WGLU, FrameTextures               │││
                                           │││
ItemBox.lua (WGL_FrameManager) ───────────┤│├─→ Frame Pool
  uses: WGLUIBuilder, WGLU, WhoLootData   │││
                                           │││
CacheHandler.lua (WGLCache) ──────────────┤│├─→ Async Inspection
  uses: WGLU, WGLUIBuilder, WhoLootData   │││
                                           │││
WhoGotLoots.lua (Core) ──────────────────────── Main Entry Point
  uses: ALL namespaces above               │││
                                           │││
OptionsMenu.lua ──────────────────────────────→ Settings Panel
  uses: WGLUIBuilder, WGLU, WhoLootData
```

## Core Data Flow

```
CHAT_MSG_LOOT event
  │
  ▼
HandleEvents() ──→ Parse item link from chat message
  │                 (regex: |c.-|H.-:.-|h.-|h|r)
  ▼
AddLootFrame(player, itemLink)
  │
  ├─ Filter: quality >= MinQuality?
  ├─ Filter: is armor or weapon? (not cosmetic)
  ├─ Filter: raid/LFR visibility settings?
  ├─ Filter: own loot visibility setting?
  ├─ Filter: equippable for player's class/spec? (WGLItemsDB)
  ├─ Filter: has player's main stat? (WGLU)
  │
  ▼
Compare to equipped item
  │
  ├─ Get equipped item in same slot
  ├─ Rings/trinkets: compare to lowest of the two slots
  ├─ Calculate ilvl diff, main stat diff, secondary stat diffs
  ├─ Check class restrictions via tooltip
  ├─ Check BoP status
  │
  ▼
Display in item frame
  │
  ├─ Acquire frame from pool (WGL_FrameManager)
  ├─ Set icon, player name (class-colored), item name (quality-colored)
  ├─ Show stat comparison (You: +X ilvl upgrade / -X ilvl downgrade)
  ├─ Show secondary stats (Haste, Crit, Vers, Mast diffs)
  ├─ Animate drop-in (scale 1.5 → 1.0)
  ├─ Play sound (ID: 145739)
  │
  ├─ If other player's item not cached:
  │     └─ Queue async inspection (WGLCache)
  │          └─ On INSPECT_READY → show "Them:" comparison
  │          └─ If upgrade for us + downgrade for them → show glow
  │
  ▼
Item frame lifecycle (60 seconds)
  │
  ├─ Progress bar countdown
  ├─ Hover: show GameTooltip, animate background color
  ├─ User interactions (click, shift+click, etc.)
  └─ FadeOut → recycle frame to pool
```

## Key Design Decisions

1. **No external libraries**: All UI, events, and data handling use native WoW API. No Ace framework, LibDataBroker, or LibStub.

2. **Frame pooling**: Pre-allocates 10 item frames at startup. Frames are recycled rather than created/destroyed, avoiding garbage collection pressure.

3. **Async inspection**: Player gear data may not be cached by the WoW client. The addon queues sequential `NotifyInspect()` calls with retry logic (max 5 retries, 2-second intervals) to handle this gracefully.

4. **9-slice backgrounds**: Custom texture slicing system (`DrawSlicedBG`) renders scalable backgrounds from single texture files, supporting corner and edge stretching.

5. **Three-value equippability**: The `ClassAndGearDB` uses a three-value system: `true` (equippable and appropriate), `false` (equippable but not your armor/weapon type), `nil` (cannot equip at all).
