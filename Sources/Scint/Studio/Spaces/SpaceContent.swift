import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct SpaceMenu: View {
    @State private var hovered = false
    let model: any Model
    
    var selection: Selection { model.session.selection }
    var path: [Reference] { model.session.navigation.path(for: selection) }

    var body: some View {
        if let ref = path.last {
            Button { model.select(ref) } label: {
                HStack(alignment: .center) {
                    Iconography.icon(for: ref, size: 13.5)
                    Text(ref.descriptor.name).font(.system(size: 13.5, weight: .medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
        }
    }
}

struct SpaceContent: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? {
        guard let ref = model.session.selection.structure, Space.with(ref, { $0 }) != nil
        else { return nil }
        return ref
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TranscriptContent(panel: panel, model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Rectangle()
                .fill(Style.Background.canvas)
                .frame(maxHeight: 64, alignment: .bottom)
                .blur(radius: 10, opaque: false)
                .blendMode(.darken)
                .padding(.bottom, -32)
            InputToolbar(model: model, onSend: {})
                .frame(alignment: .bottom)
                .padding([.bottom, .vertical], 10)
        }
        .background(Style.Background.canvas)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .top) { SpaceHeader(panel: panel, model: model) }
    }
}
