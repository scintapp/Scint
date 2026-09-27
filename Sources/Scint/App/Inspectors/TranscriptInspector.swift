import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct TranscriptInspector: Surface {
    var panel: any Panel
    var model: any Model
    var surface: AnySurface { .init(panel: panel, model: model) }

    var space: Reference? {
        guard model.session.selection.root == model.session.projects else { return nil }
        return model.session.selection.structure
    }

    var documents: [Reference] {
        guard let space, let docs = Space.with(space, { $0.documents }) else { return [] }
        return docs.filter { $0.descriptor.tags.isDisjoint(with: ["input", "automation"]) }
    }

    var document: Reference? { panel.state["document", as: Reference.self] ?? documents.first }

    static func summary(_ ref: Reference) -> String {
        let texts: [String] = Document.with(ref) { document in
            document.blocks.compactMap { block -> String? in
                guard case .text(_, let text) = block else { return nil }
                return text
            }
        } ?? []
        let prose = texts.map { text -> String in
            let source = text as NSString
            let stripped = NSMutableString(string: text)
            for link in Markdown.scan(text).links.reversed() {
                let label = Reference.Link.isReference(source.substring(with: link.url)) ? "" : source.substring(with: link.label)
                stripped.replaceCharacters(in: link.range, with: label)
            }
            return stripped as String
        }
        let lines = prose.flatMap { $0.components(separatedBy: .newlines) }.map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.filter { !$0.isEmpty && Markdown.classify($0) == .paragraph }.prefix(3).joined(separator: " ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Style.Spacing.page) {
                if let space, let document {
                    OutlineHeader(ref: document, space: space, documents: documents, panel: panel, model: model)
                    OutlineTasks(ref: document)
                    OutlineContext(ref: document, model: model)
                }

                ForEach(ArtifactsGroup.parameters(model).sections) { section in
                    Factory.build(surface, params: section, controls: ArtifactsGroup.controls(model), layout: .group)
                }
            }
            .font(Typography.body)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(20)
        }
        .frame(maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onChange(of: space) { panel.state["document", as: Reference.self] = nil }
    }
}
