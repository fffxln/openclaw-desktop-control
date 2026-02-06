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
User request -> Plan -> Screenshot -> Vision analysis -> Action -> Verify -> Repeat
```

The skill uses a **vision-action loop**: it captures a screenshot, sends it to Claude for analysis, executes one action (click, type, navigate), then verifies the result with another screenshot. This continues until the task is complete.

**Why a helper app?**
macOS requires Screen Recording and Accessibility permissions to be granted per-app. The helper runs as a proper `.app` bundle so it can receive its own TCC permissions, separate from Terminal or OpenClaw.

## Usage

Always use the wrapper script:

```bash
# Screenshot
scripts/desktop-control screencapture -x /tmp/screen.png

# Click at coordinates
scripts/desktop-control cliclick c:500,300

# Type text
scripts/desktop-control cliclick t:"Hello world"

# Get display scale factor (for Retina coordinate math)
scripts/desktop-control get-scale-factor

# Check permissions
scripts/desktop-control check-permissions

# Request permissions
scripts/desktop-control request-permission
```

See [SKILL.md](SKILL.md) for the complete workflow documentation and [patterns.md](patterns.md) for app-specific automation recipes.

## Project Structure

```
openclaw-desktop-control/
├── src/helper.swift               # Swift CLI (ScreenCaptureKit + cliclick wrapper)
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
