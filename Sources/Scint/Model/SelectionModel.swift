import Foundation
import ScintRuntime


 enum Focus: Codable, Equatable, Sendable {
    case content(Reference)
    case structure(Reference)
    case interface(Reference)
    case entry(UUID)
    case url(URL)
    case nothing

     var ref: Reference? {
        switch self {
            case .content(let ref), .structure(let ref), .interface(let ref): ref
            default: nil
        }
    }

     var entry: UUID? {
        switch self {
            case .entry(let id): id
            default: nil
        }
    }

     var link: URL? {
        switch self {
            case .url(let url): url
            default: nil
        }
    }

     var resolved: Value {
        switch self {
            case .content(let ref), .structure(let ref), .interface(let ref): .reference(ref)
            case .entry(let id): .property(.string(id.uuidString))
            case .url(let url): .property(.string(url.absoluteString))
            case .nothing: .property("")
        }
    }
}

 struct Opened: Codable, Equatable, Sendable {
     var document: Reference?
     var transcript: Reference?

    init(document: Reference? = nil, transcript: Reference? = nil) {
        self.document = document
        self.transcript = transcript
    }

     mutating func open(_ ref: Reference) {
        switch ref.type {
            case is ScintRuntime.Document.Type: document = ref
            case is ScintRuntime.Transcript.Type: transcript = ref
            default: break
        }
    }

     mutating func close(_ ref: Reference) {
        switch ref.type {
            case is ScintRuntime.Document.Type: if document == ref { document = nil }
            case is ScintRuntime.Transcript.Type: if transcript == ref { transcript = nil }
            default: break
        }
    }
}

 struct Selection: Codable, Equatable, Sendable  {
     var structure: Reference?
     var interface: Reference?
     var content: Reference?
     var entry: UUID?
     var url: URL?

     enum Axis: Sendable { case structure, interface, content, entry, path }

    init(
        structure: Reference? = nil,
        interface: Reference? = nil,
        content: Reference? = nil,
        entry: UUID? = nil,
        url: URL? = nil
    ) {
        self.structure = structure
        self.interface = interface
        self.content = content
        self.entry = entry
        self.url = url
    }

     var resolved: Value {
        var values: [String: Value] = [:]
        if let structure { values["structure"] = .reference(structure) }
        if let interface { values["interface"] = .reference(interface) }
        if let content { values["content"] = .reference(content) }
        if let entry { values["entry"] = .property(.string(entry.uuidString)) }
        if let url { values["url"] = .property(.string(url.absoluteString)) }
        return .collection(values)
    }

     var root: Reference? {
        guard var cursor = structure else { return nil }
        var depth = 0

        while let parent = Space.with(cursor, { $0.space }) ?? nil, (Space.with(parent, { $0.space }) ?? nil) != nil, depth < 100 {
            cursor = parent
            depth += 1
        }
        return cursor
    }


     func selected(_ ref: Reference) -> Bool {
        switch ref.type {
            case is any ScintRuntime.Structural.Type: structure == ref
            case is any ScintRuntime.Functional.Type: interface == ref && entry == nil && url == nil
            case is any ScintRuntime.Material.Type: content == ref && entry == nil && url == nil
            default: false
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

     func selecting(_ ref: Reference, _ entry: UUID? = nil, _ url: URL? = nil) -> Self {
        var next = self
        switch ref.type {
            case is ScintRuntime.Space.Type:
                next.structure = ref
                next.interface = nil
                next.content = nil
                next.entry = nil
                next.url = url
            case is any ScintRuntime.Functional.Type:
                next.interface = ref
                next.content = nil
                next.entry = nil
                next.url = url
            case is any ScintRuntime.Material.Type:
                next.interface = nil
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
