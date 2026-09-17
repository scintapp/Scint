import AppKit
import SwiftUI


struct PathButton: View {
    var ref: Reference
    var label: Bool = true
    var last: Bool = false
    var model: any Model

    var body: some View {
        Button { model.select(ref) } label: {
            HStack {
                Iconography
                    .icon(for: ref, size: 13)

                if label {
                    Text(ref.descriptor.name)
                        .font(.system(size: 12.5))
                }

                if !last {
                    Image(systemName: "chevron.compact.forward")
                        .frame(maxWidth: 4)
                        .foregroundStyle(Style.Foreground.faint)
                        .font(.system(size: 13, weight: .light))
                        .opacity(0.8)
                }
            }
        }
        .buttonStyle(.borderless)
        .buttonBorderShape(.roundedRectangle(radius: 9))
    }
}

struct PathBar: View {
    @State private var hovered = false
    let model: any Model
    var selection: Selection { model.session.selection }
    var path: [Reference] { model.session.navigation.path(for: selection) }

    var body: some View {
        BackButton(model: model)

        HStack(alignment: .center) {
            ForEach(path, id: \.self) { ref in
                if ref != path.last { PathButton(ref: ref, label: hovered ? true : false, model: model) }
                else { PathButton(ref: ref, label: true, last: true, model: model) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .leading)
    }
}
