import SwiftUI


struct PaletteBar: View {
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

struct StudioControls: View {
    var body: some View {
        HStack(alignment: .center) {
            Iconography.Glyph(sizing: 20, active: true)
                .frame(height: 30, alignment: .center)
            VStack(alignment: .leading) {
                Text("Scint Studio")
                    .font(.system(size: 15, weight: .semibold))
                Text("3 Active Spaces")
                    .font(.system(size: 11))
                    .foregroundStyle(Design.Foreground.tertiary)
            }
            .frame(height: 30, alignment: .center)
        }
    }
}

struct CanvasControls: View {
    let canvas: StudioCanvas

    func button(for surface: StudioCanvas.CanvasSurface, systemImage: String) -> some View {
        let isSelected = canvas.state.presented /*&& canvas.surface == surface*/

        return Button {
            if isSelected { canvas.state.presented = false }
            else {
//                canvas.surface = surface
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
        .id(String(describing: surface))
    }

    var body: some View {
        ControlGroup {
            button(for: .space, systemImage: "app")
            button(for: .composer, systemImage: "ellipses.bubble")
            button(for: .editor, systemImage: "doc.plaintext")
        }
        .controlGroupStyle(.navigation)
    }
}

struct NavigationControls: View {
    let model: any Model
    let canvas: StudioCanvas

    var body: some View {
        Group {
            Button {
                if let selection = model.session.back() {
                    if let content = selection.content, content.type is Sheet.Type { model.focus(content) }
                    else if let structure = selection.structure { model.focus(structure) }
                }
            } label: { Image(systemName: "chevron.backward") }
                .disabled(!model.session.navigation.canGoBack)
            Button {
                if let selection = model.session.forward() {
                    if let content = selection.content, content.type is Sheet.Type { model.focus(content) }
                    else if let structure = selection.structure { model.focus(structure) }
                }
            } label: { Image(systemName: "chevron.forward") }
                .disabled(!model.session.navigation.canGoForward)
        }
        .buttonStyle(.plain)
    }
}

//struct ContextControls: View {
//    let model: any Model
//    var ref: Reference { model.session.origin }
//    var composable: Bool { model.session.composable }
//
//    var running: Bool {
//        if !composable { return false }
//        guard let context = Runtime.shared.context(for: ref) else { return false }
//        if context.state == .running { return true }
//        return false
//    }
//
//    var body: some View {
//        HStack {
//            ControlGroup {
//                Button { } label: {
//                    Iconography.icon(for: ref, size: 11)
//                }
//
//                Spacer()
//
//                Button { } label: {
//                    VStack(alignment: .center) {
//                        Text(ref.descriptor.name)
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
//        .frame(minWidth: 200)
//    }
//}

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

struct ConsoleBar: View {
    @Environment(StudioModel.self) var studio

    var bar: some View {
        Group {
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(height: 0.5)
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .frame(height: 1)
        }
    }

    var body: some View {
        HStack {
            Spacer()
            Button { studio.console.state.presented.toggle() } label: {
                Image(systemName: "inset.filled.bottomthird.square")
                    .foregroundStyle(Design.Foreground.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .overlay(alignment: .top) { bar }
    }
}

struct EditorBar: View {
    @Environment(StudioModel.self) var studio
    var ref: Reference { studio.session.active ?? studio.session.space ?? studio.session.workspace }
    var words: String { "\(metrics.words) \(metrics.words == 1 ? "Word" : "Words")" }
    var tasks: String { "\(metrics.completedTasks) of \(metrics.totalTasks) \(metrics.totalTasks == 1 ? "Task" : "Tasks")" }
    var metrics: (words: Int, completedTasks: Int, totalTasks: Int) {
        Sheet.with(ref) { sheet in
            let words = sheet.rendered.split(whereSeparator: { $0.isWhitespace }).count
            let tasks = sheet.blocks.compactMap { block -> Bool? in
                guard case .task(_, _, let completed) = block else { return nil }
                return completed }
            return (words, tasks.filter { $0 }.count, tasks.count)
        } ?? (0, 0, 0)
    }

    var body: some View {
        Group {
            Text(words)
            Text(tasks)
        }
        .frame(alignment: .center)
        .foregroundStyle(.secondary)
        .font(.callout)
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
    }
}
