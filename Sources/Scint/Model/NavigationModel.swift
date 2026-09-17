import Foundation


struct Navigation: Codable, Equatable, Sendable {
    private(set) var cursor: Int = 0
    private(set) var history: [Selection] = []
    private static let maxHistory = 100
    private static let maxPathDepth = 100

    var canGoBack: Bool { cursor > 0 }
    var canGoForward: Bool { cursor < history.count - 1 }

    func path(for selection: Selection) -> [Reference] {
        guard let structure = selection.structure else { return [] }
        var refs = spaces(to: structure).filter { $0.descriptor.name != "Spaces" }
        if let content = selection.content, pathable(content) { refs.append(content) }
        else if let interface = selection.interface { refs.append(interface) }
        return refs
    }

    func spaces(to space: Reference) -> [Reference] {
        var chain: [Reference] = []
        var cursor: Reference? = space
        var depth = 0

        while let current = cursor, depth < Self.maxPathDepth {
            chain.append(current)
            cursor = Space.with(current, { $0.space }) ?? nil
            depth += 1
        }

        return chain.reversed()
    }

    func pathable(_ ref: Reference) -> Bool {
        guard ref.type is Artifact.Type else { return true }
        return Artifact.with(ref) { artifact in
            switch artifact.handler {
                case .bookmark: return true
                case .app, .directory, .executable, .file, .image, .script, .skill: return false
            }
        } ?? true
    }

    mutating func push(_ selection: Selection) {
        if cursor < history.count - 1 { history.removeSubrange((cursor + 1)...) }
        history.append(selection)
        cursor = history.count - 1

        if history.count > Self.maxHistory {
            let drop = history.count - Self.maxHistory
            history.removeFirst(drop)
            cursor -= drop
        }
    }

    mutating func back() -> Selection? {
        guard canGoBack else { return nil }
        cursor -= 1
        return history[cursor]
    }

    mutating func forward() -> Selection? {
        guard canGoForward else { return nil }
        cursor += 1
        return history[cursor]
    }

    mutating func reset(to selection: Selection) {
        history = [selection]
        cursor = 0
    }
}
