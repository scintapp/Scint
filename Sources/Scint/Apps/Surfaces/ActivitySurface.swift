import ScintComponents
import SwiftUI
import Foundation


struct ActivitySurface: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? {
        guard let ref = model.session.selection.structure, Space.with(ref, { $0 }) != nil
                else { return nil }
        return ref
    }

    var body: some View {
        ZStack(alignment: .center) {
            if let ref { SpaceSurface(ref: ref, panel: panel, model: model) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Style.Background.canvas)
        .scrollEdgeEffectStyle(.soft, for: .top)
        //        .safeAreaBar(edge: .top) {
        //            if let ref { ActivityHeader(ref: ref, panel: panel, model: model) }
        //        }

    }
}
