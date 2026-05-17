import AppKit
import Foundation


enum EditorSegment: Identifiable {
    case text(TextSegment)
    case task(TaskSegment)

    struct TextSegment: Identifiable {
        let id: UUID
        var text: String
        var attachments: [UUID: Entry]
        var selection: NSRange
    }

    struct TaskSegment: Identifiable {
        let id: UUID
        var title: String
        var complete: Bool
    }

    var id: UUID {
        switch self {
        case .text(let s): return s.id
        case .task(let t): return t.id
        }
    }

    var isText: Bool { if case .text = self { return true }; return false }
    var isTask: Bool { if case .task = self { return true }; return false }
}

enum EditorSegmentBuilder {
    static func build(from entries: [Entry]) -> [EditorSegment] {
        var result: [EditorSegment] = []
        var buffer = TextBuffer()

        for entry in entries {
            switch entry {
            case .todo(let id, let title, let done):
                result.append(.text(buffer.flush()))
                result.append(.task(.init(id: id, title: title, complete: done)))
                buffer = TextBuffer()
            case .text(_, let s):
                buffer.text.append(s)
            case .artifact, .control, .sheet:
                buffer.attachments[entry.id] = entry
                buffer.text.append(EditorAttachment.token(for: entry.id))
            }
        }
        result.append(.text(buffer.flush()))

        if result.first?.isText == false {
            result.insert(.text(emptyText()), at: 0)
        }
        if result.last?.isText == false {
            result.append(.text(emptyText()))
        }
        return result
    }

    static func entries(from segments: [EditorSegment]) -> [Entry] {
        var result: [Entry] = []
        for seg in segments {
            switch seg {
            case .text(let s):
                appendTextEntries(text: s.text, attachments: s.attachments, into: &result)
            case .task(let t):
                result.append(.todo(t.id, t.title, t.complete))
            }
        }
        if result.isEmpty { result = [.text(UUID(), "")] }
        return result
    }

    static func filterAttachments(_ attachments: [UUID: Entry], keepingTokensIn text: String) -> [UUID: Entry] {
        var present = Set<UUID>()
        for match in EditorAttachment.matches(in: text) {
            if let id = EditorAttachment.id(in: match, text: text) { present.insert(id) }
        }
        return attachments.filter { present.contains($0.key) }
    }

    private static func emptyText() -> EditorSegment.TextSegment {
        .init(id: UUID(), text: "", attachments: [:], selection: NSRange(location: 0, length: 0))
    }

    private struct TextBuffer {
        var text: String = ""
        var attachments: [UUID: Entry] = [:]

        mutating func flush() -> EditorSegment.TextSegment {
            let segment = EditorSegment.TextSegment(
                id: UUID(),
                text: text,
                attachments: attachments,
                selection: NSRange(location: 0, length: 0)
            )
            text = ""; attachments = [:]
            return segment
        }
    }

    private static func appendTextEntries(text: String, attachments: [UUID: Entry], into out: inout [Entry]) {
        let ns = text as NSString
        let matches = EditorAttachment.matches(in: text)
        var cursor = 0
        for match in matches {
            if match.range.location > cursor {
                let chunk = ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                if !chunk.isEmpty { out.append(.text(UUID(), chunk)) }
            }
            if let id = EditorAttachment.id(in: match, text: text),
               let entry = attachments[id] {
                out.append(entry)
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            let chunk = ns.substring(from: cursor)
            if !chunk.isEmpty { out.append(.text(UUID(), chunk)) }
        }
    }
}
