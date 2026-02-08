# DrumPad

A TCA (The Composable Architecture) project with modular architecture.

## Structure

```
drum-pad/
├── DrumPad.xcworkspace/
├── DrumPad/
│   ├── DrumPad/
│   │   ├── App/
│   │   │   ├── AppDelegate.swift
│   │   │   ├── SceneDelegate.swift
│   │   │   └── DrumPadApp.swift
│   │   └── Resources/
│   │       ├── Info.plist
│   │       └── Assets.xcassets/
│   └── DrumPad.xcodeproj/
└── Features/
    ├── Package.swift
    └── Sources/
        ├── AppFeature/
        ├── AppSchemas/
        └── UIComponents/
```

## Getting Started

1. Open the workspace:
   ```bash
   cd /Users/thanhhaikhong/Documents/./drum-pad
   open DrumPad.xcworkspace
   ```

2. Add the Features package to your app target:
   - Select `DrumPad` project in the navigator
   - Select `DrumPad` target
   - Go to "General" tab
   - Scroll to "Frameworks, Libraries, and Embedded Content"
   - You'll see `Foundation.framework` (iOS system framework, can be removed if desired)
   - Click the `+` button
   - Click "Add Other" → "Add Package Dependency"
   - Navigate to `Features` folder and click "Add Package"
   - Select `AppFeature` and click "Add"

3. Build and run (⌘R)
