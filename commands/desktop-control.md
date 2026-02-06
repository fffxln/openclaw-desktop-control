---
allowed-tools: Bash({baseDir}/scripts/desktop-control:*), Bash(osascript:*), Bash(open:*), Bash(sleep:*), Bash(rm:*)
description: "See and interact with the macOS desktop through a vision-action loop. Captures screenshots, analyzes them with Claude vision, and executes mouse clicks, keyboard input, and app navigation via cliclick and AppleScript."
argument-hint: "What to do on the desktop (e.g., 'open Figma and export the logo as PNG')"
---

Control the macOS desktop through a screenshot → vision → action → verify loop.

## Step 1: Plan

Before touching the screen:

1. Break the user's request into discrete steps (e.g., "open Figma and export as PNG" → open Figma, navigate to project, select frame, open export panel, set format, click export, confirm save)
2. Announce the plan to the user: list each step, ask for confirmation if the task involves more than 3 steps or any ambiguity
3. Identify which apps are involved and whether any are sensitive (see Security section)

If any involved app is in the **always-flag** list → stop and ask the user for explicit permission before proceeding. If the user declines, abort the entire task.

## Step 2: Capture

Take a screenshot before every action. Never act blind.

First, get the display scale factor:
```bash
SCALE=$({baseDir}/scripts/desktop-control get-scale-factor)
```

Capture the screen:
```bash
{baseDir}/scripts/desktop-control screencapture -x /tmp/pac_screen.png
```

For a specific display: `{baseDir}/scripts/desktop-control screencapture -x -D 1 /tmp/pac_screen.png`

**Retina scaling:** Divide all identified pixel coordinates by `$SCALE` before clicking.

## Step 3: Analyze

Send the screenshot to Claude vision:

```
Look at this screenshot. I need to [current step from the plan].
1. What app is in the foreground?
2. Where is [target element]? Give pixel coordinates (x, y).
3. Does the screen contain sensitive content? (banking, passwords, credentials, private messages, API keys)
4. What is the single best next action?
```

If sensitive content is detected → stop and ask the user. Do not act.

If the target element is not visible → scroll and take a new screenshot. After 3 scroll attempts, stop and ask the user.

## Step 4: Act

Execute exactly one action per cycle. Do not chain multiple actions without verifying each one.

### Mouse (cliclick)

```bash
{baseDir}/scripts/desktop-control cliclick c:500,300          # left click
{baseDir}/scripts/desktop-control cliclick dc:500,300         # double click
{baseDir}/scripts/desktop-control cliclick rc:500,300         # right click
{baseDir}/scripts/desktop-control cliclick tc:500,300         # triple click
{baseDir}/scripts/desktop-control cliclick m:500,300          # move without clicking
{baseDir}/scripts/desktop-control cliclick dd:100,100 du:500,500  # drag
```

### Keyboard (cliclick)

```bash
{baseDir}/scripts/desktop-control cliclick t:"Hello world"        # type text
{baseDir}/scripts/desktop-control cliclick kp:return               # press key
{baseDir}/scripts/desktop-control cliclick kd:cmd kp:a ku:cmd     # Cmd+A
{baseDir}/scripts/desktop-control cliclick kd:cmd kp:c ku:cmd     # Cmd+C
{baseDir}/scripts/desktop-control cliclick kd:cmd kp:v ku:cmd     # Cmd+V
{baseDir}/scripts/desktop-control cliclick kd:cmd kp:s ku:cmd     # Cmd+S
{baseDir}/scripts/desktop-control cliclick kd:cmd kp:space ku:cmd # Spotlight
```

### App control (AppleScript)

```bash
osascript -e 'tell application "AppName" to activate'
```

**Always activate the target app before clicking or typing.**

After every action, add `sleep 0.5` minimum. For app launches, use `sleep 2`. For file saves/exports, use `sleep 1`.

## Step 5: Verify

Take another screenshot immediately after the action. Check:

1. Did the expected change occur?
2. Did an unexpected dialog or popup appear? → handle it before continuing
3. Is a loading state in progress? → `sleep 2`, screenshot again, up to 5 retries

**If the action failed:**
- Attempt 1: Recalculate coordinates from a fresh screenshot and retry
- Attempt 2: Try an alternative approach (e.g., keyboard shortcut instead of click)
- Attempt 3: Stop and report the failure to the user with a screenshot

Do not attempt the same action more than 3 times.

## Step 6: Loop or Complete

If there are remaining steps → return to Step 2.

If all steps are complete → take a final verification screenshot, confirm to the user, and clean up: `rm -f /tmp/pac_screen*.png`

## Security

### Always-flag apps (stop and ask user before proceeding)

- Banking or financial apps/websites
- Password managers: 1Password, Bitwarden, LastPass, Keychain Access
- Authentication screens: login pages, 2FA prompts, SSO flows
- Terminal windows displaying environment variables, API keys, or credentials

**When sensitive content is detected:**
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

### Screenshot handling

- All screenshots go to `/tmp/pac_screen*.png`
- Delete after task completion: `rm -f /tmp/pac_screen*.png`
- Never save screenshots permanently unless the user explicitly asks

## Scrolling

```bash
{baseDir}/scripts/desktop-control cliclick kp:page-down
{baseDir}/scripts/desktop-control cliclick kp:page-up
{baseDir}/scripts/desktop-control cliclick kp:arrow-down
```

## Coordinate Rules

- Always derive coordinates from the most recent screenshot
- macOS menu bar: ~25px from top
- Dock: ~70px from bottom
- Retina: divide screenshot pixel coordinates by the scale factor (use `get-scale-factor`)
- If coordinates seem wrong, take a fresh screenshot

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Helper not installed | Run: `bash {baseDir}/scripts/install.sh` |
| cliclick not found | Run: `bash {baseDir}/scripts/setup-wizard.sh` |
| Clicks don't register | System Settings → Privacy & Security → Accessibility → enable DesktopControlHelper |
| Screenshots are black | System Settings → Privacy & Security → Screen Recording → enable DesktopControlHelper |
| Wrong window gets input | `osascript -e 'tell application "X" to activate'` before acting |
| Retina coordinate mismatch | Use `get-scale-factor` and divide coordinates by that value |
