# Home Companion — Setup Guide

A native macOS menu-bar app that surfaces today's calendar, in-progress
KAN tickets, GitHub PRs awaiting review, stale blog drafts, and personal
deadlines — all in one click.

> Source: https://github.com/carlfung1003/home-companion

---

## Prerequisites

| Tool | How to get |
|------|------------|
| **macOS** 13+ (Ventura) | — |
| **Xcode** 14+ | Mac App Store |
| **xcodegen** | `brew install xcodegen` |
| **gcalcli** | `brew install gcalcli` |
| **gh** | `brew install gh` (then `gh auth login`) |
| **Jira API token** | https://id.atlassian.com/manage-profile/security/api-tokens |

---

## Setup

### 1. Clone

```bash
git clone https://github.com/carlfung1003/home-companion.git ~/home-companion
cd ~/home-companion
```

### 2. Authorize gcalcli

gcalcli needs a Google OAuth client (Desktop type) you create yourself:

1. Go to https://console.cloud.google.com/auth/clients in any GCP project you own
2. **Create client** → Application type **Desktop app** → name "gcalcli"
3. Copy the Client ID + Client Secret
4. Run `gcalcli list` — it prompts for both, then opens a browser for the OAuth grant
5. Verify: `gcalcli agenda --tsv` should print your events

If your OAuth consent screen is in **Testing** mode, add your Google account
as a test user under https://console.cloud.google.com/auth/audience.

### 3. Configure Jira credentials

```bash
mkdir -p ~/.config/home-companion
cat > ~/.config/home-companion/jira.env <<'EOF'
JIRA_EMAIL=you@example.com
JIRA_TOKEN=PASTE_YOUR_TOKEN_HERE
JIRA_HOST=youraccount.atlassian.net
EOF
chmod 600 ~/.config/home-companion/jira.env
```

Edit and replace placeholders.

### 4. Customize per-user values

Two files have hardcoded defaults pointing at Carl's setup:

**`Sources/CalendarStore.swift`** — change `calendarName` to your primary
Google Calendar.

**`Sources/BlogDraftsStore.swift`** — change `inboxURL` to wherever you
keep markdown drafts. Threshold defaults to 7 days; bump if too noisy.

**`Sources/JiraStore.swift`** — adjust the JQL filter if you want
something other than "my in-progress tickets."

### 5. Optional: seed deadlines

`~/.config/home-companion/deadlines.txt` is auto-seeded on first run with
Carl's deadlines (inKind, Marriott, CA property tax). Edit it to taste.
Format:

```
# YYYY-MM-DD | Label | optional URL
2026-04-30 | inKind $50 credit expires
2026-06-01 | Marriott Bonvoy spend deadline | https://...
```

### 6. Generate Xcode project + build

```bash
cd ~/home-companion
xcodegen generate
open HomeCompanion.xcodeproj
```

In Xcode: select **HomeCompanion** scheme, press **⌘R**. A 🏠 icon
appears in the menu bar (may be hidden if your bar is full — ⌘-drag
other icons left to make room).

---

## Iterating

- Change Swift files → **⌘R** in Xcode
- Add a new source file → run `xcodegen generate`, then ⌘R
- Auto-refreshes every 5 minutes while popover is open; manual refresh via 🔄

---

## Adding a new section

Pattern (each existing section is 30–80 lines end-to-end):

1. Create `Sources/FooItem.swift` — `Identifiable & Hashable` model
2. Create `Sources/FooStore.swift` — `@MainActor` `ObservableObject` with
   `@Published var items`, `@Published var error: String?`,
   `func refresh() async`
3. In `MenuContentView.swift`:
   - Add `@StateObject private var foo = FooStore()`
   - Add a `section(title:..., systemImage:...) { fooContent }` call in `body`
   - Add a `@ViewBuilder private var fooContent: some View` that renders
     `RowButton`s
   - Add `await foo.refresh()` to the `refreshAll()` task group

---

## Troubleshooting

**`HTTP 410` on KAN section** — Atlassian retired the legacy `/rest/api/3/search`
endpoint. This app uses the new `/rest/api/3/search/jql` (POST). If you
forked an older version, update.

**`HTTP 401` on KAN section** — token wrong/expired. Regenerate at
https://id.atlassian.com/manage-profile/security/api-tokens.

**`gcalcli` errors** — most often expired auth. Run `gcalcli list` to
re-trigger the flow.

**🏠 icon not visible** — menu bar is full. ⌘-drag other icons off, or
install [Hidden Bar](https://apps.apple.com/us/app/hidden-bar/id1452453066).

**Build fails: code signing** — in **Signing & Capabilities**, set Team
to your Apple ID. No paid developer account needed for local-only use.
