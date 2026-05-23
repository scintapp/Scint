import AgencyRuntime
import Foundation
import SwiftUI


struct Outline: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        ScrollView {
            Color.clear.frame(height: 90)
            Builder.build(
                agency.studio.content,
                OutlineMapper.closures(agency, agency.studio.content),
                OutlineMapper.params(agency, agency.studio.content)
            )
        }
    }
}
