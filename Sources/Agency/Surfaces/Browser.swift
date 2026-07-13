import AgencyRuntime
import SwiftUI


struct Browser: Surface {
    @Environment(AgencyModel.self) var agency

    func parameters() -> Params { BrowserMap.parameters(agency) }
    func controls() -> Controls { BrowserMap.controls(agency) }

    var body: some View {
        Builder.build(agency.studio.canvas, parameters(), controls())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
