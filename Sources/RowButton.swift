import SwiftUI

struct RowButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(hovering ? Color.gray.opacity(0.15) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering = $0 }
    }
}
