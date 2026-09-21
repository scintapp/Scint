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

struct SpaceHeader: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? {
        guard let ref = model.session.selection.structure, Space.with(ref, { $0 }) != nil
                else { return nil }
        return ref
    }

    var state: (label: String, tint: Color) {
        if let ref, let context = ref.context {
            switch context.state {
                case .active: return ("Active", Style.Tint.accent.bright)
                case .working: return ("Working", Style.Tint.accent.bright)
                case .completed: return ("Complete", Style.Tint.space.bright)
                case .failed: return ("Needs attention", Style.Tint.alert.bright)
                case .inactive: return ("Ready", Style.Foreground.secondary)
            }
        }
        return ("", .clear)
    }

    var body: some View {
        HStack(alignment: .center) {
            if let ref {
                HStack(alignment: .center, spacing: 16) {
                    Iconography.icon(for: ref, size: 23)
                        .frame(maxHeight: 52)

                    VStack(alignment: .leading) {
                        Text(ref.descriptor.name)
                            .frame(alignment: .leading)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Style.Foreground.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let context = ref.context {
                            Text(context.intent.rawValue)
                                .frame(alignment: .leading)
                                .foregroundStyle(Style.Foreground.secondary)
                        }
                    }
                    .font(Typography.detail)
                    .lineLimit(1)
                }
                .frame(maxHeight: 52)
            }

            HStack(alignment: .center) {
                TranscriptPicker(model: model)

                if let ref, let context = ref.context  {
                    if context.state == .active {
                        Button { } label: {
                            Image(systemName: "pause.fill")
                                .frame(width: 23, height: 23)
                        }
                        .buttonStyle(.accessoryBarAction)
                        .buttonBorderShape(.circle)
                    }
                }

                Button { } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 23, height: 23)
                }
                .buttonStyle(.accessoryBarAction)
                .buttonBorderShape(.circle)
            }
            .frame(maxHeight: 52)
        }
        .padding(.horizontal, 10)
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
        VStack {
            TranscriptContent(panel: panel, model: model)
                .background(Style.Background.canvas)
                .safeAreaBar(edge: .top) { SpaceHeader(panel: panel, model: model) }
                .safeAreaBar(edge: .bottom) { InputBar(model: model, onSend: {}) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
