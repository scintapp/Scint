import SwiftUI
import Foundation


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

struct SpaceHeader: Surface {
    var ref: Reference
    var panel: any Panel
    var model: any Model

    var body: some View {
        HStack {
            Iconography.icon(for: ref, size: 18)
            VStack {
                Text(ref.descriptor.name)
                Text("")
            }
            HStack {
                Button { } label: {
                    HStack {
                        Image(systemName: "pause")
                        Text("Pause")
                    }
                }
                Button { } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}

struct SpaceSurface: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? {
        guard let ref = model.session.selection.structure, Space.with(ref, { $0 }) != nil
        else { return nil }
        return ref
    }

    var body: some View {
        ZStack {
            if let ref { TranscriptMenu(ref: ref, model: model) }
            TranscriptPicker(model: model)
            TranscriptSurface(panel: panel, model: model)
            InputBar(model: model, onSend: {})
        }
        .safeAreaBar(edge: .top) { if let ref { SpaceHeader(ref: ref, panel: panel, model: model) } }
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}



