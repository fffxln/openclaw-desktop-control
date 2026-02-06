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

Send the screenshot to Claude vision with this exact prompt structure. You MUST answer every field before proposing coordinates.

```
TASK: I need to [current step from the plan].

PHASE 1 — SCENE UNDERSTANDING (answer all before moving to Phase 2):
1. FOREGROUND APP: What app/window is in the foreground? What view/screen/tab is active?
2. SCREEN REGION MAP: Divide the visible UI into named regions (e.g., "left sidebar", "main content", "toolbar", "modal overlay"). For each region, state its approximate pixel bounds (x_min, y_min, x_max, y_max).
3. SENSITIVE CONTENT CHECK: Does the screen contain banking, passwords, credentials, private messages, or API keys? If yes, STOP — do not proceed to Phase 2.
4. EXPECTED ELEMENT: Describe in words what the target element looks like (label text, icon shape, color, size) and which REGION it should be in.
5. DANGER ZONE CHECK: Consult the Danger Zones list for the current app. Are any danger-zone elements within 40px of the expected target? If yes, flag which ones.

PHASE 2 — LOCALIZATION (only after completing Phase 1):
6. TARGET COORDINATES: Give the pixel coordinates (x, y) of the CENTER of the target element. Not the edge — the center.
7. ELEMENT BOUNDS: Estimate the bounding box of the target element: (x_min, y_min, x_max, y_max). The click coordinate from #6 must fall inside this box.
8. CONFIDENCE: Rate your coordinate confidence as HIGH (element is large, isolated, clearly labeled), MEDIUM (element is small or near other clickable elements), or LOW (element is ambiguous, crowded, or partially occluded).
9. KEYBOARD ALTERNATIVE: Is there a keyboard shortcut or search-based way to achieve the same action without clicking? If yes, describe it.
10. RECOMMENDED ACTION: State the single best next action. If confidence is LOW or a danger zone is nearby, RECOMMEND the keyboard alternative from #9 instead.
```

