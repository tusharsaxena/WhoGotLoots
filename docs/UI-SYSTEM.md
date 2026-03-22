# WhoGotLoots - UI & Visual System

## XML Templates

### Font Definitions (`Art/Fonts.xml`)

Seven virtual font objects, loaded before any Lua files:

| Name | Typeface | Size | Color (RGB) | Usage |
|------|----------|------|-------------|-------|
| `WGLFont_Checkbox` | OpenSans-SemiBold | 8pt | 0.8, 0.8, 0.8 (light gray) | Checkbox labels, button text |
| `WGLFont_General` | OpenSans-SemiBold | 6pt | 0.47, 0.46, 0.47 (muted gray) | Descriptions, slider labels |
| `WGLFont_Title` | OpenSans-Bold | 12pt | 0.4, 0.4, 0.4 (dark gray) | Section headers ("Options") |
| `WGLFont_VersNum` | OpenSans-Bold | 6pt | 0.3, 0.3, 0.3 (darker gray) | Version number |
| `WGLFont_Item_StatBottomText` | hk-grotesk Bold | 8pt | 0.66, 0.66, 0.66 (gray) | Stat comparison text |
| `WGLFont_ItemName` | OpenSans-Bold | 8pt | 0.3, 0.3, 0.3 (dark gray) | Player and item names |
| `WGLFont_Tooltip` | hk-grotesk Medium | 8pt | 0.65, 0.65, 0.65 (gray) | Tooltips, tips, char counts |

### Frame Templates (`Art/UIElements.xml`)

#### WGLCheckBoxTemplate (Button)
12x12 custom checkbox with three texture layers:
- **Background**: `checkbox.tga` — base square
- **Border**: `checkbox_hover.tga` — shown on hover
- **Overlay**: `checkbox_check.tga` (`Tick` parentKey) — shown when checked

**Methods defined in OnLoad:**
- `SetChecked(checked)` — Show/hide tick, play sound (856 check / 857 uncheck)
- `GetChecked()` → boolean
- `SetText(text)` — Set label text

**Hit rect**: Extended 112px to the right to cover label text.

#### WGLCloseBtn (Button)
24x24 close button using `CloseBtn.tga`. Default vertex color 0.7 gray, brightens to white on hover.

#### WGLGeneralButton (Button)
70x15 general-purpose button with 9-slice background.

**OnLoad:** Creates `BtnBG` backdrop and `BtnBorder` border using `DrawSlicedBG()`.

**Methods:**
- `SetText(text)` — Set centered label
- `SetEnabled(enabled)` — Toggle enabled/disabled visual state
- `IsEnabled()` → boolean

**States:**
- Enabled: backdrop 0.3 gray, text 0.75 white
- Disabled: backdrop 0.2 gray, text 0.28 dark
- Hover (enabled only): backdrop 0.4 gray

#### WGLInfoBtn (Button)
24x24 info button using `InfoButton.tga`. Same hover color behavior as WGLCloseBtn.

#### WGLOptionsBtn (Button)
24x24 gear icon using `OptionsGear.tga` with rotation animation.

**OnLoad:** Initializes `rotationAngle`, `rampDelta`, `MouseOver`.

**OnEnter:** Starts `OnUpdate` loop that spins the gear:
- Mouse over: ramp speed increases (max 0.5)
- Mouse leave: ramp speed decreases to 0
- Rotation: `angle += elapsed * 3 * -pi * rampDelta`

#### LoadingIcon (Frame)
32x32 animated spinner using `LoadingIcon.tga`.
- **OnShow**: Starts continuous rotation at `-3*pi` radians/sec
- **OnHide**: Stops `OnUpdate` script
- Alpha: 0.8 default

#### WGLSlider (Slider)
160x2 horizontal slider with custom visual thumb.

