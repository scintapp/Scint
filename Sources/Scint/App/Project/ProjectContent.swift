import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct ProjectContent: Surface {
    var host: any Host
    var model: any Model

    @State private var presentation: Presentation = .process

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
                    CanvasContent(host: host, model: model)

                case .process:
                    TranscriptContent(host: host, model: model)

                    ProjectIntent(model: model) { ProjectToolbar(host: host, model: model) }
                        .frame(alignment: .bottom)
                        .padding([.bottom, .vertical], 10)

            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.hard, for: .vertical)
        .safeAreaBar(edge: .top) { ProjectHeader(host: host, model: model, presentation: $presentation) }
    }
}


