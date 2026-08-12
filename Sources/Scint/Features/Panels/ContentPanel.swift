import SwiftUI


@Observable final class ContentPanel: Panel {
    /// What the trailing rail shows. Opening a sheet switches to the editor; the
    /// toolbar picker sets it back.
    enum Rail: String, CaseIterable, Identifiable {
        case context, tasks, editor

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
                case .context: "square.righthalf.filled"
                case .tasks: "checklist"
                case .editor: "square.and.pencil"
            }
        }
    }

    var rail: Rail = .context
    var state: PanelState = .init(presented: true, position: 480)

    func controls(_ model: any Model) -> Controls { SpaceGrid.controls(model) }
    func parameters(_ model: any Model) -> Params { SpaceGrid.parameters(model) }

    func surface(_ model: any Model) -> some View {
        @Bindable var state = self.state

        let editing = rail == .editor && model.session.material != nil

        // The rail is a fixed width; the editor is resizable and remembers its own.
        let width = Binding<CGFloat>(
            get: { editing ? max(state.position, 420) : ContextSurface.width },
            set: { if editing { state.position = $0 } }
        )

        return HSplit(
            $state.presented,
            width,
            minLeadingWidth: 480,
            minTrailingWidth: editing ? 420 : ContextSurface.width
        ) {
            HStack(alignment: .top, spacing: 20) {
                ZStack(alignment: .bottom) {
                    ScrollView {
                        Color.clear.frame(height: 24)
                        TranscriptEntries(model: model)
                            .frame(maxWidth: .infinity, alignment: .top)
                        Color.clear.frame(height: 96)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .scrollEdgeEffectStyle(.hard, for: .top)

                    ComposeInput(model: model)
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .padding(.leading, 24)
                        .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } trailing: {
            Group {
                switch editing ? .editor : rail {
                    case .editor: EditSurface(panel: self, model: model)
                    case .tasks: TasksSurface(panel: self, model: model)
                    case .context: ContextSurface(panel: self, model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .top)
    }
}
