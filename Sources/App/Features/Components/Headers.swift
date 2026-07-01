import AgencyRuntime
import SwiftUI


struct ContentHeader: View {
    @Environment(AgencyModel.self) var agency
    private var focused: Reference? { agency.session.selected.space }

    var body: some View {
        HStack(alignment: .center) {
            if let focused {
                Text(focused.descriptor.name)
                    .frame(height: 50, alignment: .center)
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .frame(maxWidth: .infinity, maxHeight: 50, alignment: .leading)
        .padding(12)
    }
}
