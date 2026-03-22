# WhoGotLoots - Data Structures & Saved Variables

## WhoGotLootsSavedData (Persisted)

Global saved variable table, persisted between sessions by the WoW client. Initialized in `OptionsMenu.lua:LoadOptions()`.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `FirstBoot` | boolean | `nil` | Set to `false` after first load. On first boot, window is shown unlocked. |
| `SavedPos` | table | `nil` | Window position: `{ point, relativeTo, relativePoint, xOfs, yOfs }` |
| `SavedSize` | number | `1` | Window scale (0.5 - 2.0) |
| `LockWindow` | boolean | `false` | Prevents window dragging when true |
| `AutoCloseOnEmpty` | boolean | `true` | Auto-hides main window when all item frames expire |
| `HideUnequippable` | boolean | `false` | Filters out items the player can't equip or that lack their main stat |
| `HideStatBreakdown` | boolean | `false` | Hides secondary stat diff text (Haste, Crit, etc.) |
| `HideItemComparison` | boolean | `false` | Hides all comparison data (primary + secondary containers) |
| `ShowOwnLoot` | boolean | `true` | Displays items the player themselves looted |
| `ShowDuringRaid` | boolean | `true` | Displays items while in a raid instance |
| `ShowDuringLFR` | boolean | `false` | Displays items while in LFR difficulty |
| `MinQuality` | number | `3` | Minimum item quality to display (1=Common, 2=Uncommon, 3=Rare, 4=Epic) |
| `SoundEnabled` | boolean | `true` | Plays notification sound (ID: 145739) on new loot |
| `WhisperMessage` | string | `"Greetings, %n!..."` | Template for whispering other players. `%n` = player name, `%i` = item link |
| `IDontNeedMessage` | string | `"I don't need %i..."` | Template for announcing own unneeded loot. `%i` = item link |

---

## WhoLootData (Runtime State)

Global runtime state table, created in `WhoGotLoots.lua`.

| Key | Type | Description |
|-----|------|-------------|
| `ActiveFrames` | table (array) | Ordered list of currently visible item frames. Frames are appended on display and removed on close/expire. |
| `MainFrame` | Frame | The main addon window frame (created by `WGLUIBuilder.CreateMainFrame()`) |
| `OptionsFrame` | Frame | Reference to `WhoLootsOptionsFrame` |

### MainFrame Sub-objects

| Property | Type | Description |
|----------|------|-------------|
| `.cursorFrame` | Frame | Invisible overlay for drag and hover detection |
| `.cursorFrame.isLocked` | boolean | Whether window is locked |
| `.cursorFrame.CursorOver` | boolean | Mouse is currently over the frame |
| `.cursorFrame.HoverAnimDelta` | number | Hover animation progress (0-1) |
| `.cursorFrame.BeingDragged` | boolean | Currently being dragged |
| `.infoBtn` | Button | Info/help button (WGLInfoBtn template) |
| `.infoTooltip` | Frame | Keybindings tooltip panel |
| `.WhisperWindow` | Frame | Whisper message editor popup |
| `.IDontNeedWindow` | Frame | "I Don't Need" message editor popup |

---

## WhoGotLootsFrames (Frame Pool)

Global array of all pre-allocated item frames. Created by `WGL_FrameManager:CreateFrame()` at load time.

```lua
WhoGotLootsFrames = { ItemFrame1, ItemFrame2, ..., ItemFrame10 }
```

### Per-Frame Properties

| Property | Type | Description |
|----------|------|-------------|
| `.Item` | string\|nil | Current item link being displayed |
| `.Player` | string\|nil | Player name/unit who looted the item |
| `.InUse` | boolean | Whether frame is currently displaying an item |
| `.Animating` | boolean | Whether an animation (DropIn/FadeOut) is in progress |
| `.IsUpgrade` | boolean | Whether the displayed item is an upgrade for the player |
| `.Lifetime` | number | Remaining display time in seconds (starts at 60) |
| `.QueuedRequest` | number\|nil | ID of pending `WGLCache` inspection request |
| `.HoverAnimDelta` | number\|nil | Hover animation progress; `nil` when not hovering (also pauses lifetime countdown) |
| `.lastClickTime` | number | `GetTime()` of last left click (for double-click detection) |

