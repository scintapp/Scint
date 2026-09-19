import ScintComponents
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

    var composition: Composition? { ref.context }

    var state: (label: String, tint: Color) {
        switch composition?.state {
            case .active: ("Active", Style.Tint.accent.bright)
            case .working: ("Working", Style.Tint.accent.bright)
            case .completed: ("Complete", Style.Tint.space.bright)
            case .failed: ("Needs attention", Style.Tint.alert.bright)
            case .inactive, .none: ("Ready", Style.Foreground.secondary)
        }
    }

    var intent: String? {
        guard let harness = Space.with(ref, { $0.harness }) ?? nil else { return nil }
        return Harness.with(harness, { $0.intent.rawValue.capitalized }) ?? nil
    }

    var body: some View {
        HStack(alignment: .center) {
            HStack(alignment: .center, spacing: 16) {
                Group {
                    if let harness = Space.with(ref, { $0 })?.harness { Iconography.icon(for: harness, size: 23) }
                    else { Iconography.icon(for: ref, size: 23) }
                }
                .frame(maxHeight: 52)

                VStack(alignment: .leading) {
                    Text(ref.descriptor.name)
                        .frame(alignment: .leading)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(intent ?? "")
                        .frame(alignment: .leading)
                        .foregroundStyle(Style.Foreground.secondary)
                }
                .font(Typography.detail)
                .lineLimit(1)
            }
            .frame(maxHeight: 52)

            HStack(alignment: .center) {
                TranscriptPicker(model: model)
                Button { } label: {
                    Image(systemName: "pause.fill")
                        .frame(width: 23, height: 23)
                }
                .buttonStyle(.accessoryBarAction)
                .buttonBorderShape(.circle)

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
        TranscriptContent(panel: panel, model: model)
            .background(Style.Background.canvas)
            .safeAreaBar(edge: .top) {
                if let ref { SpaceHeader(ref: ref, panel: panel, model: model) }
            }
    }
}

