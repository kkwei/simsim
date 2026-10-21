# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

SimSim is a macOS menu bar app (`LSUIElement`, no Dock icon) for opening iOS/watchOS/tvOS Simulator app data folders, App Groups, and App Extensions. It is a fork of github.com/dsmelov/simsim. The code is pure Swift 5 (about 1.5k lines) with no third-party dependencies (Cocoa, Foundation, ServiceManagement only). The build is arm64 only (`ARCHS = arm64` at project level) and the deployment target is macOS 26.0. Xcode 27 rejects deployment targets below 12.0.

## Build & Release

- Debug build: `xcodebuild -project SimSim.xcodeproj -scheme SimSim build`
- Unsigned release build (what `release.sh` runs): `xcodebuild clean build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`, output to `build/Release/SimSim.app`
- Release: `./release.sh <version>`, run from the repo root because it uses relative paths. It:
  1. bumps `CFBundleVersion` by 1 and sets `CFBundleShortVersionString` in `SimSim/Info.plist`, the only place the version lives;
  2. builds the app;
  3. builds a DMG through `Release/dmg/build.sh`, which needs the npm tool `appdmg`; DMGs are gitignored;
  4. zips the app to `Release/SimSim_<ver>.zip` and `Release/SimSim_latest.zip`. Both zips are committed.
- There is no test target, no lint, and no CI. To verify a change, build, run the app, and open the menu on a machine with real Simulator data in `~/Library/Developer/CoreSimulator`.

## Architecture

There are two targets: `SimSim`, the main app, and `SimSimHelper`, the login-item helper embedded at `Contents/Library/LoginItems`. Shared schemes `SimSim` and `Release` build only SimSim.app.

- **Entry point:** `main.swift` calls `NSApplicationMain`. `MainMenu.xib` instantiates `AppDelegate`, which creates the `NSStatusItem` and acts as `NSMenuDelegate`. `menuNeedsUpdate` calls `Menus.updateApplicationMenu`, so **the whole menu is rebuilt from the filesystem every time it opens**. Two caches keep this fast:
  - `Tools.identifierCache` maps a container folder UUID to its `MCMMetadataIdentifier`. A UUID's identifier never changes, so entries never go stale.
    - It is main-thread only. `Tools.containerIdentifier` asserts this with `dispatchPrecondition`.
    - `Tools.preloadIdentifierCache` runs once at launch on a background queue. It reads the metadata plists into a local dictionary, then merges that into the cache on the main queue.
  - `Menus.fileIconCache` holds the icons of external apps (Finder, Terminal, etc.). An entry is refreshed when the app bundle's modification date changes.
- **Discovery (`Tools.swift`):** simulator UUIDs come from `~/Library/Preferences/com.apple.iphonesimulator.plist`, using `CurrentDeviceUDID` plus every key under `DevicePreferences`. Each UUID maps to `~/Library/Developer/CoreSimulator/Devices/<UUID>/device.plist`. Simulators are sorted by folder modification date, and only `Constants.maxRecentSimulators` (5) are shown.
- **Containers (`Entities/`):** each kind is read from a folder under the device's `data/Containers/`:
  - `Application` comes from `Data/Application/<uuid>`. The bundle id is read from `.com.apple.mobile_container_manager.metadata.plist` (`MCMMetadataIdentifier`). It is then matched against `Bundle/Application/*` to read the `.app`'s `Info.plist` for name, version, and icon.
  - `AppGroup` comes from `Shared/AppGroup`.
  - `AppExtension` comes from `Data/PluginKitPlugin`.
- **Menus (`Menus.swift`):** builds a submenu for each simulator, then one for each container. `addSubMenus` adds the per-item actions, `addActionForRealm` adds Realm items, and `addServiceItems` adds Start at Login, About, and Quit.
- **Actions (`Actions.swift`):** each action is an `@objc class func` that reads its target path from `sender.representedObject`.
  - Finder, Terminal, iTerm, and Commander One all go through `NSWorkspace.openFile(_:withApplication:)`. The app paths are hard-coded in `Constants.swift`, and `Constants.Actions` strings double as app names.
  - Clicking an app item opens it in Finder by default. Holding Option opens Terminal, and holding Control opens Commander One.
  - Reset deletes the contents of the app's data folders.
- **Realm (`Realm.swift`):** finds `*.realm` files in `Documents`, `Library/Caches`, and the container root, then opens them in `/Applications/Realm Studio.app`.
- **Start at login:**
  - `Settings.swift` calls `SMLoginItemSetEnabled("com.dsmelov.SimSimHelper")` and stores the flag in `UserDefaults` under `SM_LOGIN_ENABLED`.
  - The helper finds SimSim.app by stripping 4 path components from its own bundle path, launches it, and exits.
  - On launch, the main app posts the distributed notification `killLauncher` to stop the helper.

## Gotchas

- The bundle ids `com.dsmelov.SimSim` and `com.dsmelov.SimSimHelper` are string literals in `AppDelegate.swift`, `Settings.swift`, and `SimSimHelper/AppDelegate.swift`. Changing the bundle id means editing all of them plus the pbxproj.
- `SimSim.entitlements` at the repo root declares the sandbox plus read-only access to `~/Library/`. The SimSim target's `CODE_SIGN_ENTITLEMENTS` does not reference it, so the main app probably runs unsandboxed. This has not been verified on a built app. Only SimSimHelper has entitlements set.
- `Constants.githubUrl` (the About link) and the Info.plist copyright still point to the upstream project.
- On macOS 27 and later, AppKit hides menu item images by default. To set a menu item's image, always call `Menus.setImage(_:for:)`, which also sets `preferredImageVisibility = .visible`. Do not assign `item.image` directly.
- App icons are read only from the PNG files listed in `Info.plist` (`CFBundleIcons` / `CFBundleIconFile`). Apps whose icon exists only in `Assets.car` get `empty_icon`.
- Apple apps (bundle id prefixed `com.apple`) are filtered out in `Application.init?`, before any bundle scanning. Keep that check first, because scanning the roughly 150 Apple containers per simulator was the main cost of opening the menu.
- Code style: Allman braces (opening brace on its own line), `//====` and `//----` section banners, and `class func` namespaces (`Tools`, `Menus`, `Actions`, `Constants`) instead of free functions. Follow these in new code.
