import SwiftUI


struct Editor: View {
    @Environment(ScintModel.self) var scint

    var body: some View {
        @Bindable var editor = scint.editor

        NavigationSplitView {
            editor.navigator.surface(editor)
                .frame(maxWidth: 400, maxHeight: .infinity)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            editor.content.surface(editor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(removing: .title)
        }
    }
}
