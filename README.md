# Who Got Loots

A World of Warcraft addon that tracks and displays looted items in your party or raid, showing real-time stat comparisons and upgrade detection so you can quickly coordinate loot sharing.

## Features

- **Real-time loot tracking** — Automatically displays items looted by party and raid members
- **Stat comparison** — Shows item level diff, primary stat, and secondary stat breakdowns against your equipped gear
- **Upgrade detection** — Highlights items that are an upgrade for you but a downgrade for the looter (trade opportunity)
- **Smart filtering** — Filter by item quality, equippability, class/spec appropriateness, and main stat
- **One-click interactions**:
  - Double-click to equip your own loot
  - Ctrl+click to open trade
  - Middle-click to whisper or announce you don't need an item
  - Shift+click to link in chat
  - Alt+click to inspect the player
- **Customizable messages** — Set your own whisper and "I don't need this" message templates
- **Async gear inspection** — Automatically inspects other players' gear for accurate comparisons
- **Configurable** — 13 settings including quality threshold, raid/LFR visibility, sound, window scale, and more

## Installation

1. Download or clone this repository
2. Copy the `WhoGotLoots` folder into your WoW addons directory:
   ```
   World of Warcraft/_retail_/Interface/AddOns/WhoGotLoots/
   ```
3. Restart WoW or reload the UI (`/reload`)

## Usage

| Command | Action |
|---------|--------|
| `/wgl` or `/whogotloots` | Toggle the main window |
| `/wgl test [itemLink]` | Inject a test loot item |
| `/wgl debug` | Toggle debug mode (shows debug overlay with cache queue and processing log) |
| `/wgl help` | Show available commands |

Hover over the **[?]** button on the main window for a full list of keybindings.

## Settings

Open the settings panel by clicking the gear icon on the main window. Options include:

- Custom whisper and "I don't need" messages (`%n` for player name, `%i` for item link)
- Auto-close when no items are displayed
- Lock window position
- Show/hide own loot
- Hide unequippable items
- Minimum item quality (Common through Epic)
- Show/hide stat breakdowns and item comparisons
- Raid and LFR visibility
- Sound toggle
- Window scale (0.5x - 2.0x)

## Compatibility

- **Dragonflight** (Interface 110002)
- **The War Within** (Interface 120000)
- No external library dependencies

## License

[GNU General Public License v3](LICENSE)
