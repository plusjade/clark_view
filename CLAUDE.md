# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

SwiftUI iOS app scaffold (Xcode "App" template). Target `clark_view`, bundle id `plusjade.clark-view`, deployment target iOS 26.5, Swift 5.0. No third-party dependencies.

Three targets: `clark_view` (app), `clark_viewTests` (unit tests), `clark_viewUITests` (UI tests).

## Build & test

Build and run via Xcode, or from the CLI:

```
xcodebuild -project clark_view.xcodeproj -scheme clark_view build
xcodebuild -project clark_view.xcodeproj -scheme clark_view test
```

Unit tests (`clark_viewTests`) use the **Swift Testing** framework (`import Testing`, `@Test`, `#expect`) — not XCTest. UI tests (`clark_viewUITests`) use XCTest (`XCUIApplication`) as usual.

## Linting

SwiftLint is configured (`.swiftlint.yml`). Run `swiftlint lint` from the project root. `type_name` is disabled project-wide since the project name contains an underscore, which every top-level type inherits.
