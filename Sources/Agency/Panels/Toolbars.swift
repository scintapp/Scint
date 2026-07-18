import SwiftUI
import AgencyRuntime


struct ActionsBar: View {
    let model: any Model
    
    var body: some View {
        HStack {
            Spacer()
            Button { } label: {
                Image(systemName: "plus")
                    .frame(height: 30, alignment: .center)
                    .foregroundStyle(Design.Foreground.secondary)
                    .font(.system(size: 13))
            }
            .frame(height: 30, alignment: .center)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

struct EditorBar: View {
    let model: any Model

    var body: some View {
        HStack {
            if let ref = model.session.active, ref.type == Sheet.self {
                Button { model.select(ref) } label: {
                    Iconography.icon(for: ref, size: 14)
                    Text(ref.descriptor.name).font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .frame(maxHeight: 30, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

struct PathBar: View {
    let model: any Model
    var refs: [Reference] {
        model.session.navigation
            .path(for: model.session.selected, in: model.session.workspace)
            .filter { $0.type != Sheet.self }
    }

    var body: some View {
        HStack(alignment: .center) {
            ForEach(Array(refs.enumerated()), id: \.element) { index, ref in
                Button { model.select(ref) } label: {
                    HStack {
                        Iconography.icon(for: ref, size: 14)
                        Text(ref.descriptor.name).font(.system(size: 11))

                        if index < refs.count - 1 {
                            Image(systemName: "chevron.compact.forward")
                                .foregroundStyle(Design.Foreground.tertiary)
                                .font(.system(size: 13, weight: .light))
                                .opacity(0.8)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

struct CanvasControls: View {
    let canvas: Canvas

    func button(for model: CanvasModel, systemImage: String) -> some View {
        let isSelected = canvas.state.presented && canvas.model == model

        return Button {
            if isSelected { canvas.state.presented = false }
            else {
                canvas.model = model
                canvas.state.presented = true
            }
        } label: {
            Image(systemName: systemImage)
                .frame(width: 40, height: 40, alignment: .center)
                .fixedSize(horizontal: true, vertical: true)
                .font(.system(size: 17, weight: .ultraLight))
                .foregroundStyle(Design.Foreground.secondary)
        }
        .buttonStyle(PickerToggleStyle(isSelected: isSelected))
        .id(String(describing: model))
    }

    var body: some View {
        ControlGroup {
            button(for: .browsing, systemImage: "rectangle.stack")
            button(for: .editing, systemImage: "doc.plaintext")
        }
        .controlGroupStyle(.navigation)
    }
}

struct NavigationControls: View {
    let model: any Model
    let canvas: Canvas

    var body: some View {
        ControlGroup {
            Button {
                if let selection = model.session.back() {
                    if let content = selection.content, content.type is Sheet.Type {
                        model.focus(content)
                        canvas.model = .editing
                    } else if let structure = selection.structure {
                        model.focus(structure)
                    }
                }
            } label: { Image(systemName: "chevron.backward") }
                .disabled(!model.session.navigation.canGoBack)
            Button {
                if let selection = model.session.forward() {
                    if let content = selection.content, content.type is Sheet.Type {
                        model.focus(content)
                        canvas.model = .editing
                    } else if let structure = selection.structure {
                        model.focus(structure)
                    }
                }
            } label: { Image(systemName: "chevron.forward") }
                .disabled(!model.session.navigation.canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}

struct ContextControls: View {
    let model: any Model
    var ref: Reference { model.session.origin }
    var composable: Bool { model.session.composable }

    var running: Bool {
        if !composable { return false }
        guard let context = Runtime.shared.context(for: ref) else { return false }
        if context.state == .running { return true }
        return false
    }

    var body: some View {
        HStack {
            ControlGroup {
                Button { } label: {
                    Iconography.icon(for: ref, size: 11)
                }

                Spacer()

                Button { } label: {
                    VStack(alignment: .center) {
                        Text(ref.descriptor.name)
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

struct WorkspaceControls: View {
    let model: any Model
    var space: Reference { model.session.origin }
    var composable: Bool { model.session.composable }

    var running: Bool {
        if !composable { return false }
        guard let context = Runtime.shared.context(for: space) else { return false }
        if context.state == .running { return true }
        return false
    }

    var body: some View {
        HStack {
            ControlGroup {
                Button { } label: { Iconography.icon(for: space, size: 11) }

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
    }
}
