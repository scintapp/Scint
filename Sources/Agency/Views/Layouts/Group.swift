import AgencyRuntime
import SwiftUI


struct GroupDivider: View { var body: some View { Divider().padding(.horizontal, 8) } }

struct GroupToggle: View {
    @State private var isOn: Bool
    let onChange: () -> Void

    init(isOn: Bool, onChange: @escaping () -> Void) {
        _isOn = State(initialValue: isOn)
        self.onChange = onChange
    }

    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(.switch)
            .scaleEffect(0.8)
            .onChange(of: isOn) { _, _ in onChange() }
    }
}

struct GroupCountButton: View {
    let count: Int?
    let onLoad: () -> Void

    var body: some View {
        HStack {
            if let count {
                Text(count == 0 ? "None" : count == 1 ? "1 Loaded" : "\(count) Loaded")
                    .font(.system(size: 12))
                    .foregroundStyle(count == 0 ? .tertiary : .secondary)
            }
            Button("Load", action: onLoad)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct GroupPickerItem: Identifiable {
    let id: AnyHashable
    let name: String
    let image: String
    let ref: Reference?
    let active: Bool
}

struct GroupPicker: View {
    let items: [GroupPickerItem]
    let onPick: (AnyHashable) -> Void

    var body: some View {
        Group {
            if items.isEmpty {
                EditorMenuEmptyState(title: "Nothing in library", width: 260, height: 120)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(items) { candidate in
                            Button { onPick(candidate.id) } label: {
                                HStack {
                                    editorMenuIcon(icon: candidate.image, selected: candidate.active, ref: candidate.ref)
                                    Text(candidate.name)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.primary.opacity(0.86))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    if candidate.active {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                }
                .frame(width: 260, height: min(CGFloat(items.count) * 40, 320), alignment: .center)
            }
        }
    }
}

struct GroupLoader: View {
    @State private var presented = false
    let count: Int?
    let items: [GroupPickerItem]
    let onPick: (AnyHashable) -> Void

    var body: some View {
        GroupCountButton(count: count) { presented = true }
            .popover(isPresented: $presented) {
                GroupPicker(items: items) { id in
                    onPick(id)
                    presented = false
                }
            }
    }
}

struct GroupHeader: View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    let ref: Reference?
    let title: String
    let description: String

    init(ref: Reference? = nil, title: String, description: String) {
        self.ref = ref
        self.title = title
        self.description = description
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                if let ref {
                    Iconography.icon(for: ref, size: 28)
                        .padding(.trailing, 6)
                }
                Text(title)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.9))
            }
            .frame(maxHeight: 64)
            .padding(.vertical, 12)
            Divider()
            Text(description.isEmpty ? "No description." : description)
                    .padding(.bottom, 12)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        description.isEmpty ?
                        Design.Foreground.tertiary :
                        Design.Foreground.secondary
                    )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(shape.fill(.primary.opacity(0.08)))
        .overlay(shape.stroke(.primary.opacity(0.03), lineWidth: 1))
    }
}

struct GroupRow<Leading: View, Trailing: View>: View {
    let label: String
    let description: String
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    init(
        label: String,
        description: String = "",
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.label = label
        self.description = description
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center) {
            leading
                .frame(width: 38, height: description.isEmpty ? 38 : 50)
                .foregroundStyle(.tertiary)
                .font(.system(size: 15, weight: .medium))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineLimit(1)

                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.72))
                        .lineLimit(1)
                }
            }
            .frame(height: description.isEmpty ? 38 : 50, alignment: .center)

            Spacer()

            trailing
                .frame(height: description.isEmpty ? 38 : 50)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(height: description.isEmpty ? 38 : 50, alignment: .center)
        .padding(.horizontal, 8)
    }
}

struct GroupLayout<Content: View>: View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    let title: String
    let footer: String?
    @ViewBuilder let content: () -> Content

    init(title: String, footer: String?, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack {
            Text(title)
                .padding(.leading, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.75))

            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(shape.fill(.primary.opacity(0.08)))
            .overlay(shape.stroke(.primary.opacity(0.03), lineWidth: 1))

            if let footer {
                Text(footer)
                    .padding(.leading, 4)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
    }
}
