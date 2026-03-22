# WhoGotLoots - Module Reference

## WhoGotLoots.lua (Core - 843 lines)

The main entry point. Handles WoW events, parses loot messages, compares items, and orchestrates all user interactions.

### Global State

- `WhoLootData` — Main addon state table
- `WhoLootDataVers` — Version string (`"1.5.3"`)

### Events Registered

| Event | Handler | Purpose |
|-------|---------|---------|
| `ADDON_LOADED` | `HandleEvents()` | Initialize saved variables, load options, set scale/position, parent frames |
| `CHAT_MSG_LOOT` | `HandleEvents()` | Parse loot messages, extract item links, call `AddLootFrame()` |

### Functions

#### `HandleEvents(self, event, ...)`
Main event dispatcher. On `ADDON_LOADED`, initializes `WhoGotLootsSavedData`, calls `LoadOptions()`, sets window position/scale, parents all pooled frames to main window. On `CHAT_MSG_LOOT`, extracts item links via regex `|c.-|H.-:.-|h.-|h|r` and calls `AddLootFrame()`.

#### `AddLootFrame(player, CompareItemLink)`
Core function. Processes a looted item and decides whether/how to display it.

**Flow:**
1. Strip realm from player name
2. Filter by own-loot setting, raid/LFR settings
3. Ensure frame pool has availability (evict oldest if needed)
4. Load item data via `Item:ContinueOnItemLoad()`
5. Filter by quality, item class (armor/weapon only), cosmetic
6. Check equippability (`WGLItemsDB.CanEquip`, `IsAppropriate`)
7. Check main stat match (`WGLU.ItemHasMainStat`)
8. Get equipped item for comparison (special handling for rings/trinkets/neck)
9. Check tooltip for class restrictions
10. For other players: check their equipped item or queue cache request
11. Calculate stat diffs (ilvl, main stat, all secondary stats)
12. Acquire frame from pool, populate, animate, play sound

#### `GetLowestItemBetween(compareItemID, compareItemLVL, slot1, slot2)` (local)
Compares two equipment slots (e.g., both ring slots) and returns the link, ilvl, and slot ID of the lower one. Also handles unique-equipped detection.

#### `IsPlayerInRaidInstance()` (local)
Returns `true` if player is in a raid instance (`IsInInstance()` + `instanceType == "raid"`).

#### `IsRaidLFR()` (local)
Returns `true` if current raid difficulty is LFR (`difficultyID == 17`).

#### `WhoLootData.SetupItemBoxFunctions(frame, itemLink, player)`
Configures all mouse interaction handlers on an item frame:

