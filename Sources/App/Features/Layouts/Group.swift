import AgencyRuntime
import SwiftUI


struct LoadAccessory: View {
    let item: ItemParams
    let controls: Controls
    @State private var presented = false

    var body: some View {
        GroupCountButton(count: item.count) {
            presented = true
        }
        .popover(isPresented: $presented) {
            LoadPicker(items: item.items) { candidate in
                controls.onSelect?(candidate)
                presented = false
            }
        }
    }
}

struct LoadPicker: View {
    let items: [ItemParams]
    let onPick: (ItemParams) -> Void

    var body: some View {
        Group {
            if items.isEmpty {
                EditorMenuEmptyState(title: "Nothing in library", width: 260, height: 120)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(items) { candidate in
                            Button { onPick(candidate) } label: {
                                HStack(spacing: 10) {
                                    EditorMenuIconTile(icon: candidate.image, selected: candidate.active, ref: candidate.ref)
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

struct GroupToggle: View {
    let isOn: Bool
    let onChange: () -> Void
    @State private var localState: Bool

    init(isOn: Bool, onChange: @escaping () -> Void) {
        self.isOn = isOn
        self.onChange = onChange
        self._localState = State(initialValue: isOn)
    }

    var body: some View {
        Toggle("", isOn: $localState)
            .toggleStyle(.switch)
            .scaleEffect(0.8)
            .onChange(of: localState) { _, _ in onChange() }
    }
}

struct GroupDivider: View {
    var body: some View {
        Divider().padding(.horizontal, 8)
    }
}

struct GroupCountButton: View {
    let count: Int?
    let onLoad: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            let n = count ?? 0
            Text(n == 0 ? "None" : n == 1 ? "1 Loaded" : "\(n) Loaded")
                .font(.system(size: 12))
                .foregroundStyle(n == 0 ? .tertiary : .secondary)
            Button("Load", action: onLoad)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct GroupHeader: View {
    @Environment(AgencyModel.self) var agency
    var ref: Reference { agency.session.selected.structure ?? agency.session.workspace }
    var title: String { Runtime.shared.get(ref).name }
    var description: String { Runtime.shared.get(ref).description }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.isEmpty ? "Some Space" : title)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .padding(.horizontal, 12)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(title.isEmpty ? Color.primary.opacity(0.5) : Color.primary.opacity(0.9))

            GroupDivider()

            Text(description.isEmpty ? "Description" : description)
                .padding(.bottom, 2)
                .padding(.horizontal, 12)
                .font(.system(size: 12))
                .foregroundStyle(description.isEmpty ? Color.secondary.opacity(0.5) : Color.secondary.opacity(1.0))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.bottom, 8)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.primary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.primary.opacity(0.03), lineWidth: 1)
        }
    }
}

struct GroupRow<Leading: View, Trailing: View>: View {
    let label: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            leading
                .frame(width: 28, height: 28)
                .foregroundStyle(.tertiary)
                .font(.system(size: 15, weight: .medium))


            Text(label)
                .frame(height: 28)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            Spacer()

            trailing
                .frame(height: 28)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(height: 28, alignment: .center)
        .padding(.horizontal, 8)
    }
}

struct GroupLayout<Content: View>: View {
    var title: String
    var footnote: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack {
            Text(title)
                .padding(.leading, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.75))

            VStack {
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.primary.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.primary.opacity(0.03), lineWidth: 1)
            }

            Text(footnote)
                .padding(.leading, 4)
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(.secondary.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