**Components:**
- Background track: 0.3 gray bar with 0.1 inner border
- `Thumb`: Invisible native thumb (0 alpha) for input handling
- `VirtualThumb`: 20x20 visual thumb (`SliderThumb2.tga`), positioned to follow native thumb
- `KeyLabel`: Value display below thumb (WGLFont_General)
- `KeyLabel2`: Optional second label right of slider (hidden by default)

**OnValueChanged:** Rounds to 1 decimal, updates `KeyLabel`, repositions `VirtualThumb` proportionally.

---

## 9-Slice Background System

The addon implements its own 9-slice texture rendering system for scalable backgrounds and borders.

### How It Works

`WGLUIBuilder.DrawSlicedBG(frame, textureKey, layer, shrink)`:

1. Looks up texture config from `FrameTextures[textureKey]`
2. Creates 9 texture regions on the frame (reuses existing if present)
3. Positions using a build order: corners first (1,3,7,9), then edges (2,4,6,8), then center (5)
4. Sets texture coordinates based on `cornerCoord` value

```
┌───┬─────────────┬───┐
│ 1 │      2      │ 3 │  Corners: fixed size (cornerSize x cornerSize)
├───┼─────────────┼───┤  Edges: stretch in one direction
│   │             │   │  Center: stretches both directions
│ 4 │      5      │ 6 │
│   │             │   │
├───┼─────────────┼───┤
│ 7 │      8      │ 9 │
└───┴─────────────┴───┘
```

**Parameters:**
- `textureKey` — Key into `FrameTextures` table
- `layer` — `"backdrop"` (stored in `frame.backdropTextures`) or `"border"` (in `frame.borderTextures`)
- `shrink` — Pixel inset for corners from frame edges

**Coloring:** `ColorBGSlicedFrame(frame, layer, r, g, b, a)` sets vertex color on all 9 textures in the specified layer.

---

## Main Frame Layout

```
                    ┌─[?]─────────────────────[⚙][✕]─┐
                    │        Main Window (130x50)      │
                    │      (MainWindowBG.tga 250x125)  │
                    └──────────────┬───────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                     │
    ┌─────────┴──────────┐ ┌──────┴──────────┐ ┌───────┴────────┐
    │   Item Frame #1    │ │  Item Frame #2  │ │  Item Frame #3 │
    │ [icon] Player → Item│ │                 │ │                │
    │ [stat breakdown]   │ │                 │ │                │
    │ [progress bar]     │ │                 │ │                │
    └────────────────────┘ └─────────────────┘ └────────────────┘
```

### Main Window Components

- **Background**: `MainWindowBG.tga` (250x125), centered on frame
- **Cursor Frame** (200x40): Invisible overlay at frame level 2
  - Handles dragging (saves to `WhoGotLootsSavedData.SavedPos`)
  - Drives button swoop animations via `OnUpdate`
  - Selection box background (SelectionBox 9-slice, 0.25 alpha)
- **Options Button** (12x12, WGLOptionsBtn): Top-right, swoops in from right on hover
- **Close Button** (12x12, WGLCloseBtn): Below options, follows options button
- **Info Button** (12x12, WGLInfoBtn): Top-left, swoops in from left on hover

### Button Animation

Buttons are hidden off-screen by default. The cursor frame's `OnUpdate`:
1. Tracks `HoverAnimDelta` (0→1 on enter, 1→0 on leave, speed 8x/4x)
2. Applies sine-eased offset: `sin(delta * pi/2) * -60px`
3. Options/Close swoop in from right, Info swoops in from left
4. Buttons fade with the same delta

---

## Item Frame Anatomy

Each item frame (270x48 default, height varies with stat content):

```
┌──────────────────────────────────────────[✕]──┐
│ [icon] PlayerName → [ItemName]                 │
│         ┌─────────┐┌──────────┐┌───────┐      │
│         │You: +5  ││Them: -3  ││Is BoP │      │  ← Primary stats
│         └─────────┘└──────────┘└───────┘      │
│         ┌──────┐┌──────┐┌──────┐┌──────┐      │
│         │+5 Str││-2 Hst││+8 Crt││+3 Vrs│      │  ← Secondary stats
│         └──────┘└──────┘└──────┘└──────┘      │
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░│  ← Progress bar
└───────────────────────────────────────────────┘
```

