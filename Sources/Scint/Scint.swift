import SwiftUI


struct Assistant: View {
    @Environment(ScintModel.self) var scint

    var body: some View {
        let model = scint.assistant
        let content = model.content
        let assistant = model.assistant
        let navigator = model.navigator
        NavigationSplitView {
            navigator.surface(model)
        } detail: {
            ZStack(alignment: .top) {
                content.surface(model)
                    .background(Style.Background.base)
                Rectangle()
                    .fill(Style.Border.base)
                    .frame(height: 0.75, alignment: .top)
            }
        }
        .environment(scint)
        .toolbar(removing: .title)
        .inspector(isPresented: assistant.bindable.presented) {
            assistant.surface(model)
                .inspectorColumnWidth(ideal: 340)
        }
    }
}

struct Editor: View {
    @Environment(ScintModel.self) var scint

    var body: some View {
        let model = scint.editor
        let editor = model.editor
        let outline = model.outline
        let navigator = model.navigator
        let presented = outline.bindable.presented

        NavigationSplitView {
            navigator.surface(model)
        } detail: {
            editor.surface(model)
        }
        .environment(scint)
        .toolbar(removing: .title)
        .inspector(isPresented: presented) {
            outline.surface(model)
                .inspectorColumnWidth(ideal: 340)
        }
    }
}

struct Studio: View {
    @Environment(ScintModel.self) var scint

    var body: some View {
        let studio = scint.studio
        let navigator = studio.navigator
        let canvas = studio.canvas
        let assistant = studio.assistant
        let presented = assistant.bindable.presented

        NavigationSplitView {
            navigator.surface(studio)
        } detail: {
            canvas.surface(studio)
        }
        .environment(scint)
        .toolbar(removing: .title)
        .inspector(isPresented: presented) {
            assistant.surface(studio)
                .inspectorColumnWidth(ideal: 480)
                .environment(scint)
        }
    }
}
