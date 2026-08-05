import Foundation


enum Focus: Equatable, Sendable {
    case content(Reference)
    case structure(Reference)
    case interface(Reference)
    case entry(UUID)
    case url(URL)
    case nothing

    var resolved: Value {
        switch self {
            case .content(let ref), .structure(let ref), .interface(let ref):
                return .reference(ref)
            case .entry(let id):
                return .string(id.uuidString)
            case .url(let url):
                return .string(url.absoluteString)
            case .nothing:
                return .string("")
        }
    }
}

struct Open: Equatable, Sendable {
    var sheets: [Reference] = []
    var transcripts: [Reference] = []

    var resolved: Value {
        .collection([
            "sheets": .sequence(sheets.map(Value.reference)),
            "transcripts": .sequence(transcripts.map(Value.reference))
        ])
    }

    @discardableResult
    mutating func open(_ ref: Reference) -> Bool {
        switch ref.type {
            case is Sheet.Type:
                if !sheets.contains(ref) { sheets.append(ref) }
                return true
            case is Transcript.Type:
                if !transcripts.contains(ref) { transcripts.append(ref) }
                return true
            default:
                return false
        }
    }

    @discardableResult
    mutating func close(_ ref: Reference) -> Bool {
        let sheetsCount = sheets.count
        let transcriptsCount = transcripts.count
        sheets.removeAll { $0 == ref }
        transcripts.removeAll { $0 == ref }
        return sheets.count != sheetsCount || transcripts.count != transcriptsCount
    }
}

struct Selection: Equatable, Sendable {
    var structure: Reference?
    var interface: Reference?
    var content: Reference?
    var entry: UUID?
    var url: URL?

    enum Axis: Sendable { case structure, interface, content, entry, path }

    var space: Reference? {
        guard let structure, structure.type is Space.Type else { return nil }
        return structure
    }

    var resolved: Value {
        var values: [String: Value] = [:]
        if let structure { values["structure"] = .reference(structure) }
        if let interface { values["interface"] = .reference(interface) }
        if let content {
            if content.type is Transcript.Type { values["transcript"] = .reference(content) }
            else { values["content"] = .reference(content) }
        }
        if let entry { values["entry"] = .string(entry.uuidString) }
        if let url { values["url"] = .string(url.absoluteString) }
        return .collection(values)
    }

    func selected(_ ref: Reference) -> Bool {
        switch ref.type {
            case is Workspace.Type, is Space.Type: return structure == ref
            case is any Functional.Type: return interface == ref && entry == nil && url == nil
            case is any Malleable.Type: return content == ref && entry == nil && url == nil
            default: return false
        }
    }

    func selected(_ ref: Reference, _ entry: UUID?) -> Bool {
        guard let entry else { return selected(ref) }
        return content == ref && self.entry == entry
    }

    func selected(_ ref: Reference, _ url: URL?) -> Bool {
        guard let url else { return selected(ref) }
        return (content == ref || interface == ref) && self.url == url
    }

    func selecting(_ ref: Reference, entry: UUID? = nil, url: URL? = nil) -> Self {
        var next = self
        switch ref.type {
            case is Workspace.Type, is Space.Type:
                next.structure = ref
                next.interface = nil
                next.content = nil
                next.entry = entry
                next.url = url
            case is any Functional.Type:
                next.interface = ref
                next.entry = entry
                next.url = url
            case is any Malleable.Type:
                next.content = ref
                next.entry = entry
                next.url = url
            default: break
        }
        return next
    }

    func clearing(_ axis: Axis) -> Self {
        var next = self
        switch axis {
            case .path:
                next.url = nil
            case .entry:
                next.entry = nil
            case .content:
                next.content = nil
                next.entry = nil
                next.url = nil
            case .interface:
                next.interface = nil
                next.url = nil
            case .structure:
                next.interface = nil
                next.content = nil
                next.entry = nil
                next.url = nil
        }
        return next
    }
}