### Visual Hierarchy

1. **Background** (frame level 0): ItemEntryBG 9-slice, RGBA 0.12/0.1/0.1/0.85
2. **Upgrade Glow** (frame level +1): ItemEntryGlow 9-slice, white, pulsing alpha via `cos(time * 3)`
3. **Border** (frame level +1): ItemEntryBorder 9-slice, 0.5 gray
4. **Icon** (22x22, OVERLAY level 7): Item texture or question mark
5. **Player name** (FontString, OVERLAY): Class-colored via `RAID_CLASS_COLORS`
6. **Arrow** (8x8, OVERLAY): `RightArrow.tga`, 0.6 gray
7. **Item name** (FontString, OVERLAY): Quality-colored via `C_Item.GetItemQualityColor`
8. **Stat containers**: Flow layout of stat frames (see below)
9. **Progress bar** (3px StatusBar): Bottom, 0.5 gray at 0.6 alpha
10. **Loading icon** (LoadingIcon template): Overlays icon while inspection pending
11. **Close button** (12x12, WGLCloseBtn): Top-right corner

### Stat Frame System

Individual stat values are displayed in small framed boxes arranged in a flow layout:

```
┌──────────┐
│ +5 Haste │  height: 12px
└──────────┘  min width: 25px
              padding: 2px between frames
              text padding: 1px inside
```

- **Background**: ItemStatBG 9-slice, 0.1 alpha white
- **Border**: ItemStatBorder 9-slice, 0.3 gray
- **Text colors**: Green (+), Red (-), White (neutral)
- Frames are pooled per container to avoid garbage collection
- Flow wraps to next row when exceeding container width

---

## Animation System

### DropIn Animation
Triggered when a new item appears.
- **Duration**: 0.2 seconds
- **Scale**: 1.5 → 1.0 (linear)
- **Color**: White → ExitColor (0.1 gray) (linear)
- Sets `Animating = true` during animation

### FadeOut Animation
Triggered when lifetime expires.
- **Speed**: alpha decreases by `elapsed * 2` per frame
- On complete: hides frame, marks `InUse = false`, removes from `ActiveFrames`, resorts

### Hover Animation
Triggered on mouse enter/leave of item frames.
- **Duration**: ~0.3 seconds (controlled by `HoverAnimTime`)
- **Easing**: Sine ease-out (`sin(progress * pi/2)`)
- **Color**: Lerps between `ExitColor` and `HoverColor`
- Pauses lifetime countdown while hovering (`HoverAnimDelta ~= nil`)

### Upgrade Glow
Pulsing white overlay for items that are upgrades.
- **Frequency**: `cos(GetTime() * 3)` — approximately 0.5 Hz
- **Alpha range**: 0.0 to 1.0

### Button Swoop
Options/Close/Info buttons animate in on main frame hover.
- **Speed**: 8x on enter, 4x on leave
- **Easing**: Sine ease-out
- **Distance**: 60px

### Options Panel Slide-In
- **Speed**: alpha increases by `elapsed * 4`
- **Offset**: 26px slide from the anchored side
- **Sound**: ID 170827

### Saved Text Animation
"Message saved" confirmation in whisper/IDontNeed editors:
1. Slides from behind save button (60px → -4px) over ~0.2s
2. Holds for 1 second
3. Fades out over ~0.5s via sine easing

---

## Options Panel Layout

220x395 scrollable panel, child of MainFrame.

