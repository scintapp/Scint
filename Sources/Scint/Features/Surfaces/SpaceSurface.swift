import SwiftUI


struct SpaceHeader: View {
    var model: any Model
    var origin: Reference { model.session.origin }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.blockSpacing) {
            VStack(alignment: .leading) {
                Text(origin.descriptor.name)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Design.Foreground.primary)
                    .padding(.bottom, 6)

                if origin.descriptor.description.isEmpty {
                    Text("Write a description...")
                        .font(Typography.message)
                        .foregroundStyle(Design.Foreground.secondary)
                        .lineLimit(5)
                } else {
                    Text(origin.descriptor.description)
                        .font(Typography.message)
                        .foregroundStyle(Design.Foreground.quaternary)
                        .lineLimit(5)
                }
            }

            Spacer()

//            VStack(alignment: .trailing) {
//                BadgesBar(model: model)
//            }
//            .frame(alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }
}

struct SpaceContextRow: View {
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

struct SpaceContextSection<Content: View>: View {
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

struct SpaceContext: Surface {
    var host: any Host
    var model: any Model
    static let width: CGFloat = 288
    var origin: Reference { model.session.origin }
    var context: Composition? { origin.context }

    private var latest: Reference? { context?.intentTranscript }

    private var artifacts: [Reference] {
        Space.with(origin, { $0.artifacts }) ?? Workspace.with(origin, { $0.artifacts }) ?? []
    }

    private var scenes: [Reference] {
        (Space.with(origin, { $0.scenes }) ?? Workspace.with(origin, { $0.scenes }) ?? [])
            .filter { $0.descriptor.published != false && !$0.descriptor.tags.contains("input") }
    }

    private var spaces: [Reference] {
        let refs = Space.with(origin, { $0.spaces }) ?? Workspace.with(origin, { $0.spaces }) ?? []
        return refs
            .filter { $0.descriptor.published != false }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    private var sources: [Reference] { scenes }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            SpaceContextSection("Activity") {
                if let latest, let state = Transcript.with(latest, { TranscriptState($0) }) {
                    row(latest) {
                        SpaceContextRow(
                            name: latest.descriptor.name,
                            detail: state.title,
                            symbol: state.symbol,
                            tint: state.tint
                        )
                    }
                } else {
                    placeholder("No runs yet")
                }
            }

            separator

            SpaceContextSection("Outputs", count: artifacts.count) {
                if artifacts.isEmpty { placeholder("No generated outputs") }
                else {
                    ForEach(artifacts.prefix(5)) { ref in
                        row(ref) { SpaceContextRow(ref: ref, detail: detail(for: ref)) }
                    }
                }
            }

            separator

            SpaceContextSection("Sources", count: sources.count) {
                if sources.isEmpty { placeholder("No sources attached") }
                else {
                    ForEach(sources.prefix(6)) { ref in
                        row(ref) { SpaceContextRow(ref: ref, detail: detail(for: ref)) }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: Self.width, alignment: .topLeading)
        .background(Design.Shape.card.fill(Design.Background.raised))
        .overlay(Design.Shape.card.strokeBorder(Design.Border.cardBorder, lineWidth: 0.75))
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
            case is Scene.Type: return "Scene"
            case is Space.Type: return "Space"
            default: return ref.descriptor.name
        }
    }
}

struct SpaceSurface: Surface {
    var host: any Host
    var model: any Model
    var origin: Reference { model.session.origin }
    var context: Composition? { origin.context }
    var active: Bool? { context?.state == .active }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    SpaceHeader(model: model)
                        .frame(alignment: .top)

                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 0) {
                            TranscriptEntries(model: model)
                            Color.clear.frame(height: 64)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)

                        SpaceContext(host: host, model: model)
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            ComposeInput(model: model)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .padding(.leading, 24)
                .padding(.trailing, SpaceContext.width + 44)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}
