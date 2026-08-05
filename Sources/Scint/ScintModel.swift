import Foundation
import SwiftUI


@Observable @MainActor final class ScintModel {
    var palette: PaletteModel
    var studio: StudioModel
    var server: ServerModel
    var panels: PanelController

    init(_ workspaces: [Reference]) {
        func workspace(_ framing: Descriptor.Framing) -> Reference {
            if let ref = workspaces.first(where: { $0.descriptor.framing == framing }) { return ref }
            return Workspace.new("\(framing)".capitalized, framing: framing)
        }

        self.palette = .init(workspace(.studio))
        self.panels = .init()
        self.server = .init()
        self.studio = .init(workspace(.studio))
    }

    func load() async {
        await SampleData.load(studio.session.workspace)
        await Runtime.shared.save()
        await server.start()
    }

    func showPalette() {
        let parameters = palette.search.parameters(studio)
        guard let panel = parameters.panel else { return }
        panels.show(parameters.id, parameters: panel, view: palette.search.panel(studio)) {
            [weak palette = palette] presented in palette?.search.state.presented = presented
        }
    }

    func togglePalette() {
        let parameters = palette.search.parameters(studio)
        guard let panel = parameters.panel else { return }
        panels.toggle(parameters.id, parameters: panel, view: palette.search.panel(studio)) {
            [weak palette = palette] presented in palette?.search.state.presented = presented
        }
    }

//    func handle(_ url: URL) -> Runtime.Callback? {
//        do {
//            let callback = try Runtime.shared.handle(url)
//            switch callback {
//                case .open(let ref):
//                    studio.open(ref)
//                case .eval:
//                    break
//                case .dispatch(_, _, let error):
//                    if let error { print(error) }
//                case .run(_, _, let error):
//                    if let error { print(error) }
//                case .search(let results):
//                    palette.search.query = results.query
//                    showPalette()
//            }
//            return callback
//        } catch {
//            print(error)
//            return nil
//        }
//    }
}
