import Foundation
import SwiftUI


@Observable final class ActionsPanel: Panel {
    var state: PanelState = .init()
    func controls(_ model: any Model) -> Controls { ActionsQuery.controls(model) }
    func parameters(_ model: any Model) -> Params { ActionsQuery.parameters(model) }
    func surface(_ model: any Model) -> some View { AnySurface(panel: self, model: model) }
}
