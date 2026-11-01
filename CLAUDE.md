# CLAUDE.md

> **What:** Keeps the workstation awake by simulating small input events.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

This is a macOS Cocoa app built with Xcode. No external dependencies or package managers.

```bash
xcodebuild -project Jiggler.xcodeproj -scheme Jiggler -configuration Debug build
xcodebuild -project Jiggler.xcodeproj -scheme Jiggler -configuration Release build
```

There are no tests in this project.

## Architecture

Jiggler is a macOS menu bar utility (LSUIElement = true) written in Objective-C with manual retain/release (ARC is disabled). It keeps a Mac awake by periodically moving the mouse cursor or simulating user activity.

### Core Classes

- **AppDelegate** - Main controller. Runs a 0.25s repeating timer (`periodicJiggleStatusCheck:`) that evaluates jiggle conditions, manages the status bar item (with color tinting for state), handles timed quit countdown, and performs the actual mouse jiggling via CGEvent APIs.
- **PrefsController** - Singleton managing all user preferences via NSUserDefaults. Controls jiggle timing, style, conditions, and inhibitors. Accessible via `[PrefsController sharedPrefsController]`.
- **JigglerOverlayWindow** - Displays a floating overlay icon when jiggling is active.
- **TimedQuitController** - Modal panel for setting an auto-quit timer.

### Stick Software Library (SS* classes)

Reusable code extracted from other Stick Software projects:
- **CocoaExtra** - Utility functions: alert panels (`SSRunAlertPanel` etc.), battery detection (`RunningOnBatteryOnly`), screen lock detection (`ScreenIsLocked`), `StSRandomIntBetween`, NSScreen/NSWindow categories.
- **SSCPU** - CPU usage monitoring (`+[SSCPU busyIndex]`).
- **SSPanels** - About panel with clickable URLs (`+[NSWindow runStandardSSAboutPanelWithURLDictionary:hideOnDeactivate:]`).
- **SSVersionChecker** - Checks sticksoftware.com for updates.
- **SSProgressPanel** - Reusable progress indicator panel.

### Jiggle Styles

Three modes controlled by `jiggleStyle` preference (0, 1, 2):
- **Standard (0)** - Moves cursor randomly within configurable distance, 35 moves scheduled 10ms apart.
- **Zen (1)** - Declares user activity via IOPMAssertion without moving the mouse.
- **Click (2)** - Posts mouse down/up events at current cursor position.

All styles call `declareUserActivity` which uses `IOPMAssertionCreateWithName` (and deprecated `UpdateSystemActivity` as fallback) to reset the system idle timer.

### Jiggle Conditions

Jiggling requires the master switch ON, plus optionally any of: CPU usage above threshold, removable writable disk mounted, specific app running, or iTunes playing. Jiggling is inhibited by: battery-only power, screen locked, or specific front app running.

## Key Details

- **Deployment target**: macOS 10.15
- **Memory management**: Manual retain/release (no ARC)
- **Bundle ID**: `com.stick.app.jiggler`
- **Frameworks**: Cocoa, ApplicationServices (CGEvent), IOKit (power management)
- **UI**: XIB-based (MainMenu.xib, Preferences.xib, TimedQuit.xib), localized via .strings files
- **Coordinate systems**: Mouse jiggling converts between AppKit (origin bottom-left) and CG (origin top-left) coordinates
