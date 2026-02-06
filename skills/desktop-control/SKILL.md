---
name: desktop-control
description: "See and interact with the macOS desktop through a vision-action loop. Captures screenshots, analyzes them with Claude vision, and executes mouse clicks, keyboard input, and app navigation via cliclick and AppleScript. Use when the user asks to interact with GUI applications, click buttons, open or navigate native macOS apps (Figma, Finder, System Settings, etc.), export files from visual interfaces, fill forms in desktop apps, or perform any task requiring seeing and acting on the screen. Triggers: 'look at my screen', 'click on X', 'open app Y and do Z', 'export from Figma', 'navigate to settings', or any multi-step desktop GUI workflow."
---

# Desktop Control

Control the macOS desktop through a screenshot → vision → action → verify loop.

## Prerequisites

Run `{baseDir}/scripts/setup_check.sh` before first use. The helper app will auto-install on first use.

Required (all auto-installed):
- **Desktop Control Helper** (auto-installed to `~/.openclaw/bin/`)
- **cliclick** (bundled, or install via `brew install cliclick`)
- macOS 14.0 (Sonoma) or later

**Installation:**
The helper installs automatically on first use. For guided setup:
```bash
bash {baseDir}/scripts/setup-wizard.sh
```

## Workflow

Follow these steps precisely for every desktop control task. Do not skip steps.

### Step 1: Plan

Before touching the screen:

