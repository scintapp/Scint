import SwiftUI


struct InspectorTabs: View {
    @Environment(AgencyModel.self) var agency
    var inspector: Inspector { agency.studio.inspector }
    let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

    func effect(_ model: Inspector.Model) -> some View {
        shape
            .inset(by: 2)
            .opacity(inspector.model == model ? 0.3 : 0.0)
    }

    func tab(_ model: Inspector.Model) -> some View {
        Button { inspector.model = model } label: {
            Image(systemName: model.image)
                .frame(maxWidth: .infinity, maxHeight: 28)
                .foregroundStyle(Color.primary.opacity(0.9))
                .font(.system(size: 13, weight: .medium))
                .contentShape(shape)
        }
        .background(effect(model))
        .buttonStyle(.plain)
        .contentShape(shape)
    }

    var body: some View {
        HStack { ForEach(Inspector.Model.allCases, id: \.self) { tab($0) } }
            .frame(maxWidth: .infinity, maxHeight: 26)
            .glassEffect(.regular, in: shape)
            .padding(.horizontal, 8)
    }
}

struct NavigatorTabs: View {
    @Environment(AgencyModel.self) var agency
    var navigator: Navigator { agency.studio.navigator }
    let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

    func effect(_ model: Navigator.Model) -> some View {
        shape
            .inset(by: 2)
            .contentShape(shape)
            .opacity(navigator.model == model ? 0.3 : 0.0)
    }

    func tab(_ model: Navigator.Model) -> some View {
        Button { navigator.model = model } label: {
            Image(systemName: model.image)
                .frame(maxWidth: .infinity, maxHeight: 28)
                .foregroundStyle(Color.primary.opacity(0.9))
                .font(.system(size: 13, weight: .medium))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .background(effect(model).contentShape(shape))
    }

    var body: some View {
        HStack { ForEach(Navigator.Model.allCases, id: \.self) { tab($0) } }
            .frame(maxWidth: .infinity, maxHeight: 28)
            .glassEffect(.regular, in: shape)
            .padding(.horizontal, 8)
    }
}
