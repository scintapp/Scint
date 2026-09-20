import SwiftUI
import ScintComponents


@Observable final class EditorPanel: Panel {
    var state: PanelState = .init()
    var surface: PanelSurface = .edit

    enum PanelSurface: String, CaseIterable, Identifiable {
        case edit
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String { "square.and.pencil" }
    }

    func surface(_ model: any Model) -> some View {
        VStack {
            if let ref = model.session.opened.document {
                ScintEdit(ref: ref, onFocus: { model.select(ref) })
                .id(ref)
                .frame(maxWidth: Typography.Prose.readableWidth, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, Style.Spacing.page)
                .padding(.top, Style.Spacing.page)
                .padding(.bottom, Style.Spacing.page)
            }
        }
    }
}
