<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/icon-dark.png">
  <img src="docs/assets/icon.png" width="160" alt="OpenAbi icon: a friendly folder with a big mustache looking after a little document">
</picture>

# OpenAbi

**The “Open with Code” menu your Mac never had.**<br>
Right‑click any folder in Finder → open it in VS Code, Cursor, Zed, Terminal, iTerm, Ghostty, or any app you like.

[![Download for macOS](https://img.shields.io/badge/Download-macOS-d9342b?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/firatmelih/OpenAbi/releases/latest/download/OpenAbi.dmg)

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-1d1d1f?logo=apple)
![Apple Silicon & Intel](https://img.shields.io/badge/Apple%20Silicon%20%26%20Intel-universal-1d1d1f)
![Notarized](https://img.shields.io/badge/Apple-notarized-1d1d1f)
[![License: MIT](https://img.shields.io/badge/License-MIT-3B2118)](LICENSE)

[Website](https://firatmelih.github.io/OpenAbi/) · [Download](https://github.com/firatmelih/OpenAbi/releases/latest) · [Report a bug](https://github.com/firatmelih/OpenAbi/issues)

</div>

---

On Windows, VS Code puts **“Open with Code”** in the right‑click menu. On a Mac you get… dragging folders onto the Dock, or `cd`‑ing around to type `code .`. Finder's **Open With** menu doesn't even appear for folders.

OpenAbi fixes that. Tell it once which apps belong to folders (or to `.md`, `.json`, `.xcodeproj`, anything), and they're one right‑click away forever.

> **abi** */ah‑bee/* (Turkish): big brother. The one who always knows what to do with your stuff.

<p align="center">
  <img src="docs/assets/context-menu.svg" width="680" alt="Finder context menu on a folder showing 'Open in Visual Studio Code', 'Open in Terminal' and 'Open in Cursor', added by OpenAbi">
</p>

## Features

- ⚡️ **Two‑second setup.** OpenAbi finds VS Code, Cursor, Windsurf, Zed, VSCodium, Sublime Text, Nova, Terminal, iTerm, Ghostty and Warp on your Mac. Click **Add All to Folders** and you're done.
- 🫳 **Any app, any file type.** Drag any `.app` onto **Folders**, **All Files**, or a specific type like `.md`, `.json` or `.xcodeproj`.
- 🖱️ **Right in Finder.** Clean **Open in Visual Studio Code** items with app icons. Works on folders, files, multiple selections, and the empty background of a window.
- 🥸 **Toolbar button.** An optional mustache button in Finder's toolbar opens the current folder in your apps.
- 🗂️ **Your menu, your way.** Show items directly, or tuck them into a single **OpenAbi ▸** submenu.
- 🔄 **Updates itself.** OpenAbi tells you when a new version is out and installs it in one click, so you never need to download it again.
- 🪶 **Tiny, native, private.** SwiftUI plus a Finder Sync extension. Signed and notarized by Apple. No accounts, no telemetry.

## Install

**Download:** grab **[OpenAbi.dmg](https://github.com/firatmelih/OpenAbi/releases/latest/download/OpenAbi.dmg)**, open it, drag **OpenAbi** into **Applications**, and launch it once.

**Homebrew:**

```bash
brew tap firatmelih/openabi https://github.com/firatmelih/OpenAbi
brew install --cask openabi
```

On first launch, OpenAbi turns on its Finder extension for you; the green dot at the top of the window confirms it. Then click **Add All to Folders** in Quick setup, or drag in your own apps.

<details>
<summary><b>The menu items don't show up?</b></summary>

- Make sure the extension is on. Click **Enable in System Settings…** in OpenAbi, or go to **System Settings → General → Login Items & Extensions → Finder** (on macOS 14: **Privacy & Security → Extensions → Added Extensions**) and turn on **OpenAbi**.
- Keep only one copy of OpenAbi.app on your Mac (the one in **Applications**).
- Still nothing? Restart Finder: hold <kbd>⌥ Option</kbd>, right‑click Finder in the Dock, and choose **Relaunch**.

</details>

## Use

| You add… | to… | Right‑click in Finder shows |
| --- | --- | --- |
| Visual Studio Code | **Folders** | `Open in Visual Studio Code` on every folder |
| Terminal / iTerm / Ghostty | **Folders** | `Open in Terminal`, which opens a shell right there |
| Typora | **.md** | `Open in Typora` on Markdown files |
| Xcode | **.xcodeproj** | `Open in Xcode` on project bundles |
| TextEdit | **All Files** | `Open in TextEdit` on any file |

- **Add a file type:** type extensions into the field (`md, json, yml`) and press <kbd>Return</kbd>.
- **Remove an app:** click the ⓧ on its chip, or right‑click the chip → **Remove**.
- **Toolbar button:** in any Finder window, choose **View ▸ Customize Toolbar…** and drag the 🥸 **OpenAbi** button into the toolbar.
- **Submenu:** turn on **Group apps in an “OpenAbi” submenu** at the bottom of the window.

You don't need to keep OpenAbi running. Finder loads the extension by itself, and changes apply immediately.

## Updates

OpenAbi uses [Sparkle](https://sparkle-project.org), the standard updater for Mac apps:

- The app checks for updates automatically, and you can also choose **OpenAbi ▸ Check for Updates…**.
- Since you'll rarely open the app itself, the Finder extension also checks once a day. When a new version is out, an **Update OpenAbi to x.y…** item appears in your right‑click menu.
- Updates are signed (EdDSA) and verified before installing, then OpenAbi relaunches. Homebrew installs update the same way.

OpenAbi only goes online to check for updates (the [`appcast.xml`](https://firatmelih.github.io/OpenAbi/appcast.xml) feed and release notes on GitHub Pages) and to download them from GitHub Releases.

## How it works

```text
┌──────────────────────┐   rules.json (App Group)   ┌──────────────────────────┐
│  OpenAbi.app         │ ─────────────────────────▶ │  Finder Sync extension   │
│  SwiftUI + Sparkle   │                            │  context menu & toolbar  │
└──────────┬───────────┘                            └────────────┬─────────────┘
           │ installs                                            │ runs on click
           ▼                                                     ▼
  ~/Library/Application Scripts/…/open-with.sh   ──▶   open -a "<App>" <items…>
```

Finder extensions must be sandboxed, and a sandboxed process isn't allowed to ask another app to open your files. So the main app installs a one‑line helper script into the extension's *Application Scripts* folder. macOS runs scripts from that folder outside the sandbox (via `NSUserUnixTask`). The script is just `open -a`.

Your rules stay on your Mac in `~/Library/Group Containers/XQH36L7379.com.melihfirat.OpenAbi/rules.json`.

## Build from source

Requires Xcode 26 or later (the icon is an Icon Composer `.icon`). Sparkle is pulled in by Swift Package Manager.

```bash
git clone https://github.com/firatmelih/OpenAbi.git
cd OpenAbi
open OpenAbi.xcodeproj   # then Run the "OpenAbi" scheme
```

For your own fork, set your team in **Signing & Capabilities** for both targets, and replace the `XQH36L7379` App Group prefix in `Config/*.entitlements` and `Shared/Rules.swift`.

### Releasing

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` (Sparkle compares the build number).
2. Add `docs/release-notes/<version>.html`.
3. Build, notarize, sign for Sparkle, and write `docs/appcast.xml`:
   ```bash
   NOTARY_PROFILE=OpenAbi scripts/release.sh
   ```
4. Publish the DMG first (`gh release create v<version> dist/OpenAbi.dmg`), then commit and push `docs/appcast.xml` and bump `version`/`sha256` in `Casks/openabi.rb`.

The Sparkle private key lives in the maintainer's Keychain (account `OpenAbi`). The public key is `SUPublicEDKey` in `Config/OpenAbi-Info.plist`.

### Project layout

| Path | What's inside |
| --- | --- |
| `OpenAbi/` | The app: SwiftUI window, presets, rule editing, Sparkle updater, helper-script installer, app icon |
| `FinderExtension/` | The Finder Sync extension: context menu, toolbar button, daily update check |
| `Shared/` | Rule model and storage used by both targets |
| `Config/` | Entitlements and Info.plists |
| `Casks/` | Homebrew cask |
| `docs/` | The [website](https://firatmelih.github.io/OpenAbi/), update feed, and release notes (GitHub Pages) |

## Uninstall

Quit OpenAbi and move it to the Trash (or `brew uninstall --zap --cask openabi`). To remove its leftover data by hand:

```bash
rm -rf ~/Library/Group\ Containers/XQH36L7379.com.melihfirat.OpenAbi \
       ~/Library/Application\ Scripts/com.melihfirat.OpenAbi.FinderExtension
```

## License

[MIT](LICENSE) © Melih Firat

<p align="center"><sub>Made with çay ☕ in Türkiye</sub></p>
