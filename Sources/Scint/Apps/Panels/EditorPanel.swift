import SwiftUI


@Observable final class EditorPanel: Panel {
    var mode: Modality = .floating
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
            if let ref = model.session.opened.material {
                EditorView(ref, sizing: .fitsContent, autofocus: false, onFocus: { model.select(ref) }, onOpenLink: { link in
                    switch link {
                        case .reference(let reference): model.open(reference)
                        case .url(let url): NSWorkspace.shared.open(url)
                    }
                })
                .id(ref)
                .frame(maxWidth: Style.Spacing.contentMaxWidth, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, Style.Spacing.xxl)
                .padding(.top, Style.Spacing.xxl)
                .padding(.bottom, Style.Spacing.xxxl)
            }
        }
    }
}
