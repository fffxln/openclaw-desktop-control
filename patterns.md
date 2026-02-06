# Common Patterns

App-specific recipes for the desktop-control skill. Each pattern describes the vision-action steps for a common workflow.

## Keyboard-First Navigation Guide

Prefer these keyboard approaches over coordinate clicking. They eliminate misclick risk entirely.

### Universal Shortcuts (work in most macOS apps)
| Action | Shortcut | Use instead of... |
|---|---|---|
| Open Spotlight / app launcher | Cmd+Space | Clicking Dock icons |
| Switch to app | Cmd+Tab | Clicking Dock/window |
| Close window/modal | Cmd+W or Escape | Clicking close button |
| Undo last action | Cmd+Z | Panicking after misclick |
| Focus address bar (browsers) | Cmd+L | Clicking URL bar |
| Open preferences | Cmd+, | Clicking menu > Preferences |
| Find/search in page | Cmd+F | Scrolling to find element |
| Save | Cmd+S | Clicking File > Save |
| Select all text in field | Cmd+A | Triple-clicking |
| Submit/confirm | Return or Cmd+Enter | Clicking OK/Submit/Post buttons |
| Cancel/dismiss | Escape | Clicking Cancel or close button |
| Tab to next field | Tab | Clicking next form field |
| Activate button in focus | Space or Return | Clicking the button |

### App-Specific Keyboard Paths

#### WhatsApp Desktop
| Action | Keyboard path | Avoids |
|---|---|---|
| Search for chat | Cmd+F → type name → Arrow Down → Enter | Clicking in chat list (risk: Calls/Status icons) |
| New message | Cmd+N | Clicking new chat icon |
| Close search | Escape | Clicking X button on search |
| Scroll through chats | Arrow Up/Down when chat list is focused | Clicking individual chat rows |

#### Twitter / X (in browser)
| Action | Keyboard path | Avoids |
|---|---|---|
| New tweet/post | N key (when not in text field) | Clicking compose button |
| Submit post | Cmd+Enter (in compose modal) | Clicking Post button (coordinate-sensitive) |
| Close modal | Escape | Clicking outside modal (risky) |
| Navigate feed | J/K keys | Scrolling and clicking tweets |
| Like tweet | L key (when tweet selected via J/K) | Clicking heart icon |

