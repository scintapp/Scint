import SwiftUI
import ScintRuntime
import ScintComponents


@MainActor struct EditorIO {
    let ref: Reference

    static func block(_ id: UUID, markdown: String) -> Block {
        let elements = Markdown.elements(markdown)
        let parsed: Block? = switch elements.count == 1 ? elements.first : nil {
            case .text(.heading(let level), let text, _, _)?: .heading(id, level, text)
            case .code(let text, let language)?: .code(id, language, text)
            default: nil
        }
        return parsed.flatMap { Self.markdown($0) == markdown ? $0 : nil } ?? .paragraph(id, markdown)
    }

    static func markdown(_ block: Block) -> String? {
        switch block {
            case .paragraph(_, let text): text
            case .heading(_, let level, let text): String(repeating: "#", count: level) + " " + text
            case .code(_, let language, let text): "```\(language)\n\(text)\n```"
            default: nil
        }
    }

    static func reference(_ block: Block) -> Reference? {
        switch block {
            case .artifact(let ref), .command(let ref), .document(let ref):
                return ref
            case .paragraph(_, let text):
                let source = text as NSString
                guard let link = Markdown.scan(text).links.first, link.range.length == source.length else { return nil }
                return Runtime.shared.resolve(source.substring(with: link.url))
            default:
                return nil
        }
    }

    static func edits(_ block: Block) -> Bool {
        switch block {
            case .task, .heading, .code: true
            case .paragraph(_, let text): Markdown.Table(text) == nil
            default: false
        }
    }

    var blocks: [Block] { ScintRuntime.Document.with(ref, { $0.blocks }) ?? [] }

    var body: [Block] { Array(blocks.dropFirst(header)) }

    private var header: Int {
        ScintRuntime.Document.with(ref, { $0.header.content == .task ? 1 : 0 }) ?? 0
    }

    func position(_ index: Int) -> Int { header + index }

    func block(_ id: AnyHashable) -> Block? { blocks.first { $0.id == id } }

    func text(of id: AnyHashable) -> String {
        switch block(id) {
            case .task(_, let text, _)?: text
            case let block?: Self.markdown(block) ?? ""
            case nil: ""
        }
    }

    func write(_ id: AnyHashable, _ text: String) {
        update(id) { block in
            switch block {
                case .paragraph(let uuid, _), .heading(let uuid, _, _), .code(let uuid, _, _): Self.block(uuid, markdown: text)
                case .task(let uuid, _, let completed): .task(uuid, text, completed)
                default: block
            }
        }
    }

    func split(_ id: AnyHashable, _ before: String, _ after: String) -> AnyHashable {
        let next = Self.block(UUID(), markdown: after)
        write(id, before)
        insert(next, after: id)
        return next.id
    }

    func join(_ id: AnyHashable, into above: AnyHashable) -> (id: AnyHashable, caret: Int)? {
        let text = self.text(of: id)
        switch (block(above), block(above).flatMap(Self.markdown)) {
            case (.task(let uuid, let previous, let completed)?, _):
                update(above) { _ in .task(uuid, previous + text, completed) }
                delete(id)
                return (above, (previous as NSString).length)
            case (let block?, let previous?) where Self.edits(block):
                write(above, previous + text)
                delete(id)
                return (above, (previous as NSString).length)
            default:
                return nil
        }
    }

    func toggle(_ id: AnyHashable) {
        update(id) { block in if case .task(let uuid, let text, let completed) = block { .task(uuid, text, !completed) } else { block } }
    }

    func splitTask(_ id: AnyHashable, _ before: String, _ after: String) -> AnyHashable {
        let next = Block.task(UUID(), after, false)
        update(id) { block in if case .task(let uuid, _, let completed) = block { .task(uuid, before, completed) } else { block } }
        insert(next, after: id)
        return next.id
    }

    func delete(_ id: AnyHashable) {
        ScintRuntime.Document.update(ref) { document in
            if let index = document.blocks.firstIndex(where: { $0.id == id }) { document.delete(at: index) }
        }
    }

    func insert(_ block: Block, after id: AnyHashable) {
        ScintRuntime.Document.update(ref) { document in
            let index = document.blocks.firstIndex { $0.id == id }
            document.insert(block, at: index.map { $0 + 1 })
        }
    }

    func insert(_ blocks: [Block], into id: AnyHashable, at offset: Int) -> Bool {
        var continued = false
        ScintRuntime.Document.update(ref) { document in
            guard let index = document.blocks.firstIndex(where: { $0.id == id }) else { return document.insert(blocks, at: nil) }
            guard let text = Self.markdown(document.blocks[index]), let uuid = document.blocks[index].id as? UUID
            else { return document.insert(blocks, at: index + 1) }
            let source = text as NSString, split = min(offset, source.length)
            let before = source.substring(to: split).trimmingCharacters(in: .newlines)
            let after = source.substring(from: split).trimmingCharacters(in: .newlines)
            continued = !after.isEmpty
            document.delete(at: index)
            document.insert((before.isEmpty ? [] : [Self.block(uuid, markdown: before)]) + blocks + (after.isEmpty ? [] : [Self.block(UUID(), markdown: after)]), at: index)
        }
        return continued
    }

    private func update(_ id: AnyHashable, _ change: (Block) -> Block) {
        ScintRuntime.Document.update(ref) { document in
            if let index = document.blocks.firstIndex(where: { $0.id == id }) { document.update(change(document.blocks[index]), at: index) }
        }
    }
}
