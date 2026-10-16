import SwiftUI
import ScintRuntime
import ScintComponents


struct SettingsContent: Surface {
    var host: any Host
    var model: any Model

    var ref: Reference? { host.parameters(model).ref }
    var size: CGSize { host.parameters(model).panel?.size ?? .zero }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)

        if let ref {
            IconPicker(icon: ref.descriptor.icon, color: ref.descriptor.color, tint: Iconography.icon(for: ref).tint) { icon, color in
                Catalog.shared.update(ref) { $0.icon = icon; $0.color = color }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipShape(shape)
            .glassEffect(.regular, in: shape)
        }
    }
}

@Observable final class SettingsMenu: Menu {
    var state: StateContainer = .init()
    var ref: Reference?
    var anchor: CGRect = .zero

    func parameters(_ model: any Model) -> Params {
        .init(
            ref: ref,
            panel: PanelParams(
                size: CGSize(width: 340, height: 412),
                placement: .anchored(anchor),
                dismissal: [.escape, .outsideClick, .resignKey]
            )
        )
    }

    func surface(_ model: PanelModel) -> some View { SettingsContent(host: self, model: model) }
}
