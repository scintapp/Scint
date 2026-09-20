import Foundation
import SwiftUI
import ScintRuntime


struct TranscriptInbox: Surface {
    var panel: any Panel
    var model: any Model
    var ref: Reference { model.session.inbox }

    var body: some View {
        
    }
}



