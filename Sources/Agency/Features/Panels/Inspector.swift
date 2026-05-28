import AgencyRuntime
import Foundation
import SwiftUI


struct InspectorTab: View {
    let inspector: Inspector.Model
    let selected: Bool
    let action: () -> Void

    var selectionBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(selected ? Color.gray.opacity(0.1) : Color.clear)
            .stroke(selected ? Color.primary.opacity(0.16) : Color.clear, lineWidth: 0.7)
            .shadow(color: selected ? .black.opacity(0.4) : .clear, radius: 1, x: 0, y: 0.5)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: inspector.image)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? .white.opacity(0.8) : .white.opacity(0.60))
                .frame(maxWidth: .infinity, maxHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selectionBackground)
    }
}

struct InspectorTabs: View {
    let inspector: Inspector

    var tabBarBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color.black.opacity(0.05))
            .stroke(Color.primary.opacity(0.09), lineWidth: 0.5)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Inspector.Model.allCases, id: \.self) { tab in
                InspectorTab(
                    inspector: tab,
                    selected: inspector.model == tab,
                    action: { inspector.model = tab }
                )
            }
        }
        .background(tabBarBackground)
        .padding([.horizontal, .bottom], 8)
        .frame(maxWidth: .infinity, maxHeight: 89, alignment: .bottom)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.gray.opacity(0.05))
                .blur(radius: 0.1)
                .frame(height: 1)
        }
    }
}

struct TranscriptSelector: View {
    @Environment(AgencyModel.self) var agency
    let inspector: Inspector

    private var space: Reference? { agency.session.space ?? agency.session.workspace }
    private var transcripts: [Reference] {
        guard let space else { return [] }
        return Runtime.shared.transcripts(for: space)
    }
    private var current: String {
        guard let transcript = agency.session.transcript else { return "Transcripts" }
        return Transcript.with(transcript, { $0.name }) ?? "Transcripts"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Menu {
                ForEach(transcripts, id: \.self) { ref in
                    let name = Transcript.with(ref, { $0.name }) ?? "Transcript"
                    Button { agency.select(ref) } label: {
                        if agency.session.selected(ref) {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
                if transcripts.isEmpty { Text("No transcripts").foregroundStyle(.secondary) }
            } label: {
                HStack(spacing: 4) {
                    Text(current)
                }
            }
            .menuStyle(.borderlessButton)
        }
        .padding([.horizontal, .bottom], 8)
        .frame(maxWidth: .infinity, maxHeight: 89, alignment: .bottom)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.gray.opacity(0.05)).blur(radius: 0.1).frame(height: 1)
        }
    }
}

struct InspectorToolbar: ToolbarContent {
    @Environment(AgencyModel.self) var agency

    var body: some ToolbarContent {
        ToolbarSpacer(.flexible, placement: .automatic)
        ToolbarItemGroup(placement: .primaryAction) { InspectorPickerToggle() }
            .sharedBackgroundVisibility(agency.studio.inspector.presented ? .hidden : .visible)
    }
}

@Observable final class Inspector: Panel {
    var model: Model = .composition
    var context: Context = .authoring
    var layout: Layout = .list
    var presented: Bool = false
    var position: CGFloat = 0
    var expanded: Set<AnyHashable> = []

    enum Context: CaseIterable { case authoring, processing }

    enum Model: String, CaseIterable {
        case composition, preview

        var label: String {
            switch self {
            case .composition: "Settings"
            case .preview: "Preview"

            }
        }

        var image: String {
            switch self {
            case .preview: "eyeglasses"
            case .composition: "gearshape.2"
            }
        }
    }

    func closures(_ agency: AgencyModel) -> Closures {
        switch context {
        case .authoring:
            switch model {
            case .composition: return CompositionMap.closures(agency, self)
            case .preview: return PreviewMap.closures(agency, self)
            }
        case .processing: return TranscriptsMap.closures(agency, self)
        }
    }

    func params(_ agency: AgencyModel) -> Params {
        switch context {
        case .authoring:
            switch model {
            case .composition: return CompositionMap.params(agency, self)
            case .preview: return PreviewMap.params(agency, self)
            }
        case .processing: return TranscriptsMap.params(agency, self)
        }
    }


    @MainActor func build(_ agency: AgencyModel) -> some View {
        VStack {
            switch context {
            case .authoring:  InspectorTabs(inspector: self)
            case .processing: TranscriptSelector(inspector: self)
            }
            switch context {
            case .authoring: Builder.build(self, closures(agency), params(agency))
            case .processing: TranscriptView().environment(agency)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .toolbar(removing: .sidebarToggle)
        .toolbar { InspectorToolbar() }
        .inspectorColumnWidth(
            min: context == .processing ? 340 : 260,
            ideal: context == .processing ? 400 : 320,
            max: context == .processing ? 460 : 380
        )
    }
}