1. Break the user's request into discrete steps (e.g., "open Figma and export as PNG" → open Figma, navigate to project, select frame, open export panel, set format, click export, confirm save)
2. Announce the plan to the user: list each step, ask for confirmation if the task involves more than 3 steps or any ambiguity
3. Identify which apps are involved and whether any are sensitive (see [Security](#security))

If any involved app is in the **always-flag** list → stop and ask the user for explicit permission before proceeding. If the user declines, abort the entire task.

### Step 2: Capture

Take a screenshot before every action. Never act blind.

**IMPORTANT:** Use the Desktop Control Helper wrapper instead of calling `screencapture` directly:

```bash
# Full screen (always use -x to suppress shutter sound)
{baseDir}/scripts/desktop-control screencapture -x /tmp/pac_screen.png

# Specific display (multi-monitor)
{baseDir}/scripts/desktop-control screencapture -x -D 1 /tmp/pac_screen.png
```

The wrapper automatically routes commands to the helper app with proper permissions.

**Retina scaling:** Screenshots from Retina displays are captured at the native resolution. Get the actual scale factor first:
```bash
SCALE=$({baseDir}/scripts/desktop-control get-scale-factor)
```
Then divide all identified pixel coordinates by `$SCALE` before clicking. For most Macs this is 2, but some displays use 1 or 3.

### Step 3: Analyze

Send the screenshot to Claude vision with this exact prompt structure:

```
Look at this screenshot. I need to [current step from the plan].
1. What app is in the foreground?
2. Where is [target element]? Give pixel coordinates (x, y).
3. Does the screen contain sensitive content? (banking, passwords, credentials, private messages, API keys)
4. What is the single best next action?
```

If the analysis reveals sensitive content that was not anticipated in Step 1 → stop and ask the user before proceeding. Do not act.

If the target element is not visible → try scrolling (see [Scrolling](#scrolling)) and take a new screenshot. After 3 scroll attempts without finding the element, stop and ask the user.

### Step 4: Act

Execute exactly one action per cycle. Do not chain multiple actions without verifying each one.

#### Mouse (cliclick)

**IMPORTANT:** Use the Desktop Control Helper wrapper:

```bash
{baseDir}/scripts/desktop-control cliclick c:500,300          # left click
{baseDir}/scripts/desktop-control cliclick dc:500,300         # double click
{baseDir}/scripts/desktop-control cliclick rc:500,300         # right click
{baseDir}/scripts/desktop-control cliclick tc:500,300         # triple click (select line)
{baseDir}/scripts/desktop-control cliclick m:500,300          # move without clicking
{baseDir}/scripts/desktop-control cliclick dd:100,100 du:500,500  # drag
```

#### Keyboard (cliclick)

**IMPORTANT:** Use the Desktop Control Helper wrapper:

```bash
{baseDir}/scripts/desktop-control cliclick t:"Hello world"   # type text
{baseDir}/scripts/desktop-control cliclick kp:return          # press key (return, tab, escape, delete, space)
{baseDir}/scripts/desktop-control cliclick kd:cmd kp:a ku:cmd     # Cmd+A
{baseDir}/scripts/desktop-control cliclick kd:cmd kp:c ku:cmd     # Cmd+C
{baseDir}/scripts/desktop-control cliclick kd:cmd kp:v ku:cmd     # Cmd+V
{baseDir}/scripts/desktop-control cliclick kd:cmd kp:s ku:cmd     # Cmd+S
{baseDir}/scripts/desktop-control cliclick kd:cmd kp:w ku:cmd     # Cmd+W
{baseDir}/scripts/desktop-control cliclick kd:cmd kp:q ku:cmd     # Cmd+Q
{baseDir}/scripts/desktop-control cliclick kd:cmd kp:space ku:cmd # Spotlight
```

#### App control (AppleScript)

```bash
# Activate/launch app — always do this before interacting with an app
osascript -e 'tell application "Figma" to activate'

# Get frontmost app
osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true'

# Get window title
osascript -e 'tell application "System Events" to get title of front window of first application process whose frontmost is true'

# List running apps
osascript -e 'tell application "System Events" to get name of every application process whose background only is false'
```

**Always activate the target app before clicking or typing.** If the wrong app is in the foreground, input will go to the wrong place.

After every action, add `sleep 0.5` minimum to allow the UI to settle. For app launches, use `sleep 2`. For file saves/exports, use `sleep 1`.

### Step 5: Verify

Take another screenshot immediately after the action. Check:

1. Did the expected change occur? (button pressed, menu opened, text entered, etc.)
2. Did an unexpected dialog or popup appear? → handle it before continuing
3. Is a loading state or animation in progress? → `sleep 2`, screenshot again, up to 5 retries (10 sec total)

**If the action failed:**
- Attempt 1: Recalculate coordinates from a fresh screenshot and retry
- Attempt 2: Try an alternative approach (e.g., keyboard shortcut instead of clicking a menu item)
- Attempt 3: Stop and report the failure to the user with a screenshot of the current state

Do not attempt the same action more than 3 times.

### Step 6: Loop or Complete

If there are remaining steps in the plan → return to Step 2 for the next step.

If all steps are complete → take a final verification screenshot, confirm to the user that the task is done, and clean up: `rm -f /tmp/pac_screen*.png`

## Security

### Always-flag apps (stop and ask user before proceeding)

- Banking or financial apps/websites (any URL with bank/finance domain, any app with "Bank" in the title)
- Password managers: 1Password, Bitwarden, LastPass, Keychain Access
- Authentication screens: login pages, 2FA prompts, SSO flows
- Terminal windows displaying environment variables, API keys, or credentials (patterns: `export API_KEY=`, `Bearer `, long hex/base64 strings)

**Decision procedure when sensitive content is detected:**
1. Stop immediately — do not click, type, or interact
2. Describe to the user what sensitive content is visible
3. Ask: "This screen contains [description]. Should I proceed, skip this step, or abort?"
4. Only continue if the user explicitly says to proceed

### Auto-proceed apps (no flag needed)

- Design tools: Figma, Sketch, Adobe CC
- Productivity: Notion, Obsidian, Notes, Reminders, Calendar
- Browsers showing non-sensitive content
- Finder, Preview, System Settings, Activity Monitor
- Code editors: VS Code, Cursor, Xcode, Terminal (unless credentials visible)
- Communication apps the user explicitly asked to control

### False positives — do NOT flag these as sensitive

- A browser tab title or article headline that mentions "bank" or "password" in editorial context
- A code editor showing example/test credentials that are clearly fake (`password123`, `sk-test-xxx`)
- System Settings panes that don't display actual credentials
- The user's own terminal where they just ran the setup command

### Screenshot handling

- All screenshots go to `/tmp/pac_screen*.png`
- Delete after task completion: `rm -f /tmp/pac_screen*.png`
- Never save screenshots permanently unless the user explicitly asks
- Never send screenshots to any destination other than Claude vision analysis

## Scrolling

```bash
{baseDir}/scripts/desktop-control cliclick kp:page-down    # page down
{baseDir}/scripts/desktop-control cliclick kp:page-up      # page up
{baseDir}/scripts/desktop-control cliclick kp:arrow-down   # fine scroll (repeat as needed)
```

If the target element is not visible, scroll down, wait 0.5s, and take a new screenshot. After 3 scrolls without finding the element, stop and ask the user.

## Coordinate Rules

- Always derive coordinates from the most recent screenshot — never reuse from previous screenshots
- macOS menu bar: ~25px from top
- Dock: ~70px from bottom (or side, depending on user config)
- Retina: divide screenshot pixel coordinates by the display scale factor (use `get-scale-factor`)
- If coordinates seem wrong after clicking, the UI may have scrolled or resized — take a fresh screenshot

## Common App Patterns

For app-specific step-by-step recipes (Figma export, Finder navigation, System Settings, browser fallback), see `{baseDir}/references/patterns.md`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `cliclick` not found | `brew install cliclick` |
| Helper not installed | Run: `bash {baseDir}/scripts/install.sh` |
| Clicks don't register | System Settings → Privacy & Security → Accessibility → enable DesktopControlHelper |
| Screenshots are black | System Settings → Privacy & Security → Screen Recording → enable DesktopControlHelper |
| Permission denied | Run: `{baseDir}/scripts/desktop-control request-permission` |
| Wrong window gets input | `osascript -e 'tell application "X" to activate'` before acting |
| Retina coordinate mismatch | Run `{baseDir}/scripts/desktop-control get-scale-factor` and divide by that value |
| App ignores keyboard input | Click inside the app window first to ensure focus, then type |
