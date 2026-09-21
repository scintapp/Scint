import Foundation
import ScintRuntime




enum ContentTool {

    enum Content { case document, transcript }

    static func new(_ name: String, _ blocks: [Document.Block], in space: Reference) -> Reference {
        let document = Document.new(space, name: name)
        Document.update(document) { $0.insert(blocks, at: nil) }
        return document
    }

    static func with(_ content: Reference) -> ScintRuntime.Document? {
        Document.with(content, { $0 })
    }

    static func update(_ document: Reference, with block: Document.Block, at index: Int?) -> Reference? {
        Document.update(document) { value in
            if let index { value.update(block, at: index) }
            else { value.insert(block, at: nil) }
            return document
        }
    }
}

enum InterfaceTool {
    enum Method { case command, harness }

    static func with(_ content: Reference) -> (any Functional)? {
        if let command = Command.with(content, { $0 }) { return command }
        return Harness.with(content, { $0 })
    }

    static func update(_ content: Reference, in space: Reference) -> Reference? {
        Space.with(space) {
            $0.add(content)
            return content
        }
    }
}

enum StructureTool {
    static func new(_ name: String, in parent: Reference) -> Reference {
        Space.new(parent, name: name)
    }

    static func with(_ content: Reference) -> Space? {
        Space.with(content, { $0 })
    }

    static func update(_ content: Reference, in space: Reference) -> Reference? {
        Space.with(space) {
            $0.add(content)
            return content
        }
    }

    static func remove(_ content: Reference) async throws {
        await Runtime.shared.remove(content)
    }
}

enum ComposeTool {
    enum Activity { case start, stop }
    enum Intent { case dispatch, evaluate, search }

    static func compose(_ activity: Activity, for space: Reference) -> Composition? {
        switch activity {
            case .start: Runtime.shared.start(space)
            case .stop: Runtime.shared.stop(space)
        }
    }

    static func context(for space: Reference) -> Composition? {
        Runtime.shared.resolve(space)
    }
}

enum DispatchTool {
    static func dispatch(_ query: String) async throws -> SearchResults {
        fatalError("TODO")
    }
}

enum EvaluateTool {
    static func goal(_ query: String) async throws {
        fatalError("TODO")
    }

    static func planning(_ query: String) async throws {
        fatalError("TODO")
    }
}

enum SearchTool {
    enum Strategy { case research, locate, update }
    enum Target { case content, file, link }

    static func search(_ query: String) async throws -> SearchResults {
        fatalError("TODO")
    }
}

struct ContextProvider {
    static var content: ContentTool.Type { ContentTool.self }
    static var interface: InterfaceTool.Type { InterfaceTool.self }
    static var structure: StructureTool.Type { StructureTool.self }
    static var compose: ComposeTool.Type { ComposeTool.self }
    static var dispatch: DispatchTool.Type { DispatchTool.self }
    static var evaluate: EvaluateTool.Type { EvaluateTool.self }
    static var search: SearchTool.Type { SearchTool.self }
    static var context: [Composition] { Runtime.shared.resolve() }
}
