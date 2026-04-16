# Spotique iOS

iOS app built with SwiftUI and SwiftData, targeting iOS 26.1.

## Getting Started

Open `Spotique.xcodeproj` in Xcode, select a simulator, and run.

## Build & Test

```bash
# Build
xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build

# Run tests
xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test
```
