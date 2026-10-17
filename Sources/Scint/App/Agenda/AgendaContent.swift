import SwiftUI
import ScintRuntime
import ScintComponents


struct AgendaContent: Surface {
    var host: any Host
    var model: any Model

    var body: some View {
        let params = host.parameters(model)
        let controls = host.controls(model)
        let state = host.state
        let select = controls.onTabSelect ?? { state.surface = $0.id.base as? String ?? "" }

        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(params.shown(state.surface)) { section in
                    switch section.layout {
                        case .row: RowFactory.build(self, section, controls)
                        case .table: TableFactory.build(self, section, controls)
                        default: EmptyView()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, Style.Spacing.entry)
            .padding(.top, 4)
            .padding(.bottom, Style.Spacing.page)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Style.Background.canvas)
        .scrollEdgeEffectStyle(.hard, for: .vertical)
        .safeAreaBar(edge: .top) { AgendaHeader(model: model, modes: params.sections, active: params.tab(state.surface)?.id, onSelect: select) }
    }
}
