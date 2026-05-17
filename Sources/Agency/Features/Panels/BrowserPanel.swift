import AgencyRuntime
import SwiftUI


struct BrowserPanel: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        ScrollView {
            Color.clear.frame(height: 90)
            Constructor.build(
                agency.studio.content,
                SheetsMapper.params(agency),
                SheetsMapper.closures(agency)
            )
        }
    }
}
