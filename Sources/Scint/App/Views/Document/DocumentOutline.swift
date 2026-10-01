import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct DocumentOutline: Surface {
    var panel: any Panel
    var model: any Model
    var surface: AnySurface { .init(panel: panel, model: model) }

    var library: Reference { model.session.library }

    var documents: [Reference] {
        guard let docs = Space.with(library, { $0.documents }) else { return [] }
        return docs.filter { $0.descriptor.tags.isDisjoint(with: ["input", "automation"]) }
    }

    var document: Reference? { panel.state["document", as: Reference.self] ?? documents.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Style.Spacing.page) {
                ForEach(ArtifactsGroup.parameters(model).sections) { section in
                    GroupFactory.build(surface, section, ArtifactsGroup.controls(model))
                }
            }
            .font(Typography.body)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(20)
        }
        .frame(maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onChange(of: library) { panel.state["document", as: Reference.self] = nil }
    }
}


