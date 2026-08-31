import SwiftUI


struct EmptyState: View {
    let title: String
    let width: CGFloat
    let height: CGFloat

    init(title: String?, width: CGFloat? = .infinity, height: CGFloat? = .infinity) {
        self.title = title ?? "Nothing Here"
        self.width = width ?? .infinity
        self.height = height ?? .infinity
    }

    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            VStack(alignment: .center) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(.quaternary)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Style.Foreground.base)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer()
        }
        .frame(maxWidth: width, maxHeight: height)
    }
}
