import AgencyRuntime
import SwiftUI


struct EmptyState: View {
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .center) {
                Text("Nothing Open")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Design.Foreground.primary)
                Text("")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Design.Foreground.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
