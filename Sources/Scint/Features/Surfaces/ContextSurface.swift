import SwiftUI


struct ContextRow: View {
    let name: String
    let detail: String
    let symbol: String
    let tint: Color

    private let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

    init(name: String, detail: String, symbol: String, tint: Color) {
        self.name = name
        self.detail = detail
        self.symbol = symbol
        self.tint = tint
    }

    init(ref: Reference, detail: String) {
        let icon = Iconography.icon(for: ref)
        self.init(name: ref.descriptor.name, detail: detail, symbol: icon.symbol, tint: icon.tint)
    }

    var body: some View {
        HStack(spacing: 10) {
            Iconography.Icon(symbol: symbol, tint: tint, sizing: 12)
                .frame(width: 28, height: 28)
                .background(shape.fill(tint.opacity(0.10)))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Design.Foreground.primary)
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Design.Foreground.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 34)
        .contentShape(Rectangle())
    }
}

struct ContextSection<Content: View>: View {
    let title: String
    let count: Int?
    @ViewBuilder let content: () -> Content

    init(_ title: String, count: Int? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.count = count
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(Typography.label)
                    .textCase(.uppercase)
                    .foregroundStyle(Design.Foreground.tertiary)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(Typography.label)
                        .foregroundStyle(Design.Foreground.disabled)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)

            content()
        }
    }
}

struct ContextSurface: Surface {
    var panel: any Panel
    var model: any Model
    static let width: CGFloat = 320
    var origin: Reference { model.session.origin }
    var context: Composition? { origin.context }

    private var latest: Reference? { context?.intentTranscript }

    private var artifacts: [Reference] {
        Space.with(origin, { $0.artifacts }) ?? Workspace.with(origin, { $0.artifacts }) ?? []
    }

    private var materials: [Reference] {
        (Space.with(origin, { $0.materials }) ?? Workspace.with(origin, { $0.materials }) ?? [])
            .filter { $0.descriptor.published != false && !$0.descriptor.tags.contains("input") }
    }

    private var spaces: [Reference] {
        let refs = Space.with(origin, { $0.spaces }) ?? Workspace.with(origin, { $0.spaces }) ?? []
        return refs
            .filter { $0.descriptor.published != false }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    private var sources: [Reference] { materials }

    private var status: String {
        switch context?.state {
            case .working: return "Running"
            case .active: return "Active"
            case .inactive: return "Idle"
            case nil: return "Ready"
        }
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ContextSection("Activity") {
                if let latest {
                    row(latest) { ContextRow(ref: latest, detail: status) }
                } else {
                    placeholder(status)
                }
            }

            if !spaces.isEmpty {
                separator

                ContextSection("Spaces", count: spaces.count) {
                    ForEach(spaces.prefix(5)) { ref in
                        row(ref) { ContextRow(ref: ref, detail: detail(for: ref)) }
                    }
                }
            }

            separator

            ContextSection("Outputs", count: artifacts.count) {
                if artifacts.isEmpty { placeholder("No generated outputs") }
                else {
                    ForEach(artifacts.prefix(5)) { ref in
                        row(ref) { ContextRow(ref: ref, detail: detail(for: ref)) }
                    }
                }
            }

            separator

            ContextSection("Sources", count: sources.count) {
                if sources.isEmpty { placeholder("No sources attached") }
                else {
                    ForEach(sources.prefix(6)) { ref in
                        row(ref) { ContextRow(ref: ref, detail: detail(for: ref)) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Context")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Design.Foreground.primary)

            Spacer(minLength: 0)

            if let harness = context?.harness {
                HStack(spacing: 5) {
                    Iconography.icon(for: harness, size: 10)
                    Text(harness.descriptor.name)
                        .font(Typography.label)
                        .lineLimit(1)
                }
                .foregroundStyle(Design.Foreground.tertiary)
            }
        }
        .padding(.horizontal, 2)
    }

    private var separator: some View {
        Rectangle()
            .fill(Design.Border.cardBorder)
            .frame(height: 0.5)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(Design.Foreground.disabled)
            .frame(minHeight: 26, alignment: .leading)
            .padding(.horizontal, 2)
    }

    private func row<Content: View>(_ ref: Reference, @ViewBuilder content: () -> Content) -> some View {
        Button { activate(ref) } label: { content() }
            .buttonStyle(.plain)
    }

    private func activate(_ ref: Reference) {
        if ref.type is Space.Type || ref.type is Workspace.Type { model.select(ref) }
        else { model.open(ref) }
    }

    private func detail(for ref: Reference) -> String {
        let description = ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty { return description }

        switch ref.type {
            case is Artifact.Type: return Artifact.with(ref, { $0.handler.directory }) == true ? "Directory" : "File"
            case is Material.Type: return "Material"
            case is Space.Type: return "Space"
            default: return ref.descriptor.name
        }
    }
}
