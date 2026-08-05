import SwiftUI


@Observable @MainActor final class PaletteModel: Model {
    var search: SearchPalette
    var files: FileProvider
    var session: Session

    init(_ workspace: Reference) {
        self.search = .init()
        self.files = .init(workspace)
        self.session = .init(workspace)
    }
}

struct ScintPalette: View {
    @Environment(ScintModel.self) var scint

    var body: some View {
        scint.palette.search.panel(scint.palette)
            .frame(maxWidth: 400, maxHeight: .infinity)
            .toolbar(removing: .sidebarToggle)
            .environment(scint)
    }
}

