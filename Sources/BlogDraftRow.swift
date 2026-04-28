import SwiftUI

struct BlogDraftRow: View {
    let draft: BlogDraft
    let onOpen: () -> Void
    let onArchive: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text("\(draft.ageDays)d")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(draft.ageDays > 30 ? .red : .orange)
                .frame(width: 56, alignment: .leading)

            // Clickable name area — opens the file
            Button(action: onOpen) {
                Text(draft.name)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Archive icon — only visible on hover, separate click target
            Button(action: onArchive) {
                Image(systemName: "archivebox")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .help("Archive — move to ~/.claude/.../archive/blog-drafts/")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(hovering ? Color.gray.opacity(0.15) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering = $0 }
    }
}