**Decision rules after analysis:**
- If CONFIDENCE is LOW: Strongly prefer the keyboard alternative. If none exists, take a closer screenshot (region capture with `-R` flag) and re-analyze.
- If CONFIDENCE is MEDIUM and a danger zone is within 40px: Strongly prefer the keyboard alternative.
- If sensitive content is detected: STOP and ask the user before proceeding.
- If the target element is not visible: scroll and re-capture (see [Scrolling](#scrolling)). After 3 scroll attempts, stop and ask the user.

### Step 3.5: Validate Coordinates (Pre-Click Safety Check)

Before executing ANY click action, perform this validation. Skip this step only for keyboard-only actions.

**Validation checklist (answer all before clicking):**

1. **COORDINATE SANITY:** Are the coordinates (x, y) within the screen bounds? Are they in the correct REGION identified in Step 3?
   - x must be between the region's x_min and x_max
   - y must be between the region's y_min and y_max
   - If coordinates fall outside the expected region → STOP and re-analyze

2. **ADJACENT ELEMENT CHECK:** What clickable elements exist within 30px in each direction (up, down, left, right) of the target coordinate?
   - List each adjacent element and what it does
   - If any adjacent element triggers an irreversible or dangerous action (call, delete, send, purchase) → flag it

3. **RETINA CORRECTION VERIFY:** Confirm the scale factor has been applied. State: "Raw pixel coordinates: (Xr, Yr). Scale factor: S. Click coordinates: (Xr/S, Yr/S) = (Xc, Yc)."

4. **BOUNDING BOX MARGIN:** Is the click coordinate at least 5px inside the element's bounding box on all sides? If the element is smaller than 20px in any dimension → prefer keyboard navigation instead.

5. **DANGER ZONE CLEARANCE:** Compute the pixel distance from the click coordinate to every danger zone element for this app (see [Danger Zones](#danger-zones)). If any distance is < 30px → ABORT the click and use keyboard alternative.

**If validation fails on any check:** Do NOT click. Use a keyboard shortcut, search, or tab-based navigation to reach the target. If no alternative exists, inform the user of the risk and ask for confirmation.

### Step 4: Act

Execute exactly one action per cycle. Do not chain multiple actions without verifying each one.

**Action priority (prefer higher over lower):**
1. **Keyboard shortcut** — fastest, no coordinate risk (e.g., Cmd+Enter to submit, Escape to dismiss)
2. **Search/filter + keyboard** — type to find element, then Enter to select (e.g., Spotlight, app search bars, Cmd+K palettes)
3. **Tab navigation** — Tab/Shift+Tab through focusable elements, Enter to activate
4. **Mouse click** — least preferred, should pass Step 3.5 validation first

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

### Step 5: Assert Expected State

Take another screenshot immediately after the action. Perform a **state assertion** — check against the specific outcome you expected, not just "did something change."

**State assertion checklist:**

1. **STATE MATCH:** Before acting (in Step 3), you described the expected outcome. Does the current screenshot match? (e.g., "The WhatsApp chat with John should be open, showing message history, with the header displaying 'John'")
2. **ELEMENT VERIFICATION:** Is the element you interacted with now in its expected post-action state? (button appears pressed, menu is open, text field contains the typed text, correct view is now active)
3. **UNWANTED CHANGES:** Did anything change that should NOT have changed? (different window came to front, a modal appeared, navigation changed to wrong view, a call was initiated)
4. **APP STATE:** Is the foreground app still the correct one? Is the correct view/tab/screen still active?

**Outcome classification:**
- **SUCCESS**: All 4 checks pass → proceed to Step 6
- **PARTIAL**: The action had some effect but the state doesn't fully match → log what's wrong, decide whether to retry with adjusted approach or proceed with modified plan
- **FAILURE**: The action had no effect, or caused an unwanted state change → enter Recovery Protocol (Step 5.5)
- **DANGER**: An unexpected modal, dialog, or navigation occurred that could lead to data loss or unintended external action (call, message send, deletion) → enter Recovery Protocol immediately with DANGER priority

### Step 5.5: Recovery Protocol

Enter this step when Step 5 classifies the outcome as FAILURE or DANGER. Follow the escalation ladder in order — do NOT skip levels.

**Level 1 — Soft Recovery (no state risk):**
- Press Escape (up to 3 times, with 0.5s between each)
- Take screenshot. If returned to expected state → resume from Step 2.
- Try Cmd+Z (undo) if an unintended text input or edit occurred
- Take screenshot. If recovered → resume from Step 2.

**Level 2 — Navigation Recovery (low state risk):**
- Use keyboard shortcuts to navigate back to a known state:
  - Cmd+W: close current tab/window/modal
  - Cmd+[: go back (browsers)
  - Cmd+,: close preferences if accidentally opened
- For app-specific recovery, consult the app's section in patterns.md
- Take screenshot after each attempt. If recovered → resume from Step 2.

**Level 3 — App Reset (medium state risk):**
- Quit the app: `osascript -e 'tell application "APP" to quit'`
- Wait 2 seconds
- Relaunch: `osascript -e 'tell application "APP" to activate'`
- Wait 3 seconds, take screenshot
- Navigate back to the starting point of the current task step
- Resume from Step 2

**Level 4 — User Escalation (safe stop):**
- Take a screenshot of the current state
- Report to the user:
  - What action was attempted
  - What went wrong (FAILURE or DANGER classification)
  - What recovery steps were tried
  - The current screen state
- Ask the user whether to: retry, skip this step, or abort the entire task
- Do NOT attempt any further automated actions until the user responds

**DANGER priority override:** If the outcome was classified as DANGER, skip Level 1 and start at Level 2. If an irreversible external action has ALREADY been triggered (call initiated, message sent, file deleted), skip to Level 4 immediately. If a modal or dialog has appeared that *could* lead to an unintended action but nothing irreversible has happened yet (e.g., a "Create call link" dialog is showing but no link was created), start at Level 2 — the goal is to dismiss the dialog, not escalate prematurely.

**Note on Escape during DANGER recovery:** "Skip Level 1" means skip the *generic* soft recovery steps. App-specific recovery patterns consulted at Level 2 may include Escape as part of their tested workflow — this is permitted because those patterns are scoped to the specific app context.

**Retry budget:** Track total retries across all steps for this task. After 5 total retries (across all steps combined), automatically escalate to Level 4 regardless of current level.

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
- **Center targeting:** Always aim for the CENTER of a UI element, never the edge. Edges risk hitting adjacent elements.
- **Minimum element size:** If the target element is smaller than 20x20px in screen coordinates, prefer keyboard navigation over clicking.
- **Coordinate logging:** Before every click, explicitly state: "Clicking at (X, Y) which is the center of [element description] in the [region name] region. Nearest danger zone: [element] at [distance]px."

## Danger Zones

Danger zones are UI elements that, if accidentally clicked, cause irreversible or disruptive actions. The agent MUST maintain clearance from these zones when clicking nearby elements.

**How to use danger zones:**
- During Step 3 (Analyze), check if any danger zone element is within 40px of the target
- During Step 3.5 (Validate), compute exact pixel distance to each danger zone
- If clearance is < 30px, ABORT the click and use keyboard navigation instead

### WhatsApp Desktop
| Danger Zone | Approximate Location | What happens if misclicked |
|---|---|---|
| Calls icon (sidebar) | x: 10-30, y: 55-75 (screen coords) | Opens Calls view, may trigger "Create call link" modal which blocks all navigation |
| Video call button | Top-right of chat header, rightmost icon | Initiates video call to contact |
| Voice call button | Top-right of chat header, second from right | Initiates voice call to contact |
| Status icon (sidebar) | x: 10-30, y: 35-55 (screen coords) | Navigates away from Chats view |

### Twitter / X (browser)
| Danger Zone | Approximate Location | What happens if misclicked |
|---|---|---|
| Delete tweet option | Inside tweet "..." menu | Permanently deletes tweet |
| Retweet (if not intended) | Below tweet, second icon from left | Publicly retweets to followers |
| Follow/Unfollow toggle | Profile cards, right side | Changes follow state |
| Modal close/overlay area | Edges of compose modal, dimmed background | Closes compose modal, may lose draft |
| Account menu | Bottom-left sidebar | Opens account switching/logout menu |

### General (all apps)
| Danger Zone | What happens if misclicked |
|---|---|
| Window close button (red circle, top-left) | Closes window, may lose unsaved work |
| "Delete" / "Remove" in any context menu | Permanent data loss |
| "Send" / "Post" / "Publish" when content is not ready | Premature publication |
| System notification banners (top-right) | Navigates away to notification source app |
| Dock icons (bottom of screen) | Switches to different app, loses context |

### Adding new danger zones
When a misclick causes a problematic outcome, add the element to this table with:
1. The app name
2. The element description and approximate location
3. What happens when misclicked

This list is the institutional memory for avoiding repeat failures.

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
