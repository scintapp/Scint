import SwiftUI


struct GridLayout<Content: View>: View {
    @ViewBuilder let content: () -> Content
    private let gridItem = GridItem(.adaptive(minimum: 128, maximum: 128), spacing: 8, alignment: .topLeading)

    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        LazyVGrid(columns: [gridItem], alignment: .leading, spacing: 8) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
