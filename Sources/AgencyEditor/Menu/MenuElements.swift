import SwiftUI


enum EditorMenuFocus: Hashable {
    case library
    case formPrimary
    case formSecondary
}

struct EditorMenuEmptyState: View {
    let title: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(.quaternary)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(width: width, height: height)
    }
}

struct EditorMenuIconTile: View {
    let icon: String
    let selected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.white.opacity(0.16) : Color.white.opacity(0.07))
                .frame(width: 26, height: 26)
            Image(systemName: icon.isEmpty ? "square.stack.3d.up" : icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? .white : .primary.opacity(0.78))
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
