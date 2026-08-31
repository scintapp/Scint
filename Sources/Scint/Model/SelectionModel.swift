import Foundation


enum Focus: Codable, Equatable, Sendable {
    case content(Reference)
    case space(Reference)
    case interface(Reference)
    case entry(UUID)
    case url(URL)
    case nothing

    var resolved: Value {
        switch self {
            case .content(let ref), .space(let ref), .interface(let ref): .reference(ref)
            case .entry(let id): .string(id.uuidString)
            case .url(let url): .string(url.absoluteString)
            case .nothing: .string("")
        }
    }
}

struct Open: Codable, Equatable, Sendable {
    var material: Reference?
    var transcript: Reference?

    var resolved: Value {
        if let material { .collection([ "material": .reference(material)]) }
        else { .collection([ "material": .bool(false)]) }
    }

    mutating func open(_ ref: Reference) {
        switch ref.type {
            case is Material.Type: material = ref
            case is Transcript.Type: transcript = ref
            default: break
        }
    }

    mutating func close(_ ref: Reference) {
        switch ref.type {
            case is Material.Type: if material == ref { material = nil }
            case is Transcript.Type: if transcript == ref { transcript = nil }
            default: break
        }
    }
}

struct Selection: Codable, Equatable, Sendable {
    var structure: Reference?
    var interface: Reference?
    var content: Reference?
    var entry: UUID?
    var url: URL?

    enum Axis: Sendable { case structure, interface, content, entry, path }

    var resolved: Value {
        var values: [String: Value] = [:]
        if let structure { values["structure"] = .reference(structure) }
        if let interface { values["interface"] = .reference(interface) }
        if let content { values["content"] = .reference(content) }
        if let entry { values["entry"] = .string(entry.uuidString) }
        if let url { values["url"] = .string(url.absoluteString) }
        return .collection(values)
    }

    func selected(_ ref: Reference) -> Bool {
        switch ref.type {
            case is any Structural.Type: structure == ref
            case is any Functional.Type: interface == ref && entry == nil && url == nil
            case is any Malleable.Type: content == ref && entry == nil && url == nil
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
            case is Workspace.Type, is Space.Type:
                next.structure = ref
                next.interface = nil
                next.content = nil
                next.entry = nil
                next.url = url
            case is any Functional.Type:
                next.interface = ref
                next.content = nil
                next.entry = nil
                next.url = url
            case is any Malleable.Type:
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
