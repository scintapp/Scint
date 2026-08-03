import SwiftUI


@Observable final class StudioLibrary: Panel {
    var model: LibraryModel = .library
    var state: StateContainer = .init()

    enum LibraryModel: CaseIterable {
        case library, transcripts

        var label: String {
            switch self {
                case .library: "Library"
                case .transcripts: "Transcripts"
            }
        }

        var image: String {
            switch self {
                case .library: "books.vertical"
                case .transcripts: "bubble.left.and.text.bubble.right"
            }
        }
    }

    func controls(_ model: any Model) -> Controls {
        switch self.model {
            case .library: return StudioLibraryMapper.controls(model)
            case .transcripts: return TranscriptsMapper.controls(model)
        }
    }

    func parameters(_ model: any Model) -> Params {
        switch self.model {
            case .library: return StudioLibraryMapper.parameters(model)
            case .transcripts: return TranscriptsMapper.parameters(model)
        }
    }

    func panel(_ model: any Model) -> some View {
        @Bindable var state = self.state
        let surface = AnySurface(panel: self, model: model)

        return surface.render(surface, parameters(model), controls(model))
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaBar(edge: .top) { Filter(text: $state.filter) }
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { SidebarToggle(presented: $state.presented) }
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
    }
}
