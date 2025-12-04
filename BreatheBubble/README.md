# Breathe Bubble

A beautiful, floating breathing exercise app for macOS. Features a 4-6-8 breathing technique with a stunning shader-based bubble visualization.

## Features

- **Floating Timer Bubble**: A small, draggable bubble that counts down to your next breathing session
- **4-6-8 Breathing**: Inhale (4s) → Hold (6s) → Exhale (8s) with optional Hold Empty (4s)
- **Metal Shader Visualization**: Beautiful, organic bubble animation with glow effects
- **Ambient Sounds**: Calming background audio during sessions
- **Customizable**: Adjust timer intervals, cycle count, and more

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later

## Building

1. Open `BreatheBubble.xcodeproj` in Xcode
2. Select your signing team in the project settings
3. Build and run (⌘R)

Or build from command line:

```bash
cd BreatheBubble
xcodebuild -project BreatheBubble.xcodeproj -scheme BreatheBubble -configuration Release build
```

## Project Structure

```
BreatheBubble/
├── App/
│   ├── BreatheBubbleApp.swift     # App entry point
│   ├── AppDelegate.swift          # Window management
│   └── BreatheBubble.entitlements # Sandbox permissions
├── Views/
│   ├── FloatingBubbleView.swift   # Small timer bubble
│   ├── BreathingPanelView.swift   # Main breathing UI
│   └── SettingsView.swift         # Settings panel
├── Shaders/
│   ├── BubbleShader.metal         # Metal shader (converted from WebGL)
│   └── MetalBubbleView.swift      # SwiftUI Metal wrapper
├── Models/
│   ├── BreathingSession.swift     # Breathing state machine
│   ├── TimerManager.swift         # Countdown timer
│   └── AppSettings.swift          # User preferences
├── Audio/
│   └── AudioManager.swift         # MP3 playback
├── Utilities/
│   └── WindowManager.swift        # Floating window management
└── Resources/
    └── Assets.xcassets/           # App icons and colors
```

## Adding Sound Files

Place your MP3 files in the project and ensure they match the filenames in `AppSettings.swift`:
- `ocean.mp3`
- `rain.mp3`
- `forest.mp3`
- `stream.mp3`

## Usage

1. The app launches with a small floating bubble in the bottom-right corner
2. The bubble shows a countdown timer (default: 30 minutes)
3. When the timer completes, the breathing panel opens automatically
4. Click the bubble anytime to manually start a breathing session
5. Right-click the bubble for more options (reset timer, change interval, quit)

## License

MIT License - Feel free to use and modify!

