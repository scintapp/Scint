import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct DocumentDrafts: Surface {
    var panel: any Panel
    var model: any Model
    
    var ref: Reference { model.session.drafts }

    var body: some View {
    }
}



