import SwiftUI


struct NoSpace: View {
    let title: String

    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            VStack(alignment: .center) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(.quaternary)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Style.Foreground.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