#### Browsers (Chrome/Safari/Arc)
| Action | Keyboard path | Avoids |
|---|---|---|
| Open URL | Cmd+L → type URL → Enter | Clicking address bar |
| New tab | Cmd+T | Clicking + button |
| Close tab | Cmd+W | Clicking X on tab |
| Switch tab | Cmd+Shift+[ or ] | Clicking tab |
| Back | Cmd+[ | Clicking back button |
| Refresh | Cmd+R | Clicking refresh button |

#### Figma
| Action | Keyboard path | Avoids |
|---|---|---|
| Quick actions / search | Cmd+/ | Navigating menus |
| Export selection | Cmd+Shift+E | Clicking through export panel |
| Zoom to fit | Cmd+1 | Clicking zoom controls |
| Search layers | Cmd+F | Scrolling layer panel |

#### Finder
| Action | Keyboard path | Avoids |
|---|---|---|
| Go to folder | Cmd+Shift+G → type path → Enter | Clicking through folder hierarchy |
| Search | Cmd+F | Clicking search bar |
| Rename selected | Enter (when file selected) | Right-click > Rename |
| Open selected | Cmd+O | Double-clicking file |

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

## Twitter / X (browser)

### CRITICAL: Use keyboard shortcuts for posting
Clicking the Post button is unreliable due to coordinate imprecision and modal positioning variability. Prefer Cmd+Enter.

### Post a tweet
1. Activate browser, navigate to twitter.com/x.com: `Cmd+L` → type URL → Enter
2. Wait for page load, screenshot → verify Twitter/X is loaded
3. Press Escape to ensure no text field is focused, then press `N` key to open compose modal
4. Screenshot → verify compose modal is open
5. Type the tweet content
6. Screenshot → verify text appears correctly
7. Press Cmd+Enter to post
8. Screenshot → verify the post was submitted (modal should close, or "Your post was sent" confirmation)
9. If modal is still open: try Cmd+Enter again
10. After 3 failed Cmd+Enter attempts: Recovery Protocol Level 4 (ask user to post manually)

### Reply to a tweet
1. Use J/K keys to navigate to the target tweet
2. Press R to open reply compose
3. Type reply text
4. Cmd+Enter to submit
5. Screenshot → verify

### Like a tweet
1. Use J/K to navigate to target tweet
2. Press L to like
3. Screenshot → verify heart icon is filled/red

### Posting failure recovery
If compose modal closes unexpectedly:
1. Screenshot → check current state
2. If draft was saved: look for "Drafts" in the sidebar
3. If draft was lost: press N to recompose, retype content
4. After 3 total compose failures: Recovery Protocol Level 4 (ask user)

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
Follow the Recovery Protocol from SKILL.md Step 5.5:
1. **Level 1 — Soft:** Press Escape (up to 3 times, 0.5s between). Try Cmd+W. Try Cmd+Z.
2. **Level 2 — Navigation:** Try Cmd+[ (back). Try app-specific recovery from the app's section above.
3. **Level 3 — App Reset:** Quit and reopen:
   ```bash
   osascript -e 'tell application "APP_NAME" to quit'
   sleep 2
   osascript -e 'tell application "APP_NAME" to activate'
   ```
4. **Level 4 — User Escalation:** Ask user to manually intervene. Provide screenshot and description.

**Prevention is better than recovery:**
- Always complete Step 3.5 (Validate Coordinates) before clicking
- Check Danger Zones in SKILL.md for the current app
- Prefer keyboard shortcuts over clicking — see Keyboard-First Navigation Guide above

## WhatsApp Desktop

### CRITICAL: Navigation Safety
WhatsApp's sidebar has densely packed icons that are extremely close to the chat list. The risk of misclicking Calls, Status, or other sidebar icons instead of a chat row is HIGH. See Danger Zones in SKILL.md.

**Preferred approach: Use Cmd+F search to open chats instead of clicking chat rows.**

### Open a specific chat (SAFE method — use this)
1. Activate WhatsApp: `osascript -e 'tell application "WhatsApp" to activate'`
2. Press Cmd+F to open search
3. Type the contact or group name
4. Wait 0.5s for results to populate
5. Press Arrow Down to select the first matching result
6. Press Enter to open the chat
7. Screenshot → verify correct chat opened (check header name)

### Open a specific chat (FALLBACK — only if search fails)
**IMPORTANT:** WhatsApp has multiple clickable regions that can trigger unintended actions:
- Left sidebar icons (Chats, Calls, Status, etc.) — y < 100 on Retina/2
- Search bar — y ≈ 55-60
- Chat list — y > 100, x < 200

Steps:
1. Screenshot → locate the chat row
2. Calculate y-coordinate: first chat row starts around y=74 (screen coords), each row ~32px tall
3. **Verify x-coordinate is within chat list** (x ≈ 100-180), NOT on sidebar icons (x < 40)
4. Run Step 3.5 Validation — compute distance to Calls icon and Status icon
5. Click on the chat row
6. Screenshot → verify correct chat opened (check header name)
7. If wrong view (Calls, Status): use recovery protocol below

### Read unread messages
1. Activate WhatsApp: `osascript -e 'tell application "WhatsApp" to activate'`
2. Screenshot → identify the chat list on the left
3. Look for: bold names, green badge numbers = unread
4. Report unread chats to user

### Navigate back to Chats from wrong view
1. Press Escape (may close any open dialog/modal)
2. Use Cmd+F to open search (this also forces the Chats view)
3. Press Escape to close search — you should now be in Chats view
4. Screenshot → verify
5. If still stuck: Recovery Protocol Level 3 (quit/reopen app)

### Error recovery
If accidentally opened a dialog or wrong view:
1. Press Escape (up to 3 times)
2. Try Cmd+F then Escape (forces back to Chats view)
3. If still stuck: Recovery Protocol Level 3 (quit/reopen)
4. If still stuck: Recovery Protocol Level 4 (ask user)

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

### Twitter/X posting failures
**What we tried and why it failed:**

1. **bird CLI**: Returned "success" but tweet never appeared (silent rejection/rate limit)
2. **Desktop control clicks**: Post button coordinates kept missing — modal closed or saved as draft
3. **Browser tool (CDP)**: OpenClaw's managed browser wasn't logged into X
4. **Safari JavaScript injection**: Blocked by default ("Allow JavaScript from Apple Events" disabled)

**Root causes:**
- Modal dialogs have variable positioning based on window size/state
- Vision model coordinate estimates can be off by 10-30px
- Clicking near modal edges triggers close/dismiss instead of button click
- Twitter's Post button may have padding that makes clickable area smaller than visible button

**Preferred: Use Cmd+Enter to submit posts instead of clicking the Post button.** See the Twitter / X (browser) pattern above.

### General modal/dialog issues
- Modals often have invisible overlay areas that close them when clicked
- Button coordinates from vision can be unreliable — off by 10-30px
- Always screenshot → verify → click → screenshot → verify
- If modal keeps closing: use keyboard shortcuts (Cmd+Enter, Return, Escape)
- **When near a modal edge, prefer keyboard interaction over clicking**
- For structured recovery, follow Recovery Protocol in SKILL.md Step 5.5

### The keyboard-first principle
- Every misclick failure we experienced could have been avoided with keyboard shortcuts
- Clicking should be the LAST resort, not the default action
- Before clicking any element, always ask: "Is there a keyboard shortcut for this?"
- Search-based navigation (Cmd+F, Cmd+K, Spotlight) is more reliable than coordinate clicking
- See the Keyboard-First Navigation Guide at the top of this file

---

## WhatsApp Navigation Deep Dive (2026-02-06 Session 2)

### Task: Open a contact's chat (6 unread messages)

### Methods attempted and results

| Method | Result | Why it failed |
|--------|--------|---------------|
| Direct coordinate click (y=330) | Clicked wrong area | Vision estimate off by 50+ px |
| Direct coordinate click (y=350) | Still wrong | Coordinates inconsistent |
| Arrow key navigation (8x down) | Opened wrong chat | Arrow keys don't navigate predictably |
| Cmd+F search "Contact Name" | ✅ Search worked! | — |
| Click search result (y=97) | Did not open chat | Click didn't register |
| Click search result (y=98) | Did not open chat | Click didn't register |
| Click search result (x=80, y=98) | Did not open chat | Previous chat stayed open |
| Double-click search result | Did not open chat | Still no response |
| Tab + Enter from search | Opened profile view, not chat | Enter shows profile, not messages |
| Click search result (x=100, y=98) | Did not open chat | 6+ attempts, all failed |

### Vision model accuracy assessment

**What vision correctly identified:**
- ✅ Which chat was currently open (a group chat)
- ✅ Target contact in search results with 6 unread badge
- ✅ General layout (search box, results sections, main panel)
- ✅ Text content in messages

**What vision got wrong or couldn't help with:**
- ❌ Coordinate estimates varied by 10-50px between analyses
- ❌ Couldn't determine why clicks weren't registering
- ❌ Couldn't identify if left panel had focus vs right panel
- ❌ Search results section has different click behavior than regular chat list

### Key insight: Search results ≠ Chat list

WhatsApp's search results view appears to have different click handling:
- Clicking a search result might need to target a specific element (not just the row)
- Tab+Enter opens profile view, not chat
- May need to click "Message" button or specific area

**Needs investigation:**
- What exactly is clickable in search results?
- Is there a "Message" or "Open chat" button in search results?
- Does WhatsApp need the result to be "selected" (highlighted) before Enter works?

### Token cost

~20 screenshots + vision calls for failed navigation = estimated 15-20k tokens wasted.

### Recommendation

**Fail fast rule:** If 3 coordinate click attempts fail on the same target, STOP and:
1. Try a completely different approach (keyboard, different UI path)
2. If that fails, ask user to click manually
3. Document what was tried for future improvement

Don't burn tokens repeating the same failed approach.