| Input | Action |
|-------|--------|
| Left click | Double-click to equip (own loot, 0.4s window) |
| Shift + Left click | Insert item link into chat (`ChatEdit_InsertLink`) |
| Alt + Left click | Inspect player (`InspectUnit`) |
| Ctrl + Left click | Initiate trade (`InitiateTrade`) |
| Middle click (own loot) | Send "I don't need" message to party/raid/instance chat |
| Middle click (other's loot) | Whisper player with custom message |
| Right click | Dismiss frame, cancel cache request |

#### `WhoLootData.HoverFrame(fromFrame, toState)`
Manages hover tooltip and background color animation. Shows `GameTooltip` with item hyperlink on enter, hides on leave. Uses sine-eased color lerp between `HoverColor` and `ExitColor`.

#### `WhoLootData.ResortFrames()`
Repositions all active frames vertically below the main window header. If no frames remain and `AutoCloseOnEmpty` is enabled, closes the main window.

#### `SplitCommands(msg)` (local)
Parses slash command arguments, preserving spaces inside item link color codes (`|c...|r`).

### Slash Commands

| Command | Action |
|---------|--------|
| `/whogotloots` or `/wgl` | Toggle main window visibility |
| `/wgl add [itemLink]` | Manually add item (uses current target or player) |
| `/wgl debug` | Toggle debug mode |

### Timer Frame

An anonymous `OnUpdate` frame decrements each active frame's `Lifetime` by elapsed time, updates progress bars, and triggers `FadeOut()` at 0 seconds. Pauses when options panel is visible.

---

## UIBuilder.lua (UI Framework - 974 lines)

Creates and manages all UI frames, templates, and visual elements.

### Constants

```lua
WGLUIBuilder.WhisperMsgMaxChars = 160
WGLUIBuilder.DefaultWhisperMessage = "Greetings, %n! I sense you hold %i..."
WGLUIBuilder.IDontNeedMsgMaxChars = 160
WGLUIBuilder.DefaultIDontNeedMessage = "I don't need %i if anyone wants it!"

WGLUIBuilder.UpgradeStatuses = {
    UPGRADE   = "+%d ilvl upgrade",
    DOWNGRADE = "-%d ilvl downgrade",
    EQUAL     = "Equal Item Level",
}
```

### Functions

#### `WGLUIBuilder.CreateMainFrame() → Frame`
Creates the entire main frame hierarchy:
- **Main frame** (130x50): Background texture, parented to UIParent
- **Cursor frame** (200x40): Invisible overlay for drag/hover detection. Handles `OnDragStart`/`OnDragStop` (saves position), `OnUpdate` (animates button swooping)
- **Options button** (12x12): Gear icon, top-right, calls `OpenOptions()`
- **Close button** (12x12): Below options button, hides main window
- **Info button** (12x12): Top-left, shows keybindings tooltip on hover
- **Info tooltip**: 295px frame with keyboard shortcuts and tips, fade-in/out animation
- **Whisper editor** (360x140): Popup with title, tip text, edit box, save/default buttons, character counter, "Message saved" animation
- **IDontNeed editor** (360x140): Same structure as whisper editor

Also defines methods on the main frame:
- `mainFrame:Move(point)` — Reposition via cursor frame
- `mainFrame:Close()` — Hide and disable mouse
- `mainFrame:Open()` — Show and enable mouse
- `mainFrame:LockWindow(toState)` — Lock/unlock position and movement
- `mainFrame:CompareItemLevels(new, equipped) → text, isUpgrade`
- `mainFrame:SetItemUpgradeStatus(request, theirItemLevel) → upgradeText`
- `mainFrame:UpdateStatBreakdownVisibility()`

#### `WGLUIBuilder.DrawSlicedBG(frame, textureKey, layer, shrink)`
Renders a 9-slice scalable background from a single texture. Creates 9 texture regions (4 corners, 4 edges, 1 center) using texture coordinates from `FrameTextures` table. Supports `"backdrop"` and `"border"` layers.

**Available texture keys:** `OptionsWindowBG`, `EdgedBorder`, `ItemEntryBG`, `ItemEntryBorder`, `SelectionBox`, `ItemEntryGlow`, `BtnBG`, `BtnBorder`, `ItemStatBG`, `ItemStatBorder`

#### `WGLUIBuilder.ColorBGSlicedFrame(frame, layer, r, g, b, a)`
Sets vertex color on all textures in a frame's backdrop or border layer.

#### `WGLUIBuilder.CreateStatFrame(parent, width, text, color) → Frame`
Creates (or recycles from pool) a stat display frame with background, border, and centered text. Auto-detects positive/negative colors from `+`/`-` signs in text if no color provided.

#### `WGLUIBuilder.AddStatToBreakdown(parentFrame, text, position, color, indexOffset, container)`
Adds a stat text frame to either the `"primary"` or `"secondary"` container of an item frame. Measures text width, creates stat frame, positions in flow layout with wrapping. Updates container heights and parent frame height.

#### `WGLUIBuilder.ClearStatContainer(parentFrame)`
Hides and removes all stat frames from both primary and secondary containers, returning them to the pool.

#### `WGLUIBuilder.CreateStatBreakdownFrames(parentFrame, bottomText)`
Clears existing stats and populates the secondary container with the provided stat text array.

#### `WGLUIBuilder.UpdateContainerPositions(parentFrame)`
Positions the secondary container below the primary, calculates total frame height (minimum 45px).

#### `WGLUIBuilder.AddOnClick(button, newOnClick)`
Wraps an existing `OnClick` handler, calling the original first then the new handler.

### Templates Configuration (`WGLUIBuilder.Templates`)

```lua
StatFrame = {
    size = { height = 12 },
    padding = 2,
    minWidth = 25,
    textPadding = 1,
    background = { texture = "ItemStatBG", color = { r=1, g=1, b=1, a=0.1 } },
    border = { texture = "ItemStatBorder", color = { r=0.3, g=0.3, b=0.3, a=0.8 } },
    text = {
        font = "WGLFont_Item_StatBottomText",
        colors = {
            positive = { r=0.384, g=0.840, b=0.294 },  -- Green
            negative = { r=0.878, g=0.333, b=0.333 },  -- Red
            normal   = { r=1.0,   g=1.0,   b=1.0   },  -- White
        }
    }
}
```

---

## ItemBox.lua (Frame Pool - 307 lines)

Manages the pre-allocated pool of item display frames.

### Constants

```lua
WGL_NumPooledFrames = 10
WhoLootFrameData.FrameLifetime = 60        -- seconds
WhoLootFrameData.HoverAnimTime = 0.3       -- seconds
WhoLootFrameData.HoverColor = { 0.3, 0.3, 0.3, 1 }
WhoLootFrameData.ExitColor  = { 0.1, 0.1, 0.1, 1 }
WhoLootFrameData.BorderColor = { 0.5, 0.5, 0.5, 1 }
```

### Functions

#### `WGL_FrameManager:CreateFrame()`
Factory function that creates a single item frame (270x48) with all visual components:

**Frame Components:**
- `background` — 9-slice backdrop (ItemEntryBG, dark semi-transparent)
- `UpgradeGlow` — Pulsing white overlay (cosine-driven alpha), hidden by default
- `border` — 9-slice border (ItemEntryBorder)
- `Icon` — 22x22 item texture (defaults to question mark)
- `PlayerText` — FontString with player name (class-colored)
- `PlayerArrow` — 8x8 right arrow texture
- `ItemText` — FontString with item name (quality-colored)
- `ProgressBar` — StatusBar showing lifetime countdown (3px height)
- `LoadingIcon` — Animated spinner (LoadingIcon template)
- `statContainer.primary` — Primary stat comparison container
- `statContainer.secondary` — Secondary stat breakdown container
- `Close` — Close button (WGLCloseBtn template)

**Frame Properties:**
- `.Item` — Item link string
- `.Player` — Player name/unit
- `.InUse` — Boolean, currently displaying an item
- `.Animating` — Boolean, animation in progress
- `.IsUpgrade` — Boolean, item is an upgrade
- `.Lifetime` — Remaining seconds (counts down)
- `.QueuedRequest` — Pending cache inspection ID
- `.HoverAnimDelta` — Hover animation progress (nil when not hovering)
- `.lastClickTime` — For double-click detection

**Frame Methods:**
- `ShowUpgradeGlow()` — Show pulsing white glow overlay
- `HideUpgradeGlow()` — Hide glow
- `Reset()` — Clear animation state, reset lifetime, mark not in use
- `UpdateStatBreakdownVisibility()` — Show/hide stat containers based on settings (always shows for upgrades)
- `DropIn(targetScale, duration)` — Entry animation: scale 1.5→1.0, color white→dark
- `FadeOut()` — Exit animation: alpha 1→0, remove from active list, resort

**Close button** calls `CloseFrame()` which plays sound, hides frame, removes from `ActiveFrames`, and resorts.

#### `WGL_FrameManager:UpdateAllFramesStatBreakdownVisibility()`
Iterates all in-use frames and calls `UpdateStatBreakdownVisibility()`, then resorts.

### Initialization

On load, creates 10 frames in a loop:
```lua
for i = 1, WGL_NumPooledFrames do
    WGL_FrameManager:CreateFrame()
end
```

---

## CacheHandler.lua (Async Inspection - 268 lines)

Handles asynchronous player gear inspection when item data isn't cached.

### Constants

```lua
WGLCache_RetryTime  = 2     -- seconds between retries
WGLCache_MaxRetries = 5     -- max retry attempts
WGLCache_Frequency  = 0.5   -- OnUpdate poll interval (seconds)
```

### State Enum (`WGLCacheCacheStage`)

| Value | Name | Meaning |
|-------|------|---------|
| 1 | `Sent` | `NotifyInspect()` called, waiting for `INSPECT_READY` |
| 2 | `Queued` | Waiting for current inspect to complete |
| 3 | `Finished` | Data received and processed |
| 4 | `Failed` | Max retries exhausted |

### Functions

#### `WGLCache.CreateRequest(unitName, request) → ID`
Queues a new inspection request. If no inspect is in progress, immediately calls `NotifyInspect()`. Otherwise queues with stage `Queued`. Request table includes:
- `ItemLocation` — Equipment slot ID
- `ItemLevel` — Dropped item's ilvl (for comparison)
- `ItemID` — Item ID
- `Frame` — Reference to display frame
- `CompareIlvl` — Comparison ilvl
- `GoodForPlayer` — Whether item is equippable+appropriate for us
- `IsUpgrade` — Whether item is an ilvl upgrade for us

#### `WGLCache.RemoveRequest(ID)`
Removes a request. If it was the current query, prepares the next one.

#### `PrepareNextQuery()` (local)
Finds next `Queued` request and sends `NotifyInspect()`.

#### `HandleInspections(fromTimer)` (local)
Core processing loop. For each `Sent` request:
1. Updates unit name via GUID (handles party changes)
2. Attempts `GetInventoryItemLink()` for the target slot
3. For rings/trinkets, uses `GetLowestItemLink()` to compare both slots
4. On success: gets their ilvl, calls `SetItemUpgradeStatus()`, adds "Them:" stat to breakdown, fades out loading icon
5. On retry timeout (>2s): retries `NotifyInspect()` if `CanInspect()` returns true
6. On max retries: marks `Failed`, calls `ClearInspectPlayer()`
7. If player not found: removes request

### Events

- **`INSPECT_READY`** — Triggers `HandleInspections(false)` immediately
- **`OnUpdate` timer** — Polls every 0.5s, calls `HandleInspections(true)` with time accumulation

### Debug Frame

When `WGLU.DebugMode` is true, displays a 300x200 overlay at TOPLEFT showing all cache requests with unit name, slot, ilvl, and stage. Debug entries expire after 60 seconds.

---

## ItemsDB.lua (Gear Database - 577 lines)

Defines which items each class and specialization can equip and which are "appropriate" (preferred armor/weapon type).

### Functions

#### `WGLItemsDB.CanEquip(item, class) → boolean`
Returns `true` if the player can equip the item at all. Delegates to `IsAppropriate()` and checks for non-nil return.

#### `WGLItemsDB.IsAppropriate(item, class) → true|false|nil`
Three-value return:
- `true` — Can equip AND is the preferred type for this class/spec
- `false` — Can equip but is NOT the preferred type (e.g., a warrior wearing leather)
- `nil` — Cannot equip at all

**Logic:**
1. Cloaks, necks, rings, trinkets → always `true`
2. Check `ClassAndGearDB.ALL` for universal items (generic weapons/armor, cosmetics)
3. For armor: check `ClassAndGearDB[class].armor[subclass]`
4. For weapons: check `ClassAndGearDB[class][spec][subclass]`

#### `GetSpecByNumber(number) → string`
Reverse lookup: given a spec ID number, returns the spec name string.

### Data: `class_specs`

Maps class names to their specializations with numeric IDs:
- DEATHKNIGHT: Blood (250), Frost (251), Unholy (252)
- WARRIOR: Arms (71), Fury (72), Protection (73)
- PALADIN: Holy (65), Protection (66), Retribution (70)
- HUNTER: BeastMastery (253), Marksmanship (254), Survival (255)
- SHAMAN: Elemental (262), Enhancement (263), Restoration (264)
- DEMONHUNTER: Havoc (577), Vengeance (581)
- ROGUE: Assassination (259), Outlaw (260), Subtlety (261)
- MONK: Brewmaster (268), Windwalker (269), Mistweaver (270)
- DRUID: Balance (102), Feral (103), Guardian (104), Restoration (105)
- PRIEST: Discipline (256), Holy (257), Shadow (258)
- MAGE: Arcane (62), Fire (63), Frost (64)
- WARLOCK: Affliction (256), Demonology (266), Destruction (267)
- EVOKER: Devastation (1467), Preservation (1468), Augmentation (1473)

### Data: `ClassAndGearDB`

Nested table defining gear appropriateness per class and spec. Structure:

```lua
ClassAndGearDB = {
    ALL = { ... },           -- Universal items (Generic weapon/armor, Cosmetic)
    WARRIOR = {
        armor = { ... },     -- Armor subclass → true/false/nil
        Arms = { ... },      -- Weapon subclass → true/false/nil (per spec)
        Fury = { ... },
        Protection = { ... },
    },
    -- ... same pattern for all 13 classes
}
```

---

## OptionsMenu.lua (Settings Panel - 394 lines)

Creates and manages the settings/options UI panel.

### Functions

#### `WhoLootsOptionsEntries.LoadOptions()`
Called on `ADDON_LOADED`. Sets defaults for all nil saved variables, syncs UI controls to saved values, loads whisper/IDontNeed messages, and applies window lock state.

#### `WhoLootsOptionsEntries.OpenOptions()`
Toggles options panel visibility. On show:
1. Determines screen space (right vs left of main frame)
2. Positions panel accordingly (TOPLEFT or TOPRIGHT)
3. Animates slide-in with fade (alpha 0→1, position offset)
4. Plays sound (ID: 170827)

### Options Panel Layout

The panel (220x395) is a child of MainFrame containing a scroll frame with these controls:

1. **Whisper Message** — Preview text + "Set Whisper Message" button (opens editor)
2. **I Don't Need This Message** — Preview text + "Set Message" button (opens editor)
3. **Auto Close** — Checkbox: Close header when no items displayed
4. **Lock Window** — Checkbox: Prevent window dragging
5. **Show Own Loot** — Checkbox: Display items you loot yourself
6. **Hide Unequippable** — Checkbox: Filter items you can't equip
7. **Minimum Item Quality** — Slider (1-4): Poor through Epic
8. **Hide Stat Breakdown** — Checkbox: Hide secondary stat diffs
9. **Hide Item Comparison** — Checkbox: Hide all comparison data
10. **Show During Raid** — Checkbox: Display items in raid instances
11. **Show During LFR** — Checkbox: Display items in LFR
12. **Enable Sound** — Checkbox: Play loot notification sound
13. **Scale** — Slider (0.5-2.0): Window scale
14. **Version** — Displays current version at bottom-left

All settings save immediately to `WhoGotLootsSavedData`.

---

## util.lua (Utilities - 200 lines)

Shared utility functions in the `WGLU` namespace.

### Functions

#### Character/Stat Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `GetPlayerMainStat()` | `→ "Strength"\|"Agility"\|"Intellect"` | Returns highest effective primary stat via `UnitStat("player", index)` |
| `GetItemMainStat(ItemStats, findStat)` | `→ number\|nil` | Extracts a specific main stat value from item stats table |
| `ItemHasMainStat(itemLink, mainStat)` | `→ boolean` | Checks if item has the given main stat (rings/trinkets/necks always return true) |

#### Player Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `GetPlayerGUID(playerName)` | `→ string\|nil` | Searches target, party1-4, raid1-40 for matching player GUID |
| `GetPlayerUnitByGUID(guid)` | `→ string\|nil` | Reverse lookup: GUID → unit ID ("target", "party1", "raid5", etc.) |
| `SplitPlayerName(playerName)` | `→ name, realm` | Splits "Name-Realm" format, defaults to `GetRealmName()` |
| `CheckIfItemIsShown(itemLink, player)` | `→ boolean` | Checks if an item is already displayed in active frames |

#### Math Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `LerpFloat(a, b, t)` | `→ number` | Linear interpolation: `a + (b - a) * t` |
| `LerpBackdropColor(frame, a, b, t)` | | Lerps RGBA backdrop color between two color tables |
| `Clamp(value, min, max)` | `→ number` | Constrains value to [min, max] |

#### Display Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `SimplifyStatName(statName)` | `→ string\|nil` | Shortens stat names: "Versatility"→"Vers", "Mastery"→"Mast", etc. |
| `ItemQualityToText(quality)` | `→ string` | Converts quality number to colored text (0=Poor through 9=WoW Token) |

#### Utility Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `OverrideEvent(frame, event, newHandler)` | | Chains a new script handler after the existing one |
| `DebugPrint(message)` | | Prints to chat if `WGLU.DebugMode` is true |

---

## Localization.lua (i18n - 23 lines)

Minimal localization framework. Currently only defines `enUS` strings for armor types.

### Structure

```lua
WGLL.LOCALIZATION = {
    ["enUS"] = {
        ["cloth"]   = "Cloth",
        ["leather"] = "Leather",
        ["mail"]    = "Mail",
        ["plate"]   = "Plate",
    }
}
```

Stat translations are commented out (reserved for future expansion).
