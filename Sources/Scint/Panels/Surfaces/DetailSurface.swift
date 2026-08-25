import SwiftUI


struct Separator: View {
    var body: some View {
        Rectangle()
            .fill(Style.Border.card)
            .frame(height: 0.5)
    }
}

struct ContextHeader: View {
    var model: any Model

    var body: some View {
        HStack {
            Text("Context")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Style.Foreground.primary)

            if let harness = model.session.origin.context?.harness {
                HStack {
                    Iconography.icon(for: harness, size: 10)
                    Text(harness.descriptor.name)
                        .font(Typography.label)
                        .lineLimit(1)
                }
                .foregroundStyle(Style.Foreground.tertiary)
            }
        }
    }
}

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
        HStack {
            Iconography.Icon(symbol: symbol, tint: tint, sizing: 12)
                .frame(width: 28, height: 28)
                .background(shape.fill(tint.opacity(0.10)))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Style.Foreground.primary)
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Style.Foreground.tertiary)
                    .lineLimit(1)
            }
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
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(Typography.label)
                    .textCase(.uppercase)
                    .foregroundStyle(Style.Foreground.tertiary)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(Typography.label)
                        .foregroundStyle(Style.Foreground.disabled)
                }

                Spacer(minLength: 0)
            }

            content()
        }
    }
}

struct DetailSurface: Surface {
    var panel: any Panel
    var model: any Model

    var context: Composition? { model.session.origin.context }
    var transcript: Reference? { context?.intentTranscript }

    var materials: [Reference] {
        Space.with(model.session.origin, { $0.materials }) ?? Workspace.with(model.session.origin, { $0.materials }) ?? []
            .filter { $0.descriptor.published != false && !$0.descriptor.tags.contains("input") }
    }

    var spaces: [Reference] {
        let refs = Space.with(model.session.origin, { $0.spaces }) ?? Workspace.with(model.session.origin, { $0.spaces }) ?? []
        return refs
            .filter { $0.descriptor.published != false }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    var status: String {
        switch context?.state {
            case .working: return "Running"
            case .active: return "Active"
            case .inactive: return "Idle"
            case nil: return "Ready"
        }
    }

    func detail(for ref: Reference) -> String {
        let description = ref.descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty { return description }

        switch ref.type {
            case is Artifact.Type: return Artifact.with(ref, { $0.handler.directory }) == true ? "Directory" : "File"
            case is Material.Type: return "Material"
            case is Space.Type: return "Space"
            default: return ref.descriptor.name
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack {
                    ContextHeader(model: model)

                    if let transcript {
                        ContextSection("Activity") { ContextRow(ref: transcript, detail: status) }
                    }

                    if !spaces.isEmpty {
                        Separator()

                        ContextSection("Spaces", count: spaces.count) {
                            ForEach(spaces.prefix(5)) { ref in
                                ContextRow(ref: ref, detail: detail(for: ref))
                            }
                        }
                    }

                    if !materials.isEmpty {
                        Separator()

                        ContextSection("Sources", count: materials.count) {
                            ForEach(materials.prefix(6)) { ref in
                                ContextRow(ref: ref, detail: detail(for: ref))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .scrollEdgeEffectStyle(.hard, for: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
