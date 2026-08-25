import SwiftUI


//struct SpaceCardButton<Label: View>: View {
//    var accented = false
//    let action: () -> Void
//    @ViewBuilder let label: () -> Label
//
//    private let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
//
//    init(accented: Bool = false, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
//        self.accented = accented
//        self.action = action
//        self.label = label
//    }
//
//    var body: some View {
//        Button(action: action) {
//            label()
//                .font(.system(size: 12.5, weight: .medium))
//                .foregroundStyle(Style.Foreground.primary)
//                .frame(maxWidth: .infinity, minHeight: 32)
//                .contentShape(shape)
//        }
//        .buttonStyle(.plain)
//        .background(shape.fill(accented ? Style.Tint.compose.opacity(0.14) : Style.Background.raised))
//        .overlay(shape.strokeBorder(accented ? Style.Tint.compose.opacity(0.38) : Style.Border.controlBorder, lineWidth: 0.75))
//    }
//}
//
//struct SpacePreviewBadges: View {
//    let ref: Reference
//    let state: Composition.State?
//
//    private var materials: Int { Space.with(ref, { $0.materials.count }) ?? 0 }
//    private var artifacts: Int { Space.with(ref, { $0.artifacts.count }) ?? 0 }
//    private var commands: Int { Space.with(ref, { $0.commands.count }) ?? 0 }
//
//    var body: some View {
//        HStack(spacing: 5) {
//            Badge("\(materials)", symbol: "text.alignleft", tint: Style.Tint.material)
//            Badge("\(artifacts)", symbol: "archivebox", tint: Style.Tint.artifact)
//            Badge("\(commands)", symbol: "switch.2", tint: Style.Tint.command)
//
//            Spacer(minLength: 6)
//
//            switch state {
//                case .working: Badge("Running", symbol: "circle.fill", tint: Style.Tint.working)
//                case .active: Badge("Active", symbol: "circle.dotted", tint: Style.Tint.active)
//                case .inactive: Badge("Idle", symbol: "pause.fill", tint: Style.Tint.inactive)
//                case nil: Badge("Ready", symbol: "circle.dotted", tint: Style.Tint.info, style: .neutral)
//            }
//        }
//        .frame(height: 22)
//    }
//}
//
//struct SpacePreviewCard: Surface {
//    var ref: Reference
//    var model: any Model
//    var panel: any Panel
//
//    var context: Composition? { ref.context }
//    var state: Composition.State? { context?.state }
//    var stoppable: Bool { state == .working || state == .active }
//
//    private var activity: String {
//        if let transcript = context?.intentTranscript { return transcript.descriptor.name }
//        return ref.descriptor.description.isEmpty ? "No recent activity" : ref.descriptor.description
//    }
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            HStack(spacing: 9) {
//                Iconography.icon(for: ref, size: 15)
//
//                Text(ref.descriptor.name)
//                    .font(.system(size: 16, weight: .medium))
//                    .foregroundStyle(Style.Foreground.primary)
//                    .lineLimit(1)
//
//                Spacer(minLength: 8)
//            }
//            .frame(height: 26)
//
//            SpaceContent(ref: ref, panel: panel, model: model)
//                .frame(width: 506, height: 144, alignment: .topLeading)
//                .scaleEffect(0.72, anchor: .topLeading)
//                .frame(width: 364, height: 104, alignment: .topLeading)
//                .clipped()
//                .background(Style.Shape.block.fill(Color.primary.opacity(0.025)))
//                .padding(.top, 12)
//
//            SpacePreviewBadges(ref: ref, state: state)
//                .padding(.top, 14)
//
//            Text(activity)
//                .font(Typography.body)
//                .foregroundStyle(Style.Foreground.tertiary)
//                .lineLimit(1)
//                .padding(.top, 10)
//
//            Spacer(minLength: 14)
//
//            HStack(spacing: 8) {
//                SpaceCardButton(accented: true) { model.select(ref) } label: {
//                    Label("Open", systemImage: "folder")
//                }
//
//                SpaceCardButton {
//                    if stoppable { let _ = Runtime.shared.stop(ref) }
//                    else { let _ = model.start(ref) }
//                } label: {
//                    Label(stoppable ? "Pause" : "Run", systemImage: stoppable ? "pause.fill" : "play.fill")
//                }
//
//                SwiftUI.Menu {
//                    Button { model.select(ref) } label: {
//                        Label("Open", systemImage: "folder")
//                    }
//                    if let transcript = context?.transcript {
//                        Button { model.open(transcript) } label: {
//                            Label("Open Transcript", systemImage: "text.bubble")
//                        }
//                    }
//                } label: {
//                    Image(systemName: "ellipsis")
//                        .font(.system(size: 12, weight: .semibold))
//                        .foregroundStyle(Style.Foreground.secondary)
//                        .frame(width: 38, height: 32)
//                }
//                .menuStyle(.borderlessButton)
//                .menuIndicator(.hidden)
//                .buttonStyle(.plain)
//                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Style.Background.raised))
//                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Style.Border.controlBorder, lineWidth: 0.75))
//                .frame(width: 38)
//            }
//        }
//        .padding(18)
//        .frame(width: 400, height: 296, alignment: .topLeading)
//        .background(Style.Shape.card.fill(Style.Background.raised))
//        .overlay(
//            Style.Shape.card.strokeBorder(
//                state == .working ? Style.Tint.compose.opacity(0.72) : Style.Border.card,
//                lineWidth: state == .working ? 1.25 : 0.75
//            )
//        )
//        .contentShape(Style.Shape.card)
//    }
//}
//
//struct SpaceContent: Surface {
//    var ref: Reference? = nil
//    var panel: any Panel
//    var model: any Model
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            ScrollView(.horizontal) {
//                let surface = AnySurface(panel: panel, model: model)
//                let parameters = if let ref { SpaceGrid.parameters(model) } else { panel.parameters(model) }
//                surface.render(surface, parameters, panel.controls(model))
//                    .scrollDisabled(true)
//            }
//        }
//        .frame(maxWidth: .infinity, maxHeight: 144)
//    }
//}
//
//struct WorkspaceSurface: Surface {
//    var panel: any Panel
//    var model: any Model
//
//    var spaces: [Reference] {
//        var pending = Array(Workspace.with(model.session.workspace, { $0.spaces }) ?? [])
//        var visited: Set<Reference> = []
//        var result: [Reference] = []
//
//        while let ref = pending.popLast() {
//            guard visited.insert(ref).inserted else { continue }
//            if ref.descriptor.published != false { result.append(ref) }
//            pending.append(contentsOf: Space.with(ref, { $0.spaces }) ?? [])
//        }
//
//        return result.sorted {
//            $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
//        }
//    }
//
//    var body: some View {
//        let columns = [GridItem(.adaptive(minimum: 360), spacing: 20, alignment: .top)]
//
//        ScrollView {
//            Color.clear.frame(height: 24)
//            VStack(alignment: .leading, spacing: 0) {
//                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
//                    ForEach(spaces) { space in
//                        SpacePreviewCard(ref: space, model: model, panel: panel)
//                    }
//                }
//                .frame(maxWidth: .infinity, alignment: .topLeading)
//                .padding(.horizontal, 24)
//                .padding(.bottom, 24)
//            }
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .scrollEdgeEffectStyle(.hard, for: .top)
//    }
//}
