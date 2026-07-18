import SwiftUI


struct InspectorTabs: View {
    @Environment(AgencyModel.self) var agency
    var inspector: Inspector { agency.app.inspector }

    func effect(_ model: InspectorModel) -> some View {
        Design.Shape.tab
            .inset(by: 2)
            .contentShape(Design.Shape.tab)
            .opacity(inspector.model == model ? 0.3 : 0.0)
    }

    func tab(_ model: InspectorModel) -> some View {
        Button { inspector.model = model } label: {
            Image(systemName: model.image)
                .frame(maxWidth: .infinity, maxHeight: 28, alignment: .center)
                .foregroundStyle(Design.Foreground.primary)
                .font(.system(size: 12.5))
                .contentShape(Design.Shape.tab)
        }
        .background(effect(model).contentShape(Design.Shape.tab))
        .buttonStyle(.plain)
    }

    var body: some View {
        HStack { ForEach(InspectorModel.allCases, id: \.self) { tab($0) } }
            .frame(maxWidth: .infinity, maxHeight: 28)
            .glassEffect(.regular, in: Design.Shape.tab)
            .padding(.horizontal, 8)
    }
}

struct NavigatorTabs: View {
    @Environment(AgencyModel.self) var agency
    var navigator: Navigator { agency.app.navigator }

    func effect(_ model: Navigator.Model) -> some View {
        Design.Shape.tab
            .inset(by: 2)
            .contentShape(Design.Shape.tab)
            .opacity(navigator.model == model ? 0.3 : 0.0)
    }

    func tab(_ model: Navigator.Model) -> some View {
        Button { navigator.model = model } label: {
            Image(systemName: model.image)
                .frame(maxWidth: .infinity, maxHeight: 28, alignment: .center)
                .foregroundStyle(Design.Foreground.primary)
                .font(.system(size: 12.5))
                .contentShape(Design.Shape.tab)
        }
        .background(effect(model).contentShape(Design.Shape.tab))
        .buttonStyle(.plain)
    }

    var body: some View {
        HStack { ForEach(Navigator.Model.allCases, id: \.self) { tab($0) } }
            .frame(maxWidth: .infinity, maxHeight: 28)
            .glassEffect(.regular, in: Design.Shape.tab)
            .padding(.horizontal, 8)
    }
}
