# AutoMacro+

A native macOS macro automation app built with SwiftUI. Create, record, and replay sequences of mouse clicks and keyboard presses with precise timing control.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

<img src="Icon.jpeg" width="128" height="128" alt="AutoMacro+ Icon">
*(Icon source: [Pinterest](https://de.pinterest.com/pin/949063321491668351/))*

## Features

- **Step-based Macro Builder** — Add mouse clicks (left/right/middle) and keyboard presses as individual steps
- **Target App Mode** — Pick a running app and key presses go only to it, even while it's in the background or fullscreen on another desktop
- **Macro Recording** — Record your actual clicks and keypresses with real timing, then replay them
- **Configurable Global Hotkeys** — Start/stop and record macros from any app using customizable keyboard shortcuts
- **Precise Timing** — Set delay (in milliseconds) between each step, or use recorded real-time delays
- **Loop Control** — Run macros infinitely or a specific number of times
- **Step Reordering** — Drag steps to reorder them, or use the up/down arrow buttons
- **Fixed/Dynamic Click Positions** — Click at the current cursor position or at fixed screen coordinates
- **Modifier Key Support** — Combine keys with ⌃ Control, ⌥ Option, ⇧ Shift, ⌘ Command
- **Sequence Persistence** — Save and load named macro sequences
- **Dark Mode UI** — Sleek glassmorphism design with smooth animations

## Installation

[![Download AutoMacro](https://img.shields.io/badge/Download-AutoMacro.dmg-blue?style=for-the-badge&logo=apple)](https://github.com/SenorAdel/AutoMacro/releases/latest)

1. Download the latest `AutoMacro.dmg` from the **[Releases](../../releases)** page (or click the button above).
2. Open the downloaded `.dmg` file.
3. Drag **AutoMacro+** into your `Applications` folder.
4. Launch the app from your Applications folder.

> [!IMPORTANT]
> **AutoMacro will not work until you grant Accessibility permission in System Settings.**
> Clicks and keystrokes will silently do nothing without it. See the steps below.

### First Launch (Unsigned App)

The app is ad-hoc signed rather than notarized, so macOS blocks it on first open.
Instead of double-clicking, **right-click `AutoMacro.app` → Open**, then confirm **Open**
in the dialog. You only need to do this once.

### Accessibility Permission — Required

macOS requires Accessibility access for any app that simulates mouse clicks and keystrokes.
Without it AutoMacro can record your input but cannot replay it.

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the `+` button, navigate to `/Applications`, and select `AutoMacro.app`
3. Make sure the toggle next to it is switched **ON**
4. If AutoMacro was already running, **quit and reopen it** so it picks up the new permission

The app shows an orange banner while the permission is missing, and the hotkey badge
reads **In-App** instead of **Global**. Once granted, the badge flips to **Global**.

> [!NOTE]
> If you replace the app with a newer build, macOS may remember the *old* copy.
> Remove the stale entry with the `−` button and re-add the new `AutoMacro.app`.

## Usage

### Default Hotkeys

| Shortcut | Action |
|----------|--------|
| `⌃⌥S` (Ctrl+Opt+S) | Start / Stop macro playback |
| `⌃⌥R` (Ctrl+Opt+R) | Start / Stop macro recording |

*Both hotkeys are fully configurable in the app's settings panel and work globally across macOS.*

### Creating a Macro

**Manual Method:**
1. Click **"Add Step"** to manually add mouse clicks, key presses, or delays.
2. Set the delay (in ms) before each step executes.
3. Reorder steps with the ▲/▼ arrows if needed.
4. Press `⌃⌥S` or click **"Start Macro"** to run.

**Recording Method:**
1. Press `⌃⌥R` or click the red **Record** button.
2. Perform your clicks and keypresses — they are captured automatically with real timing.
3. Press `⌃⌥R` again to stop recording.
4. Edit or reorder steps as needed, then play back with `⌃⌥S`.

## Building from Source

If you prefer to compile the app yourself:

```bash
git clone https://github.com/SenorAdel/AutoMacro.git
cd AutoMacro
bash build.sh
```

The `build.sh` script compiles the Swift source code, generates the `.icns` file from `Icon.jpeg`, signs the `.app` bundle, installs it to your `/Applications` directory, and packages a distributable `.dmg`.

## How It Works

- **Global Hotkeys:** Uses the Carbon `RegisterEventHotKey` API. This registers hotkeys directly with the system and avoids requiring Accessibility permission just for detection.
- **Mouse/Keyboard Simulation:** Uses `CGEvent` posting.
- **Macro Recording:** Uses `NSEvent.addGlobalMonitorForEvents` to capture input from any app.
- **Persistence:** Uses `UserDefaults` with JSON encoding for macro sequences and hotkey configurations.

## Disclaimer

This tool was created strictly for fun and educational purposes. The author is not responsible for any misuse, damage, or violation of terms of service that may occur through the use of this application. Please use it responsibly.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
