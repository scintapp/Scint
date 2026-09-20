import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct SpaceActivity: Surface {
    var panel: any Panel
    var model: any Model
    var ref: Reference { model.session.inbox }

    var body: some View {
    }
}



