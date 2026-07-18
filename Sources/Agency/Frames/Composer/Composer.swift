import AgencyRuntime
import SwiftUI


@Observable @MainActor final class ComposerModel: Model {
    var actions: Actions
    var canvas: Canvas
    var files: FileProvider
    var session: SessionModel

    init(_ workspace: Reference) {
        self.actions = .init()
        self.canvas = .init()
        self.files = .init(workspace)
        self.session = .init(workspace)
    }
}

struct Composer: View {
    @Environment(ComposerModel.self) var composer

    var body: some View {
        composer.canvas.surface(composer)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .toolbar(removing: .title)
    }
}
