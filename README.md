# PlaceWatch

**Roblox Studio Plugin** that automatically detects and visualizes differences between place snapshots.

## Features

- **Snapshot** - Capture the current state of your place's instance tree
- **Compare** - Detect additions, removals, and modifications since the last snapshot
- **Click to Select** - Click any change entry to select the instance in Explorer
- **Filters** - Filter by change type: All / +Added / -Removed / ~Modified
- **Auto Snapshot** - Toggle automatic snapshots on/off
- **Persistent Storage** - Snapshots are saved between sessions

## Tracked Properties

| Class | Properties |
| ----- | ---------- |
| BasePart | Position, Size, Orientation, Color, Material, Anchored, Transparency, CanCollide, CastShadow, Reflectance, Shape |
| Model | PrimaryPart |
| GUI (TextLabel, etc.) | Text, TextColor3, BackgroundColor3, TextSize, Font, Visible |
| Image (ImageLabel, etc.) | Image, ImageColor3, BackgroundColor3, Visible |
| Lights | Brightness, Color, Range, Angle, Face |
| Sound | SoundId, Volume, PlaybackSpeed, Looped |
| ParticleEmitter | Texture, Rate, Lifetime, Speed, Color |
| Decal / Texture | Texture, Face, Transparency |

## Scanned Services

Workspace, ReplicatedStorage, ServerStorage, ServerScriptService, StarterGui, StarterPack, StarterPlayer, Lighting, SoundService

## Installation

### Quick Install (Single File)

1. Download `PlaceWatch.lua`
2. Place it in your Roblox Studio plugins folder:
   - Windows: `%LOCALAPPDATA%\Roblox\Plugins\`
   - Mac: `~/Documents/Roblox/Plugins/`
3. Restart Roblox Studio

### From Source (Rojo)

1. Clone this repo
2. Build with Rojo: `rojo build -o PlaceWatch.rbxm`
3. Place the output in your plugins folder

## Usage

1. Click **PlaceWatch** in the toolbar to open the panel
2. Click **Snapshot** to save the current state
3. Make changes to your place
4. Click **Compare** to see what changed
5. Click any entry to select it in Explorer

## File Structure

```text
placewatch-plugin/
├── PlaceWatch.lua         -- Single-file version (ready to install)
├── src/
│   ├── init.server.lua    -- Entry point (modular version)
│   ├── Config.lua         -- Configuration
│   ├── Snapshot.lua       -- Instance tree capture
│   ├── DiffEngine.lua     -- Diff computation
│   └── UI.lua             -- Plugin UI
├── design.md              -- Technical design document
└── README.md
```

## Contributors

- [@k153636](https://github.com/k153636)
- [Claude](https://claude.ai) (Anthropic)

## License

MIT
