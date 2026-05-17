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
    @Environment(AgencyModel.self) var agency

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
                    selected: agency.studio.inspector.model == tab,
                    action: { agency.studio.inspector.model = tab }
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

@Observable final class Inspector: Frame {
    var model: Tab = .library
    var presented: Bool = false
    var position: CGFloat = 0
    var expanded: Set<AnyHashable> = []

    enum Tab: String, CaseIterable {
        case library, preview, settings

        var label: String {
            switch self {
            case .library: "Library"
            case .preview: "Preview"
            case .settings: "Settings"
            }
        }

        var image: String {
            switch self {
            case .library: "building.columns"
            case .preview: "eyeglasses"
            case .settings: "gearshape.2"
            }
        }
    }

    func params(_ studio: AgencyModel) -> Params {
        switch studio.studio.inspector.model {
        case .library: return LibraryMapper.params(studio, self)
        case .preview: return PreviewMapper.params(studio, self)
        case .settings: return CompositionMapper.params(studio, self)
        }
    }

    func closures(_ studio: AgencyModel) -> Closures {
        switch studio.studio.inspector.model {
        case .library: return LibraryMapper.closures(studio, self)
        case .preview: return PreviewMapper.closures(studio, self)
        case .settings: return CompositionMapper.closures(studio, self)
        }
    }

    @MainActor func build(_ agency: AgencyModel) -> some View {
        VStack {
            InspectorTabs()
            Constructor.build(
                agency.studio.inspector, params(agency), closures(agency))
        }
    }
}


