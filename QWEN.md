# DrumPad Project Context

## Project Overview

DrumPad is an iOS application built using The Composable Architecture (TCA), featuring a modular architecture. It's a Swift project that follows modern iOS development practices with a focus on composability and testability.

### Key Technologies & Frameworks
- **SwiftUI**: For declarative user interface building
- **The Composable Architecture (TCA)**: For state management and application architecture
- **Swift 6.0**: Latest Swift version features
- **iOS 17.0+**: Deployment target
- **Xcode 15.0+**: Development environment

### Architecture
The project follows a modular architecture with the following structure:
- **DrumPad/**: Main application code
- **Features/**: Swift Package containing reusable modules
  - **AppFeature/**: Main application feature with store and view
  - **AppSchemas/**: Shared data models and schemas
  - **UIComponents/**: Reusable UI components

## Project Structure
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

## Building and Running

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 SDK or later

### Setup Instructions
1. Open the workspace:
   ```bash
   cd /Users/thanhhaikhong/Documents/drum-pad
   open DrumPad.xcworkspace
   ```

2. Add the Features package to your app target:
   - Select `DrumPad` project in the navigator
   - Select `DrumPad` target
   - Go to "General" tab
   - Scroll to "Frameworks, Libraries, and Embedded Content"
   - Click the `+` button
   - Click "Add Other" → "Add Package Dependency"
   - Navigate to `Features` folder and click "Add Package"
   - Select `AppFeature` and click "Add"

3. Build and run (⌘R)

### Alternative Package Integration
The project uses Tuist for project generation. The `project.yml` file defines the project structure and can be used with Tuist commands to regenerate the Xcode project if needed.

### Build Verification
⚠️ IMPORTANT: ALWAYS use the `swift-build` script (with dash) to build the project or any target, NOT the default `swift build` command.
The script is located at `/Users/thanhhaikhong/.config/bin/swift-build` and provides enhanced building capabilities for this project.
Use the `swift-build` script to verify builds for specific targets:
- `swift-build --product AudioEngineClient` - Build the audio engine client interface
- `swift-build --product AudioEngineClientLive` - Build the live implementation
- `swift-build --product UIComponents` - Build UI components
- `swift-build --product AppFeature` - Build the main application feature
- `swift-build` - Build the entire project

Note: The script automatically detects the project type (Xcode or SPM) and applies appropriate build settings.

## Development Conventions

### Architecture Patterns
- **The Composable Architecture (TCA)**: All state management follows TCA patterns with reducers, stores, and actions
- **Modular Design**: Features are separated into distinct modules within the Features package
- **Observable State**: Uses TCA's `@ObservableState` for state management

### Code Organization
- **AppFeature Module**: Contains the main application reducer and view
- **AppSchemas Module**: Houses shared data models and schemas
- **UIComponents Module**: Contains reusable UI components
- **SwiftUI Views**: Follow modern SwiftUI patterns with clear separation of concerns

### Dependency Client Structure
When creating dependency clients like `@Features/Sources/AudioEngineClient/**`, follow this pattern:

#### 1. Interface.swift
- Defines the dependency client struct with the `@DependencyClient` annotation
- Contains function properties that define the interface
- Includes documentation with usage examples and testing guidance

#### 2. Models.swift
- Contains data models (structs) used by the dependency
- Defines error types as nested enums in the client extension
- Includes any shared state structures

#### 3. Mocks.swift
- Provides mock implementations for testing (`.noop`, `.failing`, `.happy`)
- Implements the `TestDependencyKey` protocol
- Defines constants for mock behavior (delays, etc.)

#### 4. Live Implementation (in separate module like AudioEngineClientLive)
- Contains the actual implementation in `Live.swift`
- Uses an actor for thread-safe operations in `Actor.swift`
- Implements the `DependencyKey` protocol to provide the live value

### Testing Approach
While no test files are visible in the current structure, TCA promotes testability through:
- Pure reducer functions that can be easily tested
- Separation of business logic from view logic
- Composable architecture that allows isolated testing of components

## Key Files and Components

### Application Entry Points
- `DrumPadApp.swift`: Main application entry point using SwiftUI's @main attribute
- `AppDelegate.swift` and `SceneDelegate.swift`: Standard iOS lifecycle management
- `AppStore.swift`: TCA reducer defining application state and actions
- `AppView.swift`: Main SwiftUI view connected to the TCA store

### Dependencies
- **swift-composable-architecture**: The core TCA framework from Point-Free
- Defined in `Package.swift` with branch: "main" for latest features

## Future Development Notes
- The project is set up for drum pad functionality (based on the name) but currently shows "Hello, TCA!" as a placeholder
- UIComponents and AppSchemas modules are initialized but empty, suggesting room for expansion
- The architecture is ready for complex state management and feature composition