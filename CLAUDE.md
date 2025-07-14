# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Digital Art Display is a tvOS (Apple TV) application built with SwiftUI. This is a native Apple platform project that requires Xcode for development.

## Development Commands

### Building
```bash
# Debug build
xcodebuild -project "Digital Art Display.xcodeproj" -scheme "Digital Art Display" -configuration Debug

# Release build
xcodebuild -project "Digital Art Display.xcodeproj" -scheme "Digital Art Display" -configuration Release

# Clean build
xcodebuild -project "Digital Art Display.xcodeproj" clean
```

### Testing
```bash
# Run all tests
xcodebuild test -project "Digital Art Display.xcodeproj" -scheme "Digital Art Display"

# Run tests with specific simulator
xcodebuild test -project "Digital Art Display.xcodeproj" -scheme "Digital Art Display" -destination 'platform=tvOS Simulator,name=Apple TV'
```

### Running in Simulator
```bash
# Open project in Xcode (recommended for development)
open "Digital Art Display.xcodeproj"
```

## Architecture

This is a SwiftUI-based tvOS application with the following structure:

- **Entry Point**: `Digital_Art_DisplayApp.swift` - Contains the `@main` app entry point using SwiftUI App lifecycle
- **Main View**: `ContentView.swift` - The root view of the application
- **UI Framework**: SwiftUI (declarative UI framework)
- **Target Platform**: tvOS 18.2+ (Apple TV)
- **Test Frameworks**: 
  - Swift Testing (new Apple framework) for unit tests
  - XCTest for UI tests

The project follows Apple's standard SwiftUI app structure with:
- App lifecycle managed by SwiftUI
- Views defined declaratively
- Preview support for rapid UI development
- Native tvOS SDK integration

## Key Technical Details

- **Bundle ID**: `pimalai-labs.Digital-Art-Display`
- **Development Team**: `ZNF8XM6L4D`
- **Swift Version**: 5.0
- **Xcode Version**: 16.2
- **No external dependencies** - Pure native Apple SDK project