# Common Patterns

App-specific recipes for the desktop-control skill. Each pattern describes the vision-action steps for a common workflow.

## Figma

### Export current frame as PNG
1. Activate Figma: `open-app "Figma"`
2. Screenshot → identify the frame/component to export
3. Click on the target element to select it
4. Open export panel: `hotkey cmd,shift e`
5. Screenshot → verify export panel is open
6. Check format is PNG (click dropdown if not)
7. Click "Export" button
8. Screenshot → verify save dialog, confirm path
9. Click "Save" or press Return

### Navigate to a specific project
1. Activate Figma
2. Screenshot → check if on home screen or inside a file
3. If inside a file: click Figma logo (top-left) → "Back to files"
4. Screenshot → find the project in recents or search
5. If not visible: click search bar, type project name
6. Click on the project tile

## Finder

### Navigate to a folder
1. Open Finder: `open-app "Finder"`
2. Go to path: `hotkey cmd,shift g` → type path → press Return
3. Screenshot → verify correct folder is displayed

### Rename a file
1. Navigate to the file's folder (see above)
2. Screenshot → find the file
3. Click on the file to select it
4. Press Return to enter rename mode
5. Type new name
6. Press Return to confirm

## System Settings

### Navigate to a specific pane
1. `open-app "System Settings"`
2. Screenshot → check what pane is currently showing
3. Click search field (top-left) or find in sidebar
4. Type the setting name (e.g., "Privacy")
5. Screenshot → click the matching result

## Browser (Chrome/Safari/Arc)

### Navigate to URL
Prefer using the browser tool (CDP) for Chrome when available. Fall back to desktop control when:
- The browser tool is not configured
- Working with Safari or Arc
- Need to interact with browser UI elements (extensions, downloads bar)

Steps:
1. Activate browser app
2. `hotkey cmd l` to focus address bar
3. Type URL
4. Press Return
5. Screenshot → wait for page load, verify

## Generic Patterns

### Click a button by label
1. Screenshot → ask vision: "Where is the button labeled [X]? Give coordinates."
2. Click at returned coordinates
3. Screenshot → verify the button action occurred

### Fill a form field
1. Screenshot → identify the field
2. Click on the field to focus it
3. Select all existing text: `hotkey cmd a`
4. Type the new value
5. Tab to next field or submit

### Handle a dialog/popup
1. Screenshot → read the dialog text
2. Determine the correct action (OK, Cancel, Allow, etc.)
3. Click the appropriate button
4. Screenshot → verify dialog dismissed

### Wait for loading
If a screenshot shows a spinner or loading state:
1. `sleep 2`
2. Screenshot again
3. Repeat up to 5 times (10 seconds total)
4. If still loading → inform user and ask whether to keep waiting

### Scroll
```bash
# Scroll down
{baseDir}/scripts/desktop-control cliclick kd:none kp:page-down ku:none
# or use AppleScript for precise scrolling:
osascript -e 'tell application "System Events" to scroll area 1 of front window of first application process whose frontmost is true by 3'
```

If the target element is not visible in the screenshot, try scrolling down and taking another screenshot.

### Handle stuck dialogs/modals
If a dialog won't close:
1. Try `kp:esc` multiple times
2. Try clicking outside the dialog (dimmed area)
3. Try `kp:return` (might accept default action)
4. If still stuck: ask user to manually close, OR quit and reopen the app:
   ```bash
   osascript -e 'tell application "APP_NAME" to quit'
   sleep 1
   osascript -e 'tell application "APP_NAME" to activate'
   ```
5. **Prevention:** Before clicking, verify coordinates are in the intended area (chat list vs sidebar icons vs other UI regions)

## WhatsApp Desktop

### Read unread messages
1. Activate WhatsApp: `osascript -e 'tell application "WhatsApp" to activate'`
2. Screenshot → identify the chat list on the left
3. Look for: bold names, green badge numbers = unread
4. Report unread chats to user

### Open a specific chat
**IMPORTANT:** WhatsApp has multiple clickable regions that can trigger unintended actions:
- Left sidebar icons (Chats, Calls, Status, etc.) — y < 100 on Retina/2
- Search bar — y ≈ 55-60
- Chat list — y > 100, x < 200

Steps:
1. Screenshot → locate the chat row
2. Calculate y-coordinate: first chat row starts around y=74 (screen coords), each row ~32px tall
3. **Verify x-coordinate is within chat list** (x ≈ 100-180), NOT on sidebar icons (x < 40)
4. Click on the chat row
5. Screenshot → verify correct chat opened (check header name)
6. If wrong view (Calls, Status): click Chats icon at top of sidebar (x≈17, y≈42)

### Navigate back to Chats from Calls view
1. Click the chat bubble icon in left sidebar (x≈17, y≈85 on Retina/2)
2. If a dialog blocks: try Esc, click outside, or quit/reopen app

### Error recovery
If accidentally opened a dialog or wrong view:
1. Press Escape multiple times
2. Click the Chats icon (top of left sidebar, has badge count)
3. If still stuck: ask user to close dialog manually

## Lessons Learned (2026-02-06)

### Coordinate precision matters
- Retina displays: divide image coordinates by scale factor (usually 2)
- Small UI elements (sidebar icons ~30px wide) are easy to miss
- Verify click landed correctly with immediate screenshot

### WhatsApp-specific gotchas
- Sidebar icons are very close to chat list — easy to accidentally click Calls instead of a chat
- "Create call link" dialog is modal and blocks all navigation
- Search box is at y≈55, clicking there focuses search instead of selecting chat
- Arrow keys navigate within current view, not across views
