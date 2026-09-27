import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents


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
                        .foregroundStyle(Style.Foreground.secondary)
                        .font(.system(size: 13, weight: .light))
                        .opacity(0.8)
                }
            }
        }
        .buttonStyle(.borderless)
        .buttonBorderShape(.roundedRectangle(radius: 9))
    }
}

struct PathToolbar: View {
    @State private var hovered = false
    let model: any Model
    var selection: Selection { model.session.selection }
    var path: [Reference] { model.session.navigation.path(for: selection) }

    var body: some View {
        HStack(alignment: .center) {
            ForEach(path, id: \.self) { ref in
                if ref != path.last { PathButton(ref: ref, label: hovered ? true : false, model: model) }
                else { PathButton(ref: ref, label: true, last: true, model: model) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .leading)
    }
}

struct OutlineControls: View {
    @State var hovered: Bool = false
    let model: any Model
    let icons: Bool

    var refs: [Reference] {
        model.session.navigation.path(for: model.session.selection)
            .filter { $0.type != ScintRuntime.Document.self }
    }

    var body: some View {
        HStack(alignment: .center) {
            SwiftUI.Menu {
                ForEach(Array(refs.enumerated()), id: \.element) { index, ref in
                    Button { model.select(ref) } label: {
                        HStack {
                            if icons { Iconography.icon(for: ref, size: 13) }
                            Text(ref.descriptor.name).font(.system(size: 12))

                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.number")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(.quaternary, in: Circle())
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(.quaternary, in: Circle())
                }
                .font(.system(size: 12))
                .contentShape(.capsule)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

