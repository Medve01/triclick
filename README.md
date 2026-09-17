# Triclick

**Three fingers. Middle click.**

A tiny open-source macOS menu-bar app that turns a three-finger trackpad tap or click into a real middle mouse button — so you can open links in new tabs, close tabs, paste in Terminal, and pan in CAD tools without a mouse.

Trackpad only. No account. No telemetry. MIT licensed.

## Install

### From a release DMG

1. Download `Triclick-x.y.z.dmg` from [Releases](https://github.com/Medve01/triclick/releases).
2. Open the DMG and drag **Triclick** into **Applications**.
3. First launch: right-click the app → **Open** (Gatekeeper will warn because builds are ad-hoc signed, not notarized).
4. Grant **Accessibility** when the welcome window asks — Triclick cannot post clicks without it.

### Build from source

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/Medve01/triclick.git
cd triclick
make install   # builds + copies to /Applications
# or: make run
# or: make dmg
```

## Gestures

| Gesture | Default | What it does |
|--------|---------|--------------|
| Three-finger **click** | On | Physical press with three fingers → middle click |
| Three-finger **tap** | On | Light tap with three fingers → middle click |
| **fn + click** | Off | Hold fn and click → middle click |

Toggle everything from the menu-bar icon.

## Why Accessibility?

macOS only lets trusted apps synthesize mouse events. Triclick uses that one permission — no Input Monitoring, no Screen Recording, no kernel extensions.

Ad-hoc builds pin Accessibility to each binary hash, so rebuilds break the grant even when the toggle still looks ON. Local builds use a stable **Triclick Local** signing cert (`make cert` once) so permission survives rebuilds.

If the toggle is ON but Triclick still shows ✗: click **Reset Permissions & Restart**, then add Triclick again with **+** in Accessibility and Input Monitoring.

## Development

```bash
make          # build Triclick.app into build/
make run      # build and launch
make dmg      # build/ + dist/Triclick-1.0.0.dmg
make clean
```

## License

MIT — see [LICENSE](LICENSE).

Inspired by the idea behind [Middle](https://middleclick.app/) and the open-source lineage of MiddleClick / friends. Triclick is an independent project.