# Home Companion

A native macOS menu-bar app that surfaces what needs my attention today —
calendar, in-progress KAN tickets, GitHub PRs awaiting review, stale blog
drafts, and personal deadlines — all in one click.

Inspired by [tpm-companion](https://github.com/carlfung1003/tpm-companion)
(my work version), reshaped for personal/dev life.

## Sections

- **Today's calendar** — remaining timed events for today (via `gcalcli`)
- **KAN — In Progress** — Jira tickets I'm actively working on (via Jira REST)
- **PRs awaiting review** — GitHub PRs where I'm a requested reviewer (via `gh`)
- **Stale blog drafts** — markdown files in my Claude memory blog inbox older than 7 days
- **Deadlines** — countdowns from a hand-edited `~/.config/home-companion/deadlines.txt`

Every row is clickable. Auto-refreshes every 5 minutes while the popover is open;
manual refresh via the 🔄 icon.

## Setup

See [SETUP.md](SETUP.md).

## Architecture

Each section is one Swift file pair:

- `FooItem.swift` — model
- `FooStore.swift` — `@MainActor` `ObservableObject` with `refresh() async`
- A `@ViewBuilder` block in `MenuContentView.swift`

To add a new section, copy the pattern from any existing one (each is 30–80 lines).

## Stack

- SwiftUI + `MenuBarExtra` (macOS 13+)
- `xcodegen` for Xcode project generation (the `.xcodeproj` is gitignored)
- Shells out to `gcalcli` and `gh` for OAuth-heavy data sources
- Direct REST for Jira (Basic auth, token in `~/.config/home-companion/jira.env`)
