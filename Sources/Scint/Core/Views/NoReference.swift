import SwiftUI
import ScintRuntime
import ScintComponents


struct NoReference: View {
    let ref: Reference?
    let title: String

    init(ref: Reference? = nil, title: String) {
        self.ref = ref
        self.title = title
    }

    var body: some View {
        HStack(alignment: .center) {
            Spacer()
            VStack(alignment: .center) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24))
                    .foregroundStyle(Style.Foreground.subtle)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(Style.Foreground.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Style.Background.canvas)
    }
}
