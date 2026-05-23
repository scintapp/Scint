import AgencyRuntime
import Foundation
import SwiftUI


struct InspectorTab: View {
    let inspector: Inspector.Tab
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
            ForEach(Inspector.Tab.allCases, id: \.self) { tab in
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

struct InspectorToolbar: ToolbarContent {
    @Environment(AgencyModel.self) var agency

    var body: some ToolbarContent {
        @Bindable var inspector = agency.studio.inspector
        ToolbarSpacer(.flexible, placement: .automatic)
        ToolbarItem(placement: .primaryAction) { InspectorToggle(presented: $inspector.presented) }
            .sharedBackgroundVisibility(inspector.presented ? .hidden : .visible)
    }
}

@Observable final class Inspector: Panel {
    var model: Tab = .preview
    var presented: Bool = false
    var position: CGFloat = 0
    var expanded: Set<AnyHashable> = []

    enum Tab: String, CaseIterable {
        case preview, composition

        var label: String {
            switch self {
            case .preview: "Preview"
            case .composition: "Settings"
            }
        }

        var image: String {
            switch self {
            case .preview: "eyeglasses"
            case .composition: "gearshape.2"
            }
        }
    }

    func params(_ agency: AgencyModel) -> Params {
        switch model {
        case .preview: return PreviewMapper.params(agency, self)
        case .composition: return CompositionMapper.params(agency, self)
        }
    }

    func closures(_ agency: AgencyModel) -> Closures {
        switch model {
        case .preview: return PreviewMapper.closures(agency, self)
        case .composition: return CompositionMapper.closures(agency, self)
        }
    }

    @MainActor func build(_ agency: AgencyModel) -> some View {
        VStack {
            InspectorTabs(inspector: self)
            Builder.build(self, closures(agency), params(agency))
        }
        .environment(agency)
        .ignoresSafeArea(.container, edges: .top)
        .inspectorColumnWidth(min: 200, ideal: 330, max: 440)
        .toolbar(removing: .sidebarToggle)
        .toolbar { InspectorToolbar() }
    }
}

