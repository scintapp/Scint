import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct ProjectContent: Surface {
    var panel: any Panel
    var model: any Model

    @State private var presentation: Presentation = .process

    var projects: Reference { model.session.projects }
    var space: Reference? { model.session.selection.structure }

    enum Presentation: String, CaseIterable {
        case process, canvas

        var image: String {
            switch self {
                case .process: "flowchart"
                case .canvas: "point.3.connected.trianglepath.dotted"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            switch presentation {
                case .canvas:
                    CanvasContent(panel: panel, model: model)

                case .process:
                    if let space, let context = space.context, let transcript = context.transcript {
                        TranscriptContent(transcript: transcript)
                    }
                    ProjectToolbar(panel: panel, model: model, onStart: {})
                        .frame(alignment: .bottom)
                        .padding([.bottom, .vertical], 10)

            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .top) {
            ProjectHeader(
                panel: panel,
                model: model,
                presentation: $presentation
            )
        }
    }
}


