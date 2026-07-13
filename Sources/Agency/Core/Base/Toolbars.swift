import SwiftUI
import AgencyRuntime


struct PickleStyle: ButtonStyle {
    @State private var isHovered = false
    let isSelected: Bool

    private func tint(pressed: Bool) -> Color {
        if pressed { return Color.primary.opacity(0.2) }
        if isSelected { return Color.primary.opacity(0.12) }
        if isHovered { return Color.primary.opacity(0.16) }
        return Color.primary.opacity(0.0)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onHover { isHovered = $0 }
            .background {
                Capsule()
                    .fill(tint(pressed: configuration.isPressed))
                    .frame(maxWidth: 38, maxHeight: 38)
                    .padding([.top, .bottom], 2)
                    .padding([.leading, .trailing], 3)
            }
    }
}

struct CanvasControls: View {
    @Environment(AgencyModel.self) var agency

    private func button(for model: Canvas.Model, systemImage: String) -> some View {
        let isSelected = agency.studio.canvas.presented && agency.studio.canvas.model == model

        return Button {
            if isSelected { agency.studio.canvas.presented = false }
            else {
                agency.studio.canvas.model = model
                agency.studio.canvas.presented = true
            }
        } label: {
            Image(systemName: systemImage)
                .frame(width: 40, height: 40, alignment: .center)
                .fixedSize(horizontal: true, vertical: true)
                .font(.system(size: 17, weight: .ultraLight))
                .foregroundStyle(Design.Foreground.secondary)
        }
        .buttonStyle(PickleStyle(isSelected: isSelected))
        .id(String(describing: model))
    }

    var body: some View {
        ControlGroup {
            button(for: .browser, systemImage: "rectangle.stack")
            button(for: .editor, systemImage: "doc.plaintext")
        }
        .controlGroupStyle(.navigation)
    }
}

struct NavigationControls: View {
    @Environment(AgencyModel.self) var agency
    private var sheet: Reference? { agency.session.selected.content }
    private var space: Reference? { agency.session.selected.space }
    private var workspace: Reference { agency.session.workspace }

    var body: some View {
        ControlGroup {
            Button {
                if let selection = agency.session.back() {
                    if let content = selection.content, content.type is Sheet.Type {
                        agency.focus(content)
                        agency.studio.canvas.model = .editor
                    } else if let structure = selection.structure {
                        agency.focus(structure)
                    }
                }
            } label: { Image(systemName: "chevron.backward") }
                .disabled(!agency.session.navigation.canGoBack)
            Button {
                if let selection = agency.session.forward() {
                    if let content = selection.content, content.type is Sheet.Type {
                        agency.focus(content)
                        agency.studio.canvas.model = .editor
                    } else if let structure = selection.structure {
                        agency.focus(structure)
                    }
                }
            } label: { Image(systemName: "chevron.forward") }
                .disabled(!agency.session.navigation.canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}

struct ContextControls: View {
    @Environment(AgencyModel.self) var agency
    var space: Reference { agency.session.selected.space ?? agency.session.workspace }

    var composable: Bool {
        guard let composable = Space.with(space, { $0.composable })
        else { return false }
        return composable
    }

    var running: Bool {
        if !composable { return false }
        guard let context = agency.context(space) else { return false }
        if context.state == .running { return true }
        return false
    }

    var body: some View {
        HStack {
            ControlGroup {
                Button { } label: {
                    Iconography.icon(for: space, size: 11)
                }

                Spacer()

                Button { } label: {
                    VStack(alignment: .center) {
                        Text(space.descriptor.name)
                            .foregroundStyle(Design.Foreground.primary)
                            .font(.system(size: 11))
                        Text("Ready")
                            .foregroundStyle(Design.Foreground.secondary)
                            .font(.system(size: 9, weight: .medium))
                    }
                }

                Spacer()

                Button { } label: {
                    if !composable {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(Design.Foreground.tertiary)
                    } else if composable && !running {
                        Image(systemName: "play.fill")
                    } else if composable && running {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(Design.Foreground.primary)
                    }
                }
            }
            .controlGroupStyle(.navigation)
        }
        .frame(minWidth: 200)
    }
}

struct PathControls: View {
    @Environment(AgencyModel.self) var agency
    var refs: [Reference] { agency.session.navigation.path(for: agency.session.selected, in: agency.session.workspace) }

    var body: some View {
        HStack(alignment: .center) {
            ForEach(Array(refs.enumerated()), id: \.element) { index, ref in
                Button { agency.select(ref) } label: {
                    Iconography.icon(for: ref, size: 14)

                    Group {
                        Text(ref.descriptor.name)
                            .font(.system(size: 11))
                        if index < refs.count - 1 {
                            Image(systemName: "chevron.compact.forward")
                                .foregroundStyle(Design.Foreground.tertiary)
                                .font(.system(size: 13, weight: .light))
                                .opacity(0.8)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxHeight: 30, alignment: .leading)
            }
        }
        .frame(maxHeight: 30, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

struct ActiveCanvasControls: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        HStack(alignment: .center) {
            Divider()
                .padding(.leading, -13)
                .padding(.vertical, 8)
                .opacity(0.8)
        }
        .frame(maxHeight: 30, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

//struct WorkspaceControls: View {
//    @Environment(AgencyModel.self) var agency
//    var space: Reference { agency.session.selected.space ?? agency.session.workspace }
//
//    var composable: Bool {
//        guard let composable = Space.with(space, { $0.composable })
//        else { return false }
//        return composable
//    }
//
//    var running: Bool {
//        if !composable { return false }
//        guard let context = agency.context(space) else { return false }
//        if context.state == .running { return true }
//        return false
//    }
//
//    var body: some View {
//        HStack {
//            ControlGroup {
//                Button { } label: { Iconography.icon(for: space, size: 11) }
//
//                Spacer()
//
//                Button { } label: {
//                    VStack(alignment: .center) {
//                        Text(space.descriptor.name)
//                            .foregroundStyle(Design.Foreground.primary)
//                            .font(.system(size: 11))
//                        Text("Ready")
//                            .foregroundStyle(Design.Foreground.secondary)
//                            .font(.system(size: 9, weight: .medium))
//                    }
//                }
//
//                Spacer()
//
//                Button { } label: {
//                    if !composable {
//                        Image(systemName: "stop.fill")
//                            .foregroundStyle(Design.Foreground.tertiary)
//                    } else if composable && !running {
//                        Image(systemName: "play.fill")
//                    } else if composable && running {
//                        Image(systemName: "stop.fill")
//                            .foregroundStyle(Design.Foreground.primary)
//                    }
//                }
//            }
//            .controlGroupStyle(.navigation)
//        }
//    }
//}