```
┌─ Options ───────────────────────[✕]─┐
│                                      │
│  Whisper Message                     │
│  "Greetings, %n! I sense..."        │
│  [Set Whisper Message]               │
│                                      │
│  I Don't Need This Message           │
│  "I don't need %i if..."            │
│  [Set Message]                       │
│                                      │
│  ☑ Auto Close                        │
│    Closes the header when empty.     │
│                                      │
│  ☑ Lock Window                       │
│    Locks the window in place.        │
│                                      │
│  ☑ Show Own Loot                     │
│    Show your own loot.               │
│                                      │
│  ☐ Hide Unequippable                 │
│    Hides items that can't equip.     │
│                                      │
│  Minimum Item Quality                │
│  ────────●─────── Neat!              │
│                                      │
│  ☐ Hide Stat Breakdown               │
│  ☐ Hide Item Comparison              │
│  ☑ Show During Raid                  │
│  ☐ Show During LFR                   │
│  ☑ Enable Sound                      │
│                                      │
│  Adjust the scale of the window.     │
│  ──────────●───── 1.0                │
│                                      │
│  v1.5.3                              │
└──────────────────────────────────────┘
```

**Positioning logic**: Panel appears on the right of the main frame if there's room; otherwise on the left.

---

## Message Editor Windows

Both the Whisper and IDontNeed editors share identical structure (360x140):

```
┌─────────────────────────────────[✕]──┐
│         Whisper Player Message        │
│  Use %n for player, %i for item.     │
│  ┌──────────────────────────────┐    │
│  │ Greetings, %n! I sense you  │    │
│  │ hold %i...                   │    │
│  │                   120 chars ─┘    │
│  └──────────────────────────────┘    │
│  [Set to Default]    [Message saved] [Save] │
└──────────────────────────────────────┘
```

**Features:**
- 160 character max
- Character counter turns red below 40 remaining
- Save button only enabled when text differs from saved
- "Message saved" confirmation slides in and fades out
- Set to Default button restores original message

---

## Art Assets

### Backgrounds (9-slice sources)
| File | Size | Used By |
|------|------|---------|
| `MainWindowBG.tga` | 250x125 | Main window background (direct texture, not 9-slice) |
| `OptionsWindowBG.tga` | — | Options panel, tooltips, editor backgrounds |
| `ItemBG.tga` | — | Item frames, stat frames, buttons |
| `ItemBox_Upgrade.tga` | — | Upgrade glow effect |
| `SelectionBox.tga` | — | Cursor frame highlight |

### Borders (9-slice sources)
| File | Used By |
|------|---------|
| `EdgedBorder.tga` | Standard borders (options, tooltips) |
| `EdgedBorder_Sharp.tga` | Item frame borders |
| `EdgedBorder_Sharp_Thick.tga` | Button and stat frame borders |

### Icons and Controls
| File | Size | Used By |
|------|------|---------|
| `CloseBtn.tga` | 24x24 | Close buttons |
| `InfoButton.tga` | 24x24 | Info/help button |
| `OptionsGear.tga` | 24x24 | Settings gear (rotates on hover) |
| `RightArrow.tga` | 8x8 | Player → Item separator |
| `SliderThumb2.tga` | 20x20 | Slider handle |
| `LoadingIcon.tga` | 32x32 | Animated loading spinner |
| `checkbox.tga` | 12x12 | Checkbox base |
| `checkbox_check.tga` | 12x12 | Checkbox tick mark |
| `checkbox_hover.tga` | 12x12 | Checkbox hover state |

### Custom Fonts
| File | Style | Usage |
|------|-------|-------|
| `OpenSans-Bold.ttf` | Bold | Titles, item names, version |
| `OpenSans-SemiBold.ttf` | SemiBold | Checkboxes, descriptions |
| `OpenSans-BoldItalic.ttf` | Bold Italic | (Available, not currently assigned) |
| `OpenSans-SemiBoldItalic.ttf` | SemiBold Italic | (Available, not currently assigned) |
| `hk-grotesk.bold.ttf` | Bold | Stat text |
| `hk-grotesk.medium.ttf` | Medium | Tooltips |
