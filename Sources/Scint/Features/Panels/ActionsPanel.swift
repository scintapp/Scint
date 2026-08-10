import Foundation
import SwiftUI


@Observable final class ActionsPanel: Panel {
    var key: AppKey = .studio
    var state: AppState = .init()
    func controls(_ model: any Model) -> Controls { ActionsQuery.controls(model) }
    func parameters(_ model: any Model) -> Params { ActionsQuery.parameters(model) }
    func surface(_ model: any Model) -> some View { AnySurface(host: self, model: model) }
}
