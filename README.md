# SwiftTrigger

A lightweight macOS automation app that fills the gap left by Apple's Shortcuts — it brings the **Automation** tab (the kind iOS has) to the Mac. SwiftTrigger listens for system events and automatically runs an action when a condition is met. Built with pure Swift + SwiftUI, no Electron, no Flutter, no bloat.

> 中文介绍请见 [README_ZH.md](README_ZH.md)

---

## Why

macOS Shortcuts has no "Automation" tab — it can't react to battery level, time of day, Wi-Fi changes, or app launches the way iOS can. SwiftTrigger watches those system events and fires an action (system notification or spoken announcement) when your rules match. Rules are configured in a GUI and persisted to disk.

---

## Features

- **4 trigger types**
  - **Battery** — below / reaches a percentage, charger plugged in / unplugged
  - **Time** — every day at a given `HH:mm`
  - **Wi-Fi** — connect to / disconnect from a given SSID
  - **App** — a given app (by bundle id) launches / quits
- **2 action types** — system notification, or spoken announcement via `/usr/bin/say` (optional voice)
- **Multiple rules** — create, enable/disable, and delete any number of rules in the UI
- **Persistent** — rules are saved as JSON and restored on restart
- **Event-driven** — IOKit / NSWorkspace / NWPathMonitor callbacks, near-zero CPU when idle (only time triggers poll)
- **Launch at Login** — registered via `SMAppService` on macOS 13+
- **Runs in the background** — closing the window does not quit the app

---

## Requirements

| Item | Minimum |
|------|---------|
| macOS | 13.0 Ventura |
| Xcode / Swift | Swift 5.9+ (`swift build`) |
| Architecture | Apple Silicon & Intel (arm64 / x86_64) |

---

## Installation

### Build from source

```bash
git clone https://github.com/istaru/swift_trigger.git
cd swift_trigger
bash build_app.sh
cp -r build/SwiftTrigger.app /Applications/
open /Applications/SwiftTrigger.app
```

### Manual build steps

```bash
swift build -c release
# The compiled binary is at .build/release/SwiftTrigger
```

On first launch the app requests notification permission. Grant it so notification actions can fire.

---

## Project Structure

```
swift_trigger/
├── Sources/SwiftTrigger/
│   ├── SwiftTriggerApp.swift        # @main entry, AppDelegate (permissions / engine / launch-at-login)
│   ├── ContentView.swift            # Main shell (NavigationSplitView)
│   ├── AutomationListView.swift     # Rule list page
│   ├── AddAutomationView.swift      # New-rule page
│   ├── AutomationStore.swift        # Rule persistence (JSON, ObservableObject)
│   ├── AutomationEngine.swift       # Central scheduler: monitor callbacks → match/dedupe → fire
│   ├── NotificationManager.swift    # Notification permission & delivery
│   ├── Models/
│   │   └── Automation.swift         # Automation model + 4 TriggerConfig types (Codable)
│   └── Monitors/
│       ├── BatteryMonitor.swift     # IOKit power events
│       ├── TimeMonitor.swift        # Timer polling
│       ├── WiFiMonitor.swift        # NWPathMonitor + CoreWLAN
│       └── AppMonitor.swift         # NSWorkspace app launch / quit
├── Package.swift
├── Info.plist
├── SwiftTrigger.entitlements
├── build_app.sh                     # Release build + .app assembly script
└── CLAUDE.md                        # Full technical spec (AI-readable)
```

---

## How It Works

### Trigger monitors (`Monitors/`)
Each monitor is a singleton that reports events to `AutomationEngine` via a closure:

- **BatteryMonitor** — IOKit `IOPSNotificationCreateRunLoopSource`; the system pushes a callback whenever power info changes, so CPU cost is effectively zero.
- **AppMonitor** — `NSWorkspace` `didLaunchApplicationNotification` / `didTerminateApplicationNotification`.
- **WiFiMonitor** — `NWPathMonitor` watches path changes, then reads the current SSID via CoreWLAN's `CWWiFiClient`; only fires when the SSID actually changes.
- **TimeMonitor** — a `Timer` polls the current `HH:mm` every 30 seconds (the one polling exception).

### Scheduling engine (`AutomationEngine`)
A singleton. On `start()` it wires up the four monitor callbacks. When an event arrives it walks the enabled, type-matching rules in `AutomationStore`, evaluates the condition, applies de-duplication, and `fire`s on a hit. Runtime logs go to `~/Library/Logs/SwiftTrigger.log`.

### De-duplication
- **Battery "below"** — fires once per discharge cycle; reset when the charger is plugged in.
- **Battery "reaches"** — fires once when crossing from below the threshold to at-or-above it.
- **Charger plugged / unplugged** — fires on the power-state switch; the opposite dedupe set is cleared on the reverse switch.
- **Time** — keyed by `date + time`, so each rule fires at most once per day.

### Actions
If a rule has `speechText`, SwiftTrigger speaks it via `/usr/bin/say` (with an optional `-v <voice>`); otherwise it posts a local notification through `UserNotifications`.

---

## Where data lives

| What | Path |
|------|------|
| Rules | `~/Library/Application Support/SwiftTrigger/automations.json` |
| Logs | `~/Library/Logs/SwiftTrigger.log` |

---

## Building & Signing

`build_app.sh` performs an ad-hoc code signature (`codesign --sign -`) sufficient for local use. For distribution, replace it with a Developer ID signature:

```bash
codesign --force --deep --sign "Developer ID Application: Your Name (TEAMID)" build/SwiftTrigger.app
```

---

## Roadmap

- Implement the other two tabs (Shortcuts / Gallery) to mirror the iPhone Shortcuts layout
- More triggers (screen lock/unlock, Bluetooth device, external display, …)
- More actions (run a Shortcut, run a script, HTTP request, …)
- Compound conditions (multiple triggers / conditional logic)

---

## License

MIT — do whatever you want, no warranty.
