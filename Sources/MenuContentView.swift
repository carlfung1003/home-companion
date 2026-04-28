import SwiftUI
import AppKit

struct MenuContentView: View {
    @StateObject private var calendar = CalendarStore()
    @StateObject private var jira = JiraStore()
    @StateObject private var prs = PullRequestStore()
    @StateObject private var blog = BlogDraftsStore()
    @StateObject private var deadlines = DeadlineStore()
    @StateObject private var vercel = VercelStore()
    @StateObject private var oura = OuraStore()
    @StateObject private var workflows = WorkflowStore()
    @StateObject private var turso = TursoStore()
    @StateObject private var bookmarks = BookmarksStore()
    @StateObject private var tiger = TigerStore()

    @State private var lastRefresh = Date()
    private let refreshInterval: TimeInterval = 300  // 5 minutes

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    // LEFT — Personal / Life
                    VStack(alignment: .leading, spacing: 0) {
                        section(title: "Today's calendar", systemImage: "calendar") {
                            calendarContent
                        }
                        section(title: "Oura readiness", systemImage: "heart.fill") {
                            ouraContent
                        }
                        section(title: "Deadlines", systemImage: "clock.badge.exclamationmark") {
                            deadlineContent
                        }
                        section(title: "Stale blog drafts", systemImage: "doc.text") {
                            blogContent
                        }
                    }
                    .frame(width: 310)

                    Divider()

                    // RIGHT — Code / Dev
                    VStack(alignment: .leading, spacing: 0) {
                        section(title: "KAN — In Progress", systemImage: "kanban") {
                            jiraContent
                        }
                        section(title: "PRs awaiting review", systemImage: "arrow.triangle.pull") {
                            prContent
                        }
                        section(title: "Vercel deploys", systemImage: "triangle.fill") {
                            vercelContent
                        }
                        section(title: "GitHub Actions failures", systemImage: "xmark.octagon") {
                            workflowContent
                        }
                        section(title: "Turso DB usage", systemImage: "cylinder.split.1x2") {
                            tursoContent
                        }
                        section(title: "API billing", systemImage: "dollarsign.circle") {
                            bookmarksContent
                        }
                    }
                    .frame(width: 310)

                    Divider()

