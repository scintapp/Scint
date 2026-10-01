import SwiftUI
import ScintRuntime
import ScintComponents


struct DocumentMapper: Mapper {
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
}

struct DocumentOutlineMapper: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if ref.type is Transcript.Type { return model.session.transcript == ref }
                if let url = item.path { return model.session.selection.selected(ref, url) }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            },
            sectionDropTarget: { section in
                let space = model.session.projects
                return .init(ref: space, name: space.descriptor.name)
            },
            itemPalette: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        guard let doc = model.session.selection.content, let blocks = Document.with(doc, { $0.blocks })
                else { return .init() }

        let blockItems = blocks.compactMap {
            switch $0 {
                case .artifact(let ref):
                    return ItemParams(ref: ref, name: ref.descriptor.name)
                case .text(_, let content):
                    return ItemParams(name: content)
                default:
                    return ItemParams(name: "")
            }
        }

        return .init(
            id: "outline",
            name: "Outline",
            header: false,
            sections: [
                .init(
                    id: "space",
                    name: "Workspace",
                    header: false,
                    items: blockItems
                ),
            ]
        )
    }
}
