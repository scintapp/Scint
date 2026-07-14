import SwiftUI


struct TableRow<Leading: View>: View {
    let title: String
    let summary: String
    let time: String?
    let status: String?
    let count: Int?
    let trailingImage: String?
    let focused: Bool
    let onSelect: () -> Void
    let leading: Leading

    init(
        title: String,
        summary: String,
        time: String?,
        status: String?,
        count: Int?,
        trailingImage: String?,
        focused: Bool,
        onSelect: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self.summary = summary
        self.time = time
        self.status = status
        self.count = count
        self.trailingImage = trailingImage
        self.focused = focused
        self.onSelect = onSelect
        self.leading = leading()
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center) {
                leading
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 12)

                if let time {
                    Text(time)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if let status {
                    Text(status)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }

                if let count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if let trailingImage {
                    Image(systemName: trailingImage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(focused ? Design.Tint.active.opacity(0.12) : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct TableLayout<Content: View>: View {
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

