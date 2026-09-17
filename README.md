# Triclick

**Three fingers. Middle click.**

A tiny open-source macOS menu-bar app that turns a three-finger trackpad tap or click into a real middle mouse button — open links in new tabs, close tabs, paste in Terminal, pan in CAD — without a mouse.

Trackpad only. No account. No telemetry. MIT licensed.

## Install

### From a release DMG (recommended)

1. Download the latest `Triclick-*.dmg` from [Releases](https://github.com/Medve01/triclick/releases).
2. Open the DMG and drag **Triclick** into **Applications**.
3. First launch: right-click → **Open** (builds are ad-hoc signed, not notarized — Gatekeeper warns once).
4. In the welcome window, grant **both**:
   - **Accessibility** — so Triclick can post a middle click
   - **Input Monitoring** — so Triclick can see trackpad fingers (required on modern macOS)
5. Click **Restart Triclick**, then **Continue**.

If a permission toggle looks ON but Triclick still shows ✗: use **Reset Permissions & Restart**, then remove Triclick with **−** and add it again with **+**.

### Build from source

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/Medve01/triclick.git
cd triclick
make install   # → /Applications/Triclick.app
# or: make run
# or: make dmg
```

## Gestures

| Gesture | Default | What it does |
|--------|---------|--------------|
| Three-finger **click** | On | Physical press with three fingers → middle click |
| Three-finger **tap** | On | Light tap with three fingers → middle click |
| **fn + click** | Off | Hold fn and click → middle click |

Toggle everything from the menu-bar **hand.tap** icon. While fingers are on the pad, the icon shows the live finger count (handy for debugging).

## Permissions

| Permission | Why |
|------------|-----|
| Accessibility | Post synthetic middle-click events |
| Input Monitoring | Receive raw MultitouchSupport trackpad frames |

No Screen Recording, Full Disk Access, or kernel extensions.

Builds sign with an **identifier-only** designated requirement so these grants survive rebuilds (plain ad-hoc CDHash signing would break them every `make install`).

## Development

```bash
make          # build/Triclick.app
make run      # build and launch
make dmg      # dist/Triclick-<version>.dmg
make clean
```

## License

MIT — see [LICENSE](LICENSE).

Inspired by the idea behind [Middle](https://middleclick.app/) and the open-source MiddleClick lineage. Triclick is an independent project.
