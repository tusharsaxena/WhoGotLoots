# WhoGotLoots - Event Handling & User Interactions

## WoW Events

### ADDON_LOADED

**Registered by:** `WhoLootData.MainFrame` in `WhoGotLoots.lua`
**Fires when:** Saved variables for the addon are loaded by the WoW client.

**Handler logic:**
1. Initialize `WhoGotLootsSavedData` table (or create empty)
2. Call `WhoLootsOptionsEntries.LoadOptions()` to set defaults and sync UI
3. Handle first boot: show window unlocked; subsequent boots: hide window
4. Set `FirstBoot = false`
5. Apply saved scale to main frame, tooltip, cursor frame, and editor windows
6. Parent all pooled item frames to main frame
7. Restore saved window position (or center on screen)

### CHAT_MSG_LOOT

**Registered by:** `WhoLootData.MainFrame` in `WhoGotLoots.lua`
**Fires when:** Any party/raid member loots an item.

**Event arguments:**
- `args[1]` — Loot message string (contains item link)
- `args[2]` — Player name who looted

**Handler logic:**
1. Validate player name exists (not nil/empty)
2. Extract item links using regex: `|c.-|H.-:.-|h.-|h|r`
3. Process first item link found (warns on multiple)
4. Call `AddLootFrame(player, itemLink)`

### INSPECT_READY

**Registered by:** `CacheHandler` frame in `CacheHandler.lua`
**Fires when:** WoW client receives player inspection data.

**Handler logic:**
Calls `HandleInspections(false)` to immediately process pending inspection requests.

---

## Loot Processing Pipeline

When `CHAT_MSG_LOOT` fires, the item goes through this filtering pipeline in `AddLootFrame()`:

```
Step 1: Player validation
  ├─ Strip realm suffix from player name
  ├─ Check ShowOwnLoot setting (skip own loot if disabled)
  └─ Resolve "target" to party member unit

Step 2: Instance checks
  ├─ If in raid and ShowDuringRaid is false → skip
  └─ If in LFR and ShowDuringLFR is false → skip

Step 3: Frame pool availability
  ├─ If pool full: remove oldest frame
  └─ If still no frames: force-remove up to 3 oldest

Step 4: Item data loading (async via Item:ContinueOnItemLoad)
  ├─ Quality < MinQuality → skip
  ├─ Not Armor or Weapon class → skip
  └─ Is cosmetic item → skip

Step 5: Class/spec filtering
  ├─ WGLItemsDB.CanEquip() — can player equip this?
  ├─ WGLItemsDB.IsAppropriate() — is it the right armor/weapon type?
  ├─ WGLU.ItemHasMainStat() — does it have our primary stat?
  └─ If HideUnequippable and fails any check → skip

Step 6: Slot resolution
  ├─ INVTYPE_NECK → slot 2
  ├─ INVTYPE_TRINKET → lowest of slots 13, 14
  ├─ INVTYPE_FINGER → lowest of slots 11, 12
  └─ Other → C_Transmog.GetSlotForInventoryType()

Step 7: Comparison data
  ├─ Get equipped item link and ilvl
  ├─ Check tooltip for class restrictions (type 21 lines)
  ├─ Check BoP status (C_Item.IsItemBindToAccountUntilEquip)
  ├─ For other players: try GetInventoryItemLink or queue cache
  └─ Calculate ilvl diff, main stat diff, all secondary stat diffs

Step 8: Display
  ├─ Acquire frame from pool
  ├─ Set icon, names, colors
  ├─ Populate stat breakdowns
  ├─ Create cache request if needed
  ├─ Show upgrade glow if applicable
  ├─ Animate drop-in
  └─ Play loot sound
```

---

## Item Comparison Flow

### Comparing to Your Own Equipped Item

```
Get equipped item in same slot
  │
  ├─ Rings: compare both INVSLOT_FINGER1 (11) and FINGER2 (12)
  │   └─ Use the one with lower ilvl
  │
  ├─ Trinkets: compare both INVSLOT_TRINKET1 (13) and TRINKET2 (14)
  │   └─ Use the one with lower ilvl
  │
  └─ Other slots: direct slot lookup via C_Transmog
```

**Unique-equipped detection**: If the dropped item has the same ID as one of your equipped items, it compares to that specific slot and checks if the new one is higher ilvl.

### Stat Comparison

1. **Primary stat**: Get player's main stat (Str/Agi/Int), extract from both items, show diff
2. **Secondary stats**: Compare all of: Haste, Mastery, Versatility, Crit, Avoidance, Leech, Speed, Indestructible, Armor
3. **Display order**: Positive stats first (green, with `+`), then negative (red)

### Stat Keys Used

| WoW API Key | Display Name |
|-------------|-------------|
| `ITEM_MOD_HASTE_RATING_SHORT` | Haste |
| `ITEM_MOD_MASTERY_RATING_SHORT` | Mast |
| `ITEM_MOD_VERSATILITY` | Vers |
| `ITEM_MOD_CRIT_RATING_SHORT` | Crit |
| `ITEM_MOD_CR_AVOIDANCE_SHORT` | Avoid |
| `ITEM_MOD_CR_LIFESTEAL_SHORT` | Leech |
| `ITEM_MOD_CR_SPEED_SHORT` | Speed |
| `ITEM_MOD_CR_STURDINESS_SHORT` | Indest |
| `RESISTANCE0_NAME` | Armor |
| `ITEM_MOD_AGILITY_SHORT` | Agi |
| `ITEM_MOD_STRENGTH_SHORT` | Str |
| `ITEM_MOD_INTELLECT_SHORT` | Int |

---

## Cache Inspection Flow

When another player's equipped item data isn't cached by the WoW client:

```
AddLootFrame() detects missing item data
  │
  ▼
WGLCache.CreateRequest(unitName, request)
  │
  ├─ Get player GUID for stable reference
  ├─ Generate unique request ID
  ├─ If no active query → NotifyInspect() immediately (stage: Sent)
  └─ If query in progress → queue (stage: Queued)

  ▼ (OnUpdate every 0.5s OR INSPECT_READY event)

HandleInspections()
  │
  ├─ Update unit name from GUID (handles party changes)
  ├─ Try GetInventoryItemLink(unitName, slot)
  │
  ├─ SUCCESS:
  │   ├─ Get their item level
  │   ├─ Compare: upgrade for them or downgrade?
  │   ├─ Add "Them: +X ilvl upgrade" or "Them: -X ilvl downgrade" to primary stats
  │   ├─ If upgrade for us AND downgrade for them → show upgrade glow
  │   ├─ Fade out loading icon
  │   └─ Remove request, process next in queue
  │
  ├─ RETRY (>2 seconds elapsed):
  │   ├─ Check CanInspect(unitName)
  │   ├─ If can inspect AND tries < 5 → NotifyInspect() again
  │   └─ If tries >= 5 → mark Failed, ClearInspectPlayer()
  │
  └─ PLAYER NOT FOUND:
      └─ Remove request
```

### Upgrade Glow Logic

The upgrade glow (pulsing white border) is shown when ALL of these are true:
1. The item is an ilvl upgrade for the player (`CompareItemIlvl > CurrentItemIlvl`)
2. The other player's equipped item is higher ilvl than the dropped item (downgrade for them)
3. The item is equippable and appropriate for the player's class/spec
4. No cache request is pending (data must be available)
5. The item is not BoP

This signals: "This player got an item that's bad for them but good for you — ask to trade!"

---

## User Interactions

### Item Frame Mouse Actions

| Input | Context | Action | WoW API |
|-------|---------|--------|---------|
| **Left click** (single) | Own loot | Start 0.4s double-click timer | `GetTime()` |
| **Left click** (double, <0.4s) | Own loot | Equip the item | `C_Item.EquipItemByName(itemLink)` |
| **Shift + Left click** | Any | Insert item link into chat input | `ChatEdit_InsertLink(itemLink)` |
| **Alt + Left click** | Other's loot | Inspect player | `InspectUnit(player)` |
| **Ctrl + Left click** | Other's loot | Open trade window | `InitiateTrade(player)` |
| **Middle click** | Own loot | Send "I don't need" to party/raid/instance | `SendChatMessage(msg, chatType)` |
| **Middle click** | Other's loot | Whisper player with custom message | `SendChatMessage(msg, "WHISPER", nil, name)` |
| **Right click** | Any | Dismiss item frame | `CloseFrame()` |
| **Close button** (X) | Any | Dismiss item frame | `CloseFrame()` |
| **Hover enter** | Any | Show item tooltip, animate background | `GameTooltip:SetHyperlink()` |
| **Hover leave** | Any | Hide tooltip, reverse animation | `GameTooltip:Hide()` |

### Pre-conditions for Actions