                    // THIRD — Tiger
                    VStack(alignment: .leading, spacing: 0) {
                        section(title: "Tiger requests", systemImage: "tray.full") {
                            tigerRequestsContent
                        }
                        section(title: "Tiger heartbeat (VPS)", systemImage: "waveform.path.ecg") {
                            tigerHeartbeatContent
                        }
                    }
                    .frame(width: 310)
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 960, height: 600)
        .background(.regularMaterial)
        .task {
            await refreshAll()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
                if Task.isCancelled { break }
                await refreshAll()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Home Companion")
                .font(.headline)
            Spacer()
            Text(lastRefreshLabel)
                .font(.caption2)
                .foregroundColor(.secondary)
            Button {
                Task { await refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.08))
    }

    private var lastRefreshLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "↻ \(f.string(from: lastRefresh).lowercased())"
    }

    // MARK: - Section helper

    @ViewBuilder
    private func section<Content: View>(title: String, systemImage: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            content()
        }
    }

    // MARK: - Calendar

    @ViewBuilder
    private var calendarContent: some View {
        if let err = calendar.error {
            errorRow(err)
        } else if calendar.events.isEmpty && !calendar.loading {
            emptyRow("No more events today")
        } else {
            ForEach(calendar.events) { event in
                RowButton {
                    NSWorkspace.shared.open(URL(string: "https://calendar.google.com/calendar/u/0/r/day")!)
                } label: {
                    HStack {
                        Text(event.timeLabel)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 56, alignment: .leading)
                        Text(event.title)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Oura

    @ViewBuilder
    private var ouraContent: some View {
        if let err = oura.error {
            errorRow(err)
        } else if oura.readiness == nil && !oura.loading {
            emptyRow("No data")
        } else if let r = oura.readiness {
            RowButton {
                NSWorkspace.shared.open(URL(string: "https://cloud.ouraring.com")!)
            } label: {
                HStack {
                    Text("\(r.score)")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundColor(scoreColor(r.color))
                        .frame(width: 56, alignment: .leading)
                    Text(r.label)
                        .lineLimit(1)
                    Spacer()
                    Text(r.day)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func scoreColor(_ c: OuraReadiness.ScoreColor) -> Color {
        switch c {
        case .green:  return .green
        case .yellow: return .orange
        case .red:    return .red
        }
    }

    // MARK: - Jira

    @ViewBuilder
    private var jiraContent: some View {
        if let err = jira.error {
            errorRow(err)
        } else if jira.tickets.isEmpty && !jira.loading {
            emptyRow("No tickets in progress")
        } else {
            ForEach(jira.tickets) { ticket in
                RowButton {
                    if let url = ticket.browseURL { NSWorkspace.shared.open(url) }
                } label: {
                    HStack {
                        Text(ticket.id)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .frame(width: 56, alignment: .leading)
                        Text(ticket.summary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - PRs

    @ViewBuilder
    private var prContent: some View {
        if let err = prs.error {
            errorRow(err)
        } else if prs.prs.isEmpty && !prs.loading {
            emptyRow("Inbox zero")
        } else {
            ForEach(prs.prs) { pr in
                RowButton {
                    NSWorkspace.shared.open(pr.url)
                } label: {
                    HStack {
                        Text("#\(pr.number)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .frame(width: 56, alignment: .leading)
                        VStack(alignment: .leading) {
                            Text(pr.title).lineLimit(1)
                            Text(pr.repo).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - GitHub Actions

    @ViewBuilder
    private var workflowContent: some View {
        if let err = workflows.error {
            errorRow(err)
        } else if workflows.runs.isEmpty && !workflows.loading {
            emptyRow("No recent failures")
        } else {
            ForEach(workflows.runs) { run in
                RowButton {
                    NSWorkspace.shared.open(run.url)
                } label: {
                    HStack {
                        Text(run.repo)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.red)
                            .frame(width: 80, alignment: .leading)
                            .lineLimit(1)
                        Text(run.workflow)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Vercel

    @ViewBuilder
    private var vercelContent: some View {
        if let err = vercel.error {
            errorRow(err)
        } else if vercel.deployments.isEmpty && !vercel.loading {
            emptyRow("All green")
        } else {
            ForEach(vercel.deployments) { d in
                RowButton {
                    if let url = d.url { NSWorkspace.shared.open(url) }
                } label: {
                    HStack {
                        Text(d.state)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(d.isFailing ? .red : .orange)
                            .frame(width: 60, alignment: .leading)
                        Text(d.project)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Turso

    @ViewBuilder
    private var tursoContent: some View {
        if let err = turso.error {
            errorRow(err)
        } else if turso.databases.isEmpty && !turso.loading {
            emptyRow("No databases")
        } else {
            ForEach(turso.databases) { db in
                RowButton {
                    NSWorkspace.shared.open(URL(string: "https://app.turso.tech")!)
                } label: {
                    HStack {
                        Text(db.storagePercent.map { String(format: "%.1f%%", $0) } ?? "—")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor((db.storagePercent ?? 0) > 80 ? .red : .secondary)
                            .frame(width: 56, alignment: .leading)
                        Text(db.name)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Blog drafts

    @ViewBuilder
    private var blogContent: some View {
        if let err = blog.error {
            errorRow(err)
        } else if blog.drafts.isEmpty && !blog.loading {
            emptyRow("No stale drafts")
        } else {
            ForEach(blog.drafts) { draft in
                BlogDraftRow(draft: draft) {
                    NSWorkspace.shared.open(draft.id)
                } onArchive: {
                    blog.archive(draft.id)
                }
            }
        }
    }

    // MARK: - Deadlines

    @ViewBuilder
    private var deadlineContent: some View {
        if let err = deadlines.error {
            errorRow(err)
        } else if deadlines.deadlines.isEmpty && !deadlines.loading {
            emptyRow("No deadlines configured")
        } else {
            ForEach(deadlines.deadlines.prefix(8)) { d in
                RowButton {
                    if let url = d.url { NSWorkspace.shared.open(url) }
                } label: {
                    HStack {
                        Text(d.daysRemaining < 0 ? "past" : "\(d.daysRemaining)d")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(badgeColor(d.badgeColorHint))
                            .frame(width: 56, alignment: .leading)
                        Text(d.label)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Tiger requests

    @ViewBuilder
    private var tigerRequestsContent: some View {
        if let err = tiger.error {
            errorRow(err)
        } else if tiger.requests.isEmpty {
            emptyRow("No pending requests")
        } else {
            ForEach(tiger.requests) { req in
                RowButton {
                    NSWorkspace.shared.open(req.id)
                } label: {
                    HStack {
                        Text("\(req.ageDays)d")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(req.ageDays > 14 ? .red : .orange)
                            .frame(width: 56, alignment: .leading)
                        Text(req.name)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Tiger heartbeat (local sync)

    @ViewBuilder
    private var tigerHeartbeatContent: some View {
        if let err = tiger.error {
            errorRow(err)
        } else {
            let hb = tiger.heartbeat
            RowButton {
                // Click → open the vault's Tiger journal mirror (synced nightly from VPS)
                let path = ("~/.claude/projects/-Users-carlfung/memory/agents/journal/tiger" as NSString).expandingTildeInPath
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            } label: {
                HStack {
                    Text(hoursLabel(hb))
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundColor(heartbeatColor(hb.status))
                        .frame(width: 56, alignment: .leading)
                    VStack(alignment: .leading) {
                        Text(heartbeatLabel(hb))
                            .lineLimit(1)
                        if let name = hb.lastEntryName {
                            Text(name).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func hoursLabel(_ hb: TigerHeartbeat) -> String {
        guard let h = hb.hoursSince else { return "—" }
        if h < 24 { return "\(h)h" }
        return "\(h / 24)d"
    }

    private func heartbeatLabel(_ hb: TigerHeartbeat) -> String {
        switch hb.status {
        case .fresh:   return "Tiger active"
        case .warning: return "Tiger quiet (>1d)"
        case .stale:   return "Tiger silent (>3d)"
        case .missing: return "No journal data"
        }
    }

    private func heartbeatColor(_ s: TigerHeartbeat.Status) -> Color {
        switch s {
        case .fresh:   return .green
        case .warning: return .orange
        case .stale:   return .red
        case .missing: return .gray
        }
    }

    // MARK: - Bookmarks

    @ViewBuilder
    private var bookmarksContent: some View {
        if let err = bookmarks.error {
            errorRow(err)
        } else if bookmarks.bookmarks.isEmpty {
            emptyRow("No bookmarks configured")
        } else {
            ForEach(bookmarks.bookmarks) { bm in
                RowButton {
                    NSWorkspace.shared.open(bm.url)
                } label: {
                    HStack {
                        Text(bm.tag ?? "")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .frame(width: 56, alignment: .leading)
                        Text(bm.label)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func badgeColor(_ c: Deadline.BadgeColor) -> Color {
        switch c {
        case .red: return .red
        case .orange: return .orange
        case .blue: return .blue
        case .gray: return .gray
        }
    }

    // MARK: - Common rows

    private func errorRow(_ msg: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text(msg)
                .font(.caption)
                .foregroundColor(.red)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func emptyRow(_ msg: String) -> some View {
        Text(msg)
            .font(.caption)
            .foregroundColor(.primary.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Refresh

    private func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await calendar.refresh() }
            group.addTask { await jira.refresh() }
            group.addTask { await prs.refresh() }
            group.addTask { await blog.refresh() }
            group.addTask { await deadlines.refresh() }
            group.addTask { await vercel.refresh() }
            group.addTask { await oura.refresh() }
            group.addTask { await workflows.refresh() }
            group.addTask { await turso.refresh() }
            group.addTask { await bookmarks.refresh() }
            group.addTask { await tiger.refresh() }
        }
        lastRefresh = Date()
    }
}
