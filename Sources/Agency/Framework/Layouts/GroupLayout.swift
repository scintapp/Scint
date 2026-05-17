import AgencyRuntime
import SwiftUI


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
    let ref: Reference

    var body: some View {
        let title = Boundary.with(ref) { $0.name } ?? "Boundary"
        let description = Boundary.with(ref) { $0.description }


        VStack(alignment: .leading) {
            Text(title)
                .padding(.horizontal, 10)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.primary)
            GroupDivider()
            if ((description?.isEmpty) != nil) {
                Text("Description")
                    .padding(.horizontal, 10)
                    .padding(.bottom, 2)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.tertiary).opacity(0.8)
            } else {
                Text(description!)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }



        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thickMaterial)
        }
    }
}

struct GroupDivider: View {
    var body: some View {
        Divider().padding(.horizontal, 8)
    }
}

struct GroupRowUnavailable: View {
    let label: String
    let icon: String

    var body: some View {
        GroupRow(label: label) { Image(systemName: icon) } trailing: {
            Text("Unavailable")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }
}

struct GroupRow<Leading: View, Trailing: View>: View {
    let label: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            leading
                .foregroundStyle(.tertiary)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 24, height: 24, alignment: .center)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .frame(alignment: .center)
            Spacer()
            trailing
                .labelsHidden()
                .controlSize(.small)
                .frame(alignment: .center)
        }
        .frame(height: 28)
        .padding(.leading, 8)
        .padding(.trailing, 12)
    }
}

struct GroupLayout<Content: View>: View {
    var title: String
    var footnote: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack {
            Text(title)
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
