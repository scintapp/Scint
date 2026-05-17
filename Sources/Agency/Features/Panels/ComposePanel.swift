import AgencyRuntime
import SwiftUI
import Foundation


struct ComposePanel: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        ZStack(alignment: .bottom) {
            LazyVStack(alignment: .leading, spacing: 12) {
                let ref = agency.session.boundary ?? agency.session.space
                let _: ()? = Journal.with(ref) { journal in
                }
            }
        }
    }
}
