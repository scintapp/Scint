import Foundation


// Base Tools

/// Core operations over content known to the runtime.
///
/// MCP owns the external schemas for these operations. The block vocabulary is provisional while
/// the editable agent surface is being decided; it must not be treated as a second content model.
enum ContentTool {
    /// The runtime block representation accepted by material operations.
    typealias Block = Material.Block

    /// The runtime content kinds this tool family may render.
    enum Content { case material, transcript }

    /// Creates runtime content with a caller-supplied name and initial blocks.
    ///
    /// Block payload and multi-block editing behavior are intentionally unspecified in this pass.
    static func new(_ name: String, _ blocks: [Block], in space: Reference) -> Reference {
        let material = Material.new(space, name: name)
        Material.update(material) { $0.insert(blocks, at: nil) }
        return material
    }

    /// Returns the referenced material from the runtime when it exists.
    static func with(_ content: Reference) -> Material? {
        Material.with(content, { $0 })
    }

    /// Updates one material block at the requested position and returns the material reference.
    ///
    /// The exact block payload is intentionally unspecified until the editable block surface is
    /// settled. This operation does not define persistence independently of the runtime.
    static func update(_ material: Reference, with block: Block, at index: Int?) -> Reference? {
        Material.update(material) { value in
            if let index { value.update(block, at: index) }
            else { value.insert(block, at: nil) }
            return material
        }
    }
}

/// Core operations over runtime interfaces.
///
/// Command exposure is deferred. Harnesses describe semantic runtime behavior and are not exposed
/// as concrete MCP tools by this type.
enum InterfaceTool {
    /// The runtime interface kinds this tool family may address.
    enum Method { case command, harness }

    /// Returns the referenced runtime interface when it exists.
    static func with(_ content: Reference) -> (any Functional)? {
        if let command = Command.with(content, { $0 }) { return command }
        return Harness.with(content, { $0 })
    }

    /// Makes the referenced interface available in the referenced space.
    static func update(_ content: Reference, in space: Reference) -> Reference? {
        Space.with(space) {
            $0.add(content)
            return content
        }
    }
}

/// Core operations over runtime structures.
enum StructureTool {
    /// Creates a named space under the referenced parent space.
    static func new(_ name: String, in parent: Reference) -> Reference {
        Space.new(parent, name: name)
    }

    /// Returns the referenced space from the runtime when it exists.
    static func with(_ content: Reference) -> Space? {
        Space.with(content, { $0 })
    }

    /// Adds or attaches the referenced runtime value to the referenced space.
    static func update(_ content: Reference, in space: Reference) -> Reference? {
        Space.with(space) {
            $0.add(content)
            return content
        }
    }

    /// Deletes the referenced runtime value through its own deletion behavior.
    static func delete(_ content: Reference) async throws -> Reference {
        try await content.delete()
        return content
    }
}


// Intent Tools (Harness/Semantic Type)

/// Controls composition activity for spaces whose harness defines their semantic behavior.
///
/// Compose harnesses orchestrate the spaces beneath them. This tool does not implement that
/// orchestration or bypass the runtime's composition machinery.
enum ComposeTool {
    /// The lifecycle transition requested of a composition.
    enum Activity { case start, stop }

    /// Harness semantics that may participate in a composition.
    enum Intent { case dispatch, evaluate, search }

    /// Requests a start or stop transition for the referenced space.
    static func compose(_ activity: Activity, for space: Reference) -> Composition? {
        switch activity {
            case .start: Runtime.shared.start(space)
            case .stop: Runtime.shared.stop(space)
        }
    }

    /// Returns the live runtime composition for the referenced space, if one exists.
    static func context(for space: Reference) -> Composition? {
        Runtime.shared.resolve(space)
    }
}

/// Invokes dispatcher-harness semantics for a request.
///
/// Dispatchers route work; their selection and execution behavior is not yet present in the
/// runtime and remains stubbed in this pass.
enum DispatchTool {
    /// Dispatches a request and returns the runtime's resulting matches.
    static func dispatch(_ query: String) async throws -> SearchResults {
        fatalError("TODO")
    }
}

/// Invokes evaluator-harness semantics for a regular agent runtime.
///
/// Goal and planning behavior is not yet present in the runtime and remains stubbed in this pass.
enum EvaluateTool {
    /// Gives the evaluator a goal.
    static func goal(_ query: String) async throws {
        fatalError("TODO")
    }

    /// Gives the evaluator a planning request.
    static func planning(_ query: String) async throws {
        fatalError("TODO")
    }
}

/// Invokes search-harness semantics for research across external or distributed data planes.
///
/// This is distinct from `Runtime.search`, which searches the local catalog.
enum SearchTool {
    /// The semantic approach requested of a search harness.
    enum Strategy { case research, locate, update }

    /// The kind of result the search harness is intended to pursue.
    enum Target { case content, file, link }

    /// Runs a semantic search request.
    static func search(_ query: String) async throws -> SearchResults {
        fatalError("TODO")
    }
}


// Provider

/// Stateless access to the MCP-facing runtime tool families and current compositions.
///
/// The provider retains no request or runtime snapshot. Every access resolves against current
/// runtime state, and the tool families expose only static operations.
struct ContextProvider {
    static var content: ContentTool.Type { ContentTool.self }
    static var interface: InterfaceTool.Type { InterfaceTool.self }
    static var structure: StructureTool.Type { StructureTool.self }
    static var compose: ComposeTool.Type { ComposeTool.self }
    static var dispatch: DispatchTool.Type { DispatchTool.self }
    static var evaluate: EvaluateTool.Type { EvaluateTool.self }
    static var search: SearchTool.Type { SearchTool.self }

    /// The compositions currently resolved by the runtime.
    static var context: [Composition] { Runtime.shared.resolve() }
}
