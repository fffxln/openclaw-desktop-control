# OpenClaw Desktop Control

macOS desktop automation through vision-action loops. Capture screenshots, analyze with Claude vision, and control mouse/keyboard via a TCC-compliant helper app.

## Requirements

- macOS 14.0 (Sonoma) or later
- Screen Recording permission (guided setup)
- Accessibility permission (guided setup)

## Installation

**Guided setup (recommended):**
```bash
git clone https://github.com/fffxln/openclaw-desktop-control.git
cd openclaw-desktop-control
bash scripts/setup-wizard.sh
```

The wizard walks you through each step -- installing the helper, granting permissions, and verifying everything works. No developer tools required.

**Manual:**
```bash
bash scripts/install.sh
```

**As an OpenClaw skill:**
Add this repo's path to your `~/.openclaw/openclaw.json`:
```json
{
  "skills": {
    "load": {
      "extraDirs": ["/path/to/openclaw-desktop-control"]
    }
  }
}
```

## How It Works

```
Plan -> Capture -> Analyze -> Validate -> Act -> Assert -> Recover (if needed) -> Repeat
```

The skill uses a **hybrid vision + accessibility** approach:

1. **Analyze** — Two-phase structured analysis with vision, then cross-reference with the macOS Accessibility API to get exact element positions
2. **Validate** — Pre-click safety: verify coordinates, check adjacent elements, use `element-at-point` to confirm the target
3. **Act** — Accessibility-first: click elements by label/role (zero coordinate risk), fall back to keyboard shortcuts, then vision-estimated coordinates as last resort
4. **Assert** — Explicit state assertion with `get-focused-element` to verify focus landed correctly
5. **Recover** — 4-level escalation ladder (Escape → navigation shortcuts → app reset → user escalation)

**Why accessibility + vision?** Vision understands the scene (what's on screen, what to interact with). The Accessibility API performs the action (finds the exact element, clicks it by reference). Vision coordinate estimates are 10-50px off — accessibility coordinates are exact.

**Why a helper app?**
macOS requires Screen Recording and Accessibility permissions to be granted per-app. The helper runs as a proper `.app` bundle so it can receive its own TCC permissions, separate from Terminal or OpenClaw.

## Usage

Always use the wrapper script:

```bash
# Accessibility — click element by label (zero coordinate risk)
scripts/desktop-control click-element --label "Send" --role AXButton

# Accessibility — find element and get exact screen-point coordinates
scripts/desktop-control find-element --label "Chats"
scripts/desktop-control get-element-frame --label "Chats"

# Accessibility — check what's at a point / what has focus
scripts/desktop-control element-at-point --x 500 --y 300
scripts/desktop-control get-focused-element

# Accessibility — explore available elements
scripts/desktop-control get-ui-tree --app "Finder" --depth 3

# Screenshot
scripts/desktop-control screencapture -x /tmp/screen.png

# Mouse/keyboard (via cliclick)
scripts/desktop-control cliclick c:500,300
scripts/desktop-control cliclick t:"Hello world"

# Display and permissions
scripts/desktop-control get-scale-factor
scripts/desktop-control check-permissions
scripts/desktop-control request-permission
```

See [SKILL.md](SKILL.md) for the complete workflow documentation and [patterns.md](patterns.md) for app-specific automation recipes.

## Project Structure

```
openclaw-desktop-control/
├── src/helper.swift               # Swift CLI (ScreenCaptureKit + Accessibility API + cliclick)
├── scripts/
│   ├── setup-wizard.sh            # Guided first-time setup
│   ├── install.sh                 # Automated installation
│   ├── build.sh                   # Build from source (universal binary)
│   └── desktop-control            # Wrapper script (main entry point)
├── bin/
│   ├── DesktopControlHelper.app/  # Pre-built universal binary (arm64 + x86_64)
│   └── cliclick                   # Bundled cliclick binary
├── SKILL.md                       # Complete workflow documentation
├── _meta.json                     # Skill metadata and security review
├── patterns.md                    # App-specific automation recipes
└── setup_check.sh                 # Prerequisites verification
```

## Security

**Verdict:** Conditional -- requires security gates for sensitive apps.

The skill stops and asks for your permission before interacting with:
- Banking or financial apps
- Password managers (1Password, Bitwarden, LastPass, Keychain Access)
- Authentication screens (login pages, 2FA prompts)
- Terminals displaying API keys or credentials

Screenshots are stored temporarily in `/tmp/` and deleted after each task.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Setup issues | Run: `bash scripts/setup-wizard.sh` |
| Screenshots are black | Grant Screen Recording in System Settings |
| Clicks don't work | Grant Accessibility in System Settings |
| Wrong window gets input | The skill activates the target app first |
| Coordinate mismatch | Run `scripts/desktop-control get-scale-factor` to check Retina scaling |
| Full diagnostics | Run: `bash setup_check.sh` |

## Development

**Rebuild from source:**
```bash
bash scripts/build.sh
```

Produces a universal binary (arm64 + x86_64) signed with ad-hoc identity `ai.openclaw.desktop-control-helper`.

## License

[MIT](LICENSE)