| Action | Requirements |
|--------|-------------|
| Inspect | Not in combat (`!InCombatLockdown()`), target is player-controlled, `CanInspect()` returns true |
| Trade | Target is player-controlled, within interact distance (`CheckInteractDistance(player, 2)`) |
| Equip | Must be own loot (`UnitIsUnit('player', player)`) |

### Chat Channel Selection (Middle Click Own Loot)

The "I don't need" message is sent to the most appropriate channel:
1. Instance group (dungeons/raids via LFG) → `INSTANCE_CHAT`
2. Raid → `RAID`
3. Party → `PARTY`
4. None of the above → `SAY`

### Message Template Variables

| Variable | Replacement | Available In |
|----------|-------------|-------------|
| `%n` | Player name (`UnitName(player)`) | Whisper message |
| `%i` | Item link | Whisper message, IDontNeed message |

---

## Slash Commands

Registered as `SLASH_WHOLOOT1` (`/whogotloots`) and `SLASH_WHOLOOT2` (`/wgl`).

### Command Parsing

`SplitCommands(msg)` splits the command string by spaces, but preserves spaces inside WoW color code tags (`|c...|r`) so item links aren't broken.

### Commands

| Command | Action |
|---------|--------|
| `/wgl` (no args) | Toggle main window visibility |
| `/wgl test [itemLink\|itemID]` | Inject a test loot item. Uses current target as the "looter", or player if no target. Accepts both full item links and numeric item IDs. |
| `/wgl debug` | Toggle debug mode (not persisted, resets each session). Shows a movable debug overlay centered on screen with two sections: cache queue and scrollable debug log. |
| `/wgl help` | Print available commands to chat. |

### Debug Mode Output

When debug mode is active, a two-section debug overlay appears (400x450, centered, draggable):

**Top section — Cache Queue**: Real-time inspection request status with unit name, slot, ilvl, and stage (Sent/Queued/Finished). Entries expire after 60 seconds.

**Bottom section — Debug Log** (scrollable): Timestamped messages logged at each stage of loot processing:

| Stage | Output |
|-------|--------|
| **CHAT_MSG_LOOT** | Raw event args (message, player name) |
| **Item loaded** | Item name, quality, ilvl, type/subtype, equip location, classID |
| **Filtering** | Reason for skipping (quality too low, not armor/weapon, cosmetic, own loot, raid/LFR settings, unequippable) |
| **Equip check** | CanEquip, IsAppropriate, HasMainStat, player class and main stat |
| **Slot resolution** | Target slot ID and why (neck special case, ring/trinket lowest comparison, transmog lookup) |
| **Equipped item** | Current item link and ilvl in the resolved slot |
| **BoP status** | Bind-on-pickup detection |
| **Other player** | Whether their gear was cached or queued for async inspection |
| **Stat diffs** | ilvl diff, main stat diff, count of positive/negative secondary stats |
| **Cache request** | Slot, ilvl, itemID, request ID |
| **Frame pool** | Frame acquisition status, active/available counts |

The debug log is capped at 100 entries and auto-scrolls to the latest message.

---

## Tooltip Display

When hovering an item frame:
1. `GameTooltip:SetOwner(fromFrame, "ANCHOR_RIGHT")` — Positions tooltip to the right
2. `GameTooltip:SetHyperlink(fromFrame.Item)` — Displays full item tooltip
3. `GameTooltip:Show()`
4. On leave: `GameTooltip:Hide()`

The addon also reads tooltip data programmatically via `C_TooltipInfo.GetHyperlink()` to detect class restrictions (tooltip line type 21, pattern: `"Class[es]*: (.*)"`) during item processing.

---

## Sound Effects

| Sound ID | Trigger | Context |
|----------|---------|---------|
| 145739 | New item displayed | Loot notification (if `SoundEnabled`) |
| 856 | UI interaction | Close button, checkbox check, save button, dismiss |
| 857 | Checkbox uncheck | Checkbox template OnClick |
| 170827 | Options opened | Options panel and editor windows |

---

## Info Tooltip Content

Shown when hovering the `[?]` info button:

```
Key Bindings
 - Double left click to equip the item (if it's your loot).
 - Shift + left click to link the item in chat.
 - Right click to dismiss the item.
 - Alt + left click to try and inspect the player.
 - Ctrl + left click to open trade with the person.
 - Middle click someone else's item to whisper them.
 - Middle click your own item to announce you don't need it.
Tips
 - Rings and Trinket will compare to your lowest item level one.
```
