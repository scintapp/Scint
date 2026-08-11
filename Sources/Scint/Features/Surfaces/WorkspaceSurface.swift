import SwiftUI


struct SpaceCardButton<Label: View>: View {
    var accented = false
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    private let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)

    init(accented: Bool = false, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.accented = accented
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Design.Foreground.primary)
                .frame(maxWidth: .infinity, minHeight: 32)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .background(shape.fill(accented ? Design.Tint.compose.opacity(0.14) : Design.Background.raised))
        .overlay(shape.strokeBorder(accented ? Design.Tint.compose.opacity(0.38) : Design.Border.controlBorder, lineWidth: 0.75))
    }
}

struct SpaceContent: Surface {
    var ref: Reference? = nil
    var host: any Host
    var model: any Model

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.horizontal) {
                let surface = AnySurface(host: host, model: model)
                let parameters = if let ref { SpaceGrid.content(ref) } else { host.parameters(model) }
                surface.render(surface, parameters, host.controls(model))
                    .scrollDisabled(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 144)
    }
}

struct SpacePreviewBadges: View {
    let ref: Reference
    let state: Composition.State?

    private var materials: Int { Space.with(ref, { $0.materials.count }) ?? 0 }
    private var artifacts: Int { Space.with(ref, { $0.artifacts.count }) ?? 0 }
    private var commands: Int { Space.with(ref, { $0.commands.count }) ?? 0 }

    var body: some View {
        HStack(spacing: 5) {
            Badge("\(materials)", symbol: "text.alignleft", tint: Design.Tint.material)
            Badge("\(artifacts)", symbol: "archivebox", tint: Design.Tint.artifact)
            Badge("\(commands)", symbol: "switch.2", tint: Design.Tint.command)

            Spacer(minLength: 6)

            switch state {
                case .working: Badge("Running", symbol: "circle.fill", tint: Design.Tint.working)
                case .active: Badge("Active", symbol: "circle.dotted", tint: Design.Tint.active)
                case .inactive: Badge("Idle", symbol: "pause.fill", tint: Design.Tint.inactive)
                case nil: Badge("Ready", symbol: "circle.dotted", tint: Design.Tint.info, style: .neutral)
            }
        }
        .frame(height: 22)
    }
}

struct SpacePreviewCard: Surface {
    var model: any Model
    var host: any Host
    var ref: Reference

    var context: Composition? { ref.context }
    var state: Composition.State? { context?.state }
    var stoppable: Bool { state == .working || state == .active }

    private var activity: String {
        if let transcript = context?.intentTranscript { return transcript.descriptor.name }
        return ref.descriptor.description.isEmpty ? "No recent activity" : ref.descriptor.description
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Iconography.icon(for: ref, size: 15)

                Text(ref.descriptor.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Design.Foreground.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }
            .frame(height: 26)

            SpaceContent(ref: ref, host: host, model: model)
                .frame(width: 506, height: 144, alignment: .topLeading)
                .scaleEffect(0.72, anchor: .topLeading)
                .frame(width: 364, height: 104, alignment: .topLeading)
                .clipped()
                .background(Design.Shape.block.fill(Color.primary.opacity(0.025)))
                .padding(.top, 12)

            SpacePreviewBadges(ref: ref, state: state)
                .padding(.top, 14)

            Text(activity)
                .font(Typography.body)
                .foregroundStyle(Design.Foreground.tertiary)
                .lineLimit(1)
                .padding(.top, 10)

            Spacer(minLength: 14)

            HStack(spacing: 8) {
                SpaceCardButton(accented: true) { model.select(ref) } label: {
                    Label("Open", systemImage: "folder")
                }

                SpaceCardButton {
                    if stoppable { let _ = Runtime.shared.stop(ref) }
                    else { let _ = model.start(ref) }
                } label: {
                    Label(stoppable ? "Pause" : "Run", systemImage: stoppable ? "pause.fill" : "play.fill")
                }

                SwiftUI.Menu {
                    Button { model.select(ref) } label: {
                        Label("Open", systemImage: "folder")
                    }
                    if let transcript = context?.transcript {
                        Button { model.open(transcript) } label: {
                            Label("Open Transcript", systemImage: "text.bubble")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Design.Foreground.secondary)
                        .frame(width: 38, height: 32)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Design.Background.raised))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Design.Border.controlBorder, lineWidth: 0.75))
                .frame(width: 38)
            }
        }
        .padding(18)
        .frame(width: 400, height: 296, alignment: .topLeading)
        .background(Design.Shape.card.fill(Design.Background.raised))
        .overlay(
            Design.Shape.card.strokeBorder(
                state == .working ? Design.Tint.compose.opacity(0.72) : Design.Border.cardBorder,
                lineWidth: state == .working ? 1.25 : 0.75
            )
        )
        .contentShape(Design.Shape.card)
    }
}

struct WorkspaceSurface: Surface {
    var host: any Host
    let model: any Model

    var spaces: [Reference] {
        var pending = Array(Workspace.with(model.session.workspace, { $0.spaces }) ?? [])
        var visited: Set<Reference> = []
        var result: [Reference] = []

        while let ref = pending.popLast() {
            guard visited.insert(ref).inserted else { continue }
            if ref.descriptor.published != false { result.append(ref) }
            pending.append(contentsOf: Space.with(ref, { $0.spaces }) ?? [])
        }

        return result.sorted {
            $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
        }
    }

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 400, maximum: 400), spacing: 20, alignment: .top)]

        ScrollView {
            Color.clear.frame(height: 24)
            VStack(alignment: .leading, spacing: 0) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(spaces) { space in
                        SpacePreviewCard(model: model, host: host, ref: space)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}
