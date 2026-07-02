import AgencyRuntime
import SwiftUI


//struct PaletteAction: View {
//    @Binding var prompt: Palette.ControlPrompt
//    let focused: FocusState<Bool>.Binding
//    let onSubmit: () -> Void
//    let onCancel: () -> KeyPress.Result
//
//    var body: some View {
//        HStack(alignment: .center, spacing: 12) {
//            Iconography.icon(for: prompt.ref)
//                .font(.system(size: 13, weight: .medium))
//                .frame(width: 22, height: 22, alignment: .center)
//
//            Text(prompt.ref.descriptor.name)
//                .font(.system(size: 16, weight: .medium))
//                .foregroundStyle(.primary)
//                .lineLimit(1)
//
//            TextField("Arguments", text: $prompt.arguments)
//                .foregroundStyle(.primary)
//                .font(.system(size: 16))
//                .textFieldStyle(.plain)
//                .focused(focused)
//                .onKeyPress(.return) { onSubmit(); return .handled }
//                .onKeyPress(.escape) { onCancel() }
//
//            Button(action: onSubmit) {
//                Image(systemName: "arrow.up")
//                    .font(.system(size: 14, weight: .semibold))
//            }
//            .buttonStyle(.glassProminent)
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 14)
//    }
//}

@Observable final class PaletteAction: Panel {
    var model: Model = .commands
    var layout: Layout = .list
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []
//    let focused: FocusState<Bool>.Binding
//    let onSubmit: () -> Void
//    let onCancel: () -> KeyPress.Result

    enum Model: String, CaseIterable, Identifiable {
        case commands, interfaces, library, workspace

        var id: String { rawValue }
        var placeholder: String { "\(label)" }

        var label: String {
            switch self {
            case .commands: "Commands"
            case .interfaces: "Interfaces"
            case .library: "Library"
            case .workspace: "Workspace"
            }
        }

        var image: String {
            switch self {
            case .commands: "command"
            case .interfaces: "switch.2"
            case .library: "building.columns"
            case .workspace: "cube.transparent"
            }
        }
    }

    func view(_ agency: AgencyModel) -> some View {
        HStack(alignment: .center, spacing: 12) {
//            Iconography.icon(for: prompt.ref)
//                .font(.system(size: 13, weight: .medium))
//                .frame(width: 22, height: 22, alignment: .center)
//
//            Text(prompt.ref.descriptor.name)
//                .font(.system(size: 16, weight: .medium))
//                .foregroundStyle(.primary)
//                .lineLimit(1)
//
//            TextField("Arguments", text: $prompt.arguments)
//                .foregroundStyle(.primary)
//                .font(.system(size: 16))
//                .textFieldStyle(.plain)
//                .focused(focused)
//                .onKeyPress(.return) { onSubmit(); return .handled }
//                .onKeyPress(.escape) { onCancel() }
//
//            Button(action: onSubmit) {
//                Image(systemName: "arrow.up")
//                    .font(.system(size: 14, weight: .semibold))
//            }
//            .buttonStyle(.glassProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
