import SwiftUI


//struct InspectorTabs: View {
//    let inspector: StudioInspector
//
//    func effect(_ surface: StudioInspector.InspectorSurface) -> some View {
//        Design.Shape.tab
//            .inset(by: 2)
//            .contentShape(Design.Shape.tab)
//            .opacity(inspector.surface == surface ? 0.3 : 0.0)
//    }
//
//    func tab(_ surface: StudioInspector.InspectorSurface) -> some View {
//        Button { inspector.surface = surface } label: {
//            Image(systemName: surface.image)
//                .frame(maxWidth: .infinity, maxHeight: 28, alignment: .center)
//                .foregroundStyle(Design.Foreground.primary)
//                .font(.system(size: 12.5))
//                .contentShape(Design.Shape.tab)
//        }
//        .background(effect(surface).contentShape(Design.Shape.tab))
//        .buttonStyle(.plain)
//    }
//
//    var body: some View {
//        HStack { ForEach(StudioInspector.InspectorSurface.allCases, id: \.self) { tab($0) } }
//            .frame(maxWidth: .infinity, maxHeight: 28)
//            .glassEffect(.regular, in: Design.Shape.tab)
//            .padding(.horizontal, 8)
//    }
//}

//struct NavigatorTabs: View {
//    let navigator: StudioNavigator
//
//    func effect(_ model: StudioNavigator.NavigatorModel) -> some View {
//        Design.Shape.tab
//            .inset(by: 2)
//            .contentShape(Design.Shape.tab)
//            .opacity(navigator.model == model ? 0.3 : 0.0)
//    }
//
//    func tab(_ model: StudioNavigator.NavigatorModel) -> some View {
//        Button { navigator.model = model } label: {
//            Image(systemName: model.image)
//                .frame(maxWidth: .infinity, maxHeight: 28, alignment: .center)
//                .foregroundStyle(Design.Foreground.primary)
//                .font(.system(size: 12.5))
//                .contentShape(Design.Shape.tab)
//        }
//        .background(effect(model).contentShape(Design.Shape.tab))
//        .buttonStyle(.plain)
//    }
//
//    var body: some View {
//        HStack { ForEach(StudioNavigator.NavigatorModel.allCases, id: \.self) { tab($0) } }
//            .frame(maxWidth: .infinity, maxHeight: 28)
//            .glassEffect(.regular, in: Design.Shape.tab)
//            .padding(.horizontal, 8)
//    }
//}
