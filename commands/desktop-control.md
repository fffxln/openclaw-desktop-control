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

Send the screenshot to Claude vision with structured two-phase analysis:

```
TASK: I need to [current step from the plan].

PHASE 1 — SCENE UNDERSTANDING:
1. What app/view is in foreground?
2. Map visible UI regions with approximate pixel bounds.
3. Sensitive content check — if found, STOP.
4. Describe the target element (label, shape, color, region).
5. Danger zone check — any danger elements within 40px of target? (see Danger Zones in SKILL.md)

PHASE 2 — LOCALIZATION:
6. Target center coordinates (x, y).
7. Target bounding box (x_min, y_min, x_max, y_max).
8. Confidence: HIGH / MEDIUM / LOW.
9. Keyboard alternative available?
10. Recommended action (if LOW confidence or near danger zone, strongly prefer keyboard).
```

If CONFIDENCE is LOW or a danger zone is within 40px: use keyboard alternative. If none exists, take a region capture (`-R` flag) and re-analyze.

### Accessibility Cross-Reference

After vision analysis, use the accessibility API to get exact element positions:

```bash
# Find the target element by its label text
{baseDir}/scripts/desktop-control find-element --label "Button Text" --role AXButton

# Get exact screen-point coordinates (no Retina math needed)
{baseDir}/scripts/desktop-control get-element-frame --label "Button Text"
```

If `find-element` returns a match, use its frame coordinates instead of vision estimates. If it returns no match (common in Electron apps), fall back to vision coordinates.

## Step 3.5: Validate (Pre-Click Safety)

Before any click action, verify:
1. Coordinates fall within the expected UI region from Step 3
2. List clickable elements within 30px in each direction — flag dangerous adjacencies
3. Confirm Retina scale applied: "Raw (Xr,Yr) / Scale S = Click (Xc,Yc)"
4. Click point is 5px+ inside element bounding box on all sides
5. Distance to nearest danger zone element is > 30px

If any check fails: use keyboard alternative or ask user.

**Accessibility pre-click validation:** Before clicking at vision-estimated coordinates, verify what's actually at that point:
```bash
{baseDir}/scripts/desktop-control element-at-point --x 500 --y 300
```
If the element at that point doesn't match what you expect, do NOT click.

## Step 4: Act

Execute exactly one action per cycle. Do not chain multiple actions without verifying each one.

**Priority order (prefer higher):**
1. **Accessibility click** — click element by label, zero coordinate risk: `{baseDir}/scripts/desktop-control click-element --label "Send" --role AXButton`
2. **Keyboard shortcut** — no coordinate risk (Cmd+Enter, Escape, etc.)
3. **Search/filter + keyboard** — type to find, Enter to select (Cmd+F, Spotlight)
4. **Accessibility frame + cliclick** — exact coordinates from `get-element-frame`, no Retina math needed
5. **Tab navigation** — Tab through elements, Enter to activate
6. **Vision-estimated click** — last resort, must pass Step 3.5 validation first

### Accessibility (helper)

```bash
{baseDir}/scripts/desktop-control click-element --label "Send"              # click by label
{baseDir}/scripts/desktop-control click-element --label "Post" --role AXButton  # click by label + role
{baseDir}/scripts/desktop-control find-element --label "Chats"              # find element (returns JSON with frame)
{baseDir}/scripts/desktop-control get-element-frame --label "Chats"         # get exact screen coordinates
{baseDir}/scripts/desktop-control get-ui-tree --app "Finder" --depth 3      # dump accessibility tree
{baseDir}/scripts/desktop-control get-focused-element                       # what has focus right now
{baseDir}/scripts/desktop-control element-at-point --x 500 --y 300          # what's at these coordinates
```

Frame coordinates from accessibility commands are in screen points — they map directly to cliclick with no Retina division needed.

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

## Step 5: Assert Expected State

Take a screenshot after the action. Perform explicit state assertion:

1. Does screen match the expected post-action state described in Step 3?
2. Is the target element in its expected post-action state?
3. Did any unwanted changes occur? (wrong window, unexpected modal, wrong view)
4. Is the correct app/view still active?
5. **Focus check:** Use `{baseDir}/scripts/desktop-control get-focused-element` to verify focus landed on the expected element.

**Classification:**
- **SUCCESS** — all checks pass → proceed to Step 6
- **FAILURE** — enter Recovery Protocol (Step 5.5)
- **DANGER** — unexpected modal/dialog/navigation that could cause data loss or unintended action → enter Recovery Protocol at Level 2+

## Step 5.5: Recovery Protocol

Escalation ladder (do not skip levels):

1. **Level 1 — Soft:** Escape (3x), Cmd+Z. Screenshot. If recovered → resume from Step 2.
2. **Level 2 — Navigation:** Cmd+W, Cmd+[, app-specific shortcuts. Screenshot. If recovered → resume.
3. **Level 3 — App Reset:** Quit app, wait 2s, relaunch, navigate back. Resume from Step 2.
4. **Level 4 — User Escalation:** Screenshot + full report to user. Wait for instructions.

**DANGER classification:** start at Level 2. If an irreversible action has ALREADY occurred (call initiated, message sent, file deleted) → skip to Level 4 immediately. If a dialog appeared but nothing irreversible happened yet → start at Level 2. App-specific recovery patterns at Level 2 may include Escape — this is permitted.

**Retry budget:** 5 retries total across all steps, then auto-escalate to Level 4.

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
| `find-element` returns no match | Element may not be exposed to accessibility API (common in Electron apps). Fall back to vision coordinates |
| `click-element` has no effect | App may not support AXPress action. Use `get-element-frame` + cliclick instead |
| `get-ui-tree` is slow or empty | Reduce `--depth` or specify `--app`. Some apps have deep/sparse accessibility trees |
