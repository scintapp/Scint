import SwiftUI


@Observable final class SearchPalette: Panel {
    var query = ""
    var state: StateContainer = .init()

    func controls(_ model: any Model) -> Controls { .init() }
    func parameters(_ model: any Model) -> Params { .init() }
    func panel(_ model: any Model) -> some View { AnySurface(panel: self, model: model) }
}