### Per-Frame Visual Components

| Property | Type | Description |
|----------|------|-------------|
| `.background` | Frame | 9-slice background (ItemEntryBG) |
| `.UpgradeGlow` | Frame | Pulsing white glow overlay (ItemEntryGlow) |
| `.border` | Frame | 9-slice border (ItemEntryBorder) |
| `.Icon` | Texture | 22x22 item icon |
| `.PlayerText` | FontString | Player name (class-colored) |
| `.PlayerTextFrame` | Frame | Container for PlayerText |
| `.PlayerArrow` | Texture | 8x8 right arrow between player and item name |
| `.ItemText` | FontString | Item name (quality-colored) |
| `.ProgressBar` | StatusBar | Lifetime countdown bar (3px height) |
| `.LoadingIcon` | Frame | Animated spinner (LoadingIcon template) |
| `.Close` | Button | Close button (WGLCloseBtn template) |
| `.statContainer` | table | Contains `.primary` and `.secondary` Frame containers |
| `.statContainer.primary` | Frame | Priority stats (ilvl diff, "You:", "Them:") |
| `.statContainer.secondary` | Frame | Secondary stats (Haste, Crit, Vers diffs, warnings) |
| `.statContainer.*.frames` | table | Array of active stat frame children |
| `.statContainer.*.framePool` | table | Array of recyclable stat frames |

---

## WhoLootFrameData (Animation Config)

Global constants for item frame behavior, defined in `ItemBox.lua`.

| Key | Type | Value | Description |
|-----|------|-------|-------------|
| `HoverAnimTime` | number | `0.3` | Hover color transition duration (seconds) |
| `FrameLifetime` | number | `60` | How long each item frame stays visible (seconds) |
| `HoverColor` | table | `{0.3, 0.3, 0.3, 1}` | Background color when hovered |
| `ExitColor` | table | `{0.1, 0.1, 0.1, 1}` | Background color when not hovered |
| `BorderColor` | table | `{0.5, 0.5, 0.5, 1}` | Border color |
| `ItemNameAnimPosLeft` | table | `{35, 5}` | Item name X position {start, end} |
| `IconAnimPosLeft` | table | `{8, 7}` | Icon X position {start, end} |
| `PlayerNameLeft` | table | `{8, 5}` | Player name X position {start, end} |
| `ItemNameAnimPosTop` | table | `{-5, -5}` | Item name Y position {start, end} |
| `IconAnimPosTop` | table | `{-15, -15}` | Icon Y position {start, end} |
| `PlayerNameTop` | table | `{-5.5, -5.5}` | Player name Y position {start, end} |

---

## WGL_Request_Cache (Inspection Requests)

Table of active/pending inspection requests, keyed by auto-generated ID.

### Request Object

| Key | Type | Description |
|-----|------|-------------|
| `ID` | number | Unique request identifier (based on `GetTime()`) |
| `UnitName` | string | Unit reference ("party1", "raid5", etc.) |
| `PlayerGUID` | string | Player GUID for stable identification across party changes |
| `ItemLocation` | number | Equipment slot ID to inspect |
| `ItemLevel` | number | Dropped item's ilvl (for comparison) |
| `ItemID` | number | Dropped item's ID |
| `Frame` | Frame | Reference to the item display frame to update |
| `CompareIlvl` | number | Our equipped item's ilvl for comparison |
| `OurItemLevel` | number | Our equipped item level |
| `GoodForPlayer` | boolean | Whether item is equippable and appropriate for us |
| `IsUpgrade` | boolean | Whether dropped item is an ilvl upgrade for us |
| `TextString` | string | Pre-formatted priority stats text |
| `QueryStage` | number | Current state (1=Sent, 2=Queued, 3=Finished, 4=Failed) |
| `Time` | number | Accumulated time since last action (for retry timing) |
| `Tries` | number | Number of retry attempts |

