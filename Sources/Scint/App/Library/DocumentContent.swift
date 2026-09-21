import SwiftUI
import ScintRuntime
import ScintComponents


struct DocumentContent: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? { model.session.opened.document }
    var library: Reference { model.session.library }

    var body: some View {
        ScrollView {
            if let ref {
                EditorView(ref, autofocus: true)
                    .id(ref)
                    .frame(maxWidth: Typography.Prose.readableWidth, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, Style.Spacing.page)
                    .padding(.top, Style.Spacing.page)
                    .padding(.bottom, Style.Spacing.page)
                    .background {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollIndicators(.hidden)
        .background(Style.Background.canvas)
    }
}
