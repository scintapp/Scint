import AppKit
import Foundation


struct EditorSegment: Identifiable {
    let id: UUID
    var text: String
    var attachments: [UUID: Entry]
    var selection: NSRange
}

enum EditorSegmentBuilder {
    static func build(from entries: [Entry]) -> [EditorSegment] {
        var buffer = TextBuffer()

        for entry in entries {
            switch entry {
            case .text(_, let string):
                buffer.text.append(string)
            case .artifact, .control, .service, .sheet, .todo:
                buffer.attachments[entry.id] = entry
                buffer.text.append(EditorAttachment.token(for: entry.id))
            }
        }

        return [buffer.flush()]
    }

    static func entries(from segments: [EditorSegment]) -> [Entry] {
        var result: [Entry] = []
        for segment in segments {
            appendTextEntries(text: segment.text, attachments: segment.attachments, into: &result)
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

    private struct TextBuffer {
        var text = ""
        var attachments: [UUID: Entry] = [:]

        mutating func flush() -> EditorSegment {
            let segment = EditorSegment(
                id: UUID(),
                text: text,
                attachments: attachments,
                selection: NSRange(location: 0, length: 0)
            )
            text = ""
            attachments = [:]
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