---

## ClassAndGearDB (Gear Compatibility)

Nested table defining item appropriateness per class and specialization.

### Three-Value Logic

| Value | Meaning | UI Result |
|-------|---------|-----------|
| `true` | Can equip AND is the preferred type | Normal display |
| `false` | Can equip but NOT preferred (e.g., warrior wearing cloth) | "Undesired Type" warning in orange |
| `nil` | Cannot equip at all | "Can't equip [type]" warning in red, or hidden if `HideUnequippable` |

### Structure

```lua
ClassAndGearDB = {
    ALL = {
        [Enum.ItemClass.Weapon] = {
            [Enum.ItemWeaponSubclass.Generic] = true,
            [Enum.ItemWeaponSubclass.Fishingpole] = true,
        },
        [Enum.ItemClass.Armor] = {
            [Enum.ItemArmorSubclass.Generic] = true,
            [Enum.ItemArmorSubclass.Cosmetic] = true,
        },
    },
    -- Per class:
    WARRIOR = {
        armor = {
            [Enum.ItemArmorSubclass.Shield] = true,
            [Enum.ItemArmorSubclass.Plate] = true,   -- Preferred
            [Enum.ItemArmorSubclass.Mail] = false,    -- Can wear, not preferred
            [Enum.ItemArmorSubclass.Leather] = false,
            [Enum.ItemArmorSubclass.Cloth] = false,
        },
        Arms = {
            [Enum.ItemWeaponSubclass.Axe2H] = true,  -- Appropriate for spec
            [Enum.ItemWeaponSubclass.Axe1H] = false,  -- Can use, not for this spec
            -- nil entries = cannot equip
        },
        Fury = { ... },
        Protection = { ... },
    },
    -- DEATHKNIGHT, PALADIN, HUNTER, SHAMAN, DEMONHUNTER, ROGUE,
    -- MONK, DRUID, PRIEST, MAGE, WARLOCK, EVOKER
}
```

### Armor Type Mapping

| Class | Preferred Armor | Can Also Wear |
|-------|----------------|---------------|
| Death Knight, Warrior, Paladin | Plate | Mail, Leather, Cloth (marked false) |
| Hunter, Shaman, Evoker | Mail | Leather, Cloth (marked false) |
| Demon Hunter, Rogue, Monk, Druid | Leather | Cloth (marked false) |
| Priest, Mage, Warlock | Cloth | — |

---

## class_specs (Spec ID Mapping)

Maps class names to specialization names and their numeric IDs. Used by `GetSpecByNumber()` for reverse lookup.

```lua
class_specs = {
    WARRIOR = { Arms = 71, Fury = 72, Protection = 73 },
    -- ... all 13 classes with all specs
}
```

---

## FrameTextures (9-Slice Config)

Configuration for the 9-slice background rendering system.

| Key | File | Corner Size | Corner Coord | Used For |
|-----|------|-------------|--------------|----------|
| `OptionsWindowBG` | OptionsWindowBG | 12 | 0.25 | Options panel, tooltips, editors |
| `EdgedBorder` | EdgedBorder | 12 | 0.25 | Standard borders |
| `ItemEntryBG` | ItemBG | 10 | 0.2 | Item frame backgrounds |
| `ItemEntryBorder` | EdgedBorder_Sharp | 10 | 0.2 | Item frame borders |
| `SelectionBox` | SelectionBox | 14 | 0.25 | Cursor frame highlight |
| `ItemEntryGlow` | ItemBox_Upgrade | 8 | 0.2 | Upgrade glow effect |
| `BtnBG` | ItemBG | 4 | 0.2 | Button backgrounds |
| `BtnBorder` | EdgedBorder_Sharp_Thick | 4 | 0.2 | Button borders |
| `ItemStatBG` | ItemBG | 2 | 0.2 | Stat frame backgrounds |
| `ItemStatBorder` | EdgedBorder_Sharp_Thick | 2 | 0.2 | Stat frame borders |

All textures are located at `Interface\AddOns\WhoGotLoots\Art\[file]`.
