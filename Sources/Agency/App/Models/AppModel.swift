import AgencyRuntime
import Foundation
import SwiftUI


@Observable @MainActor final class AppModel {
    var actions = Actions()
    var canvas = Canvas()
    var inspector = Inspector()
    var navigator = Navigator()
    var panels = PanelController()
}
