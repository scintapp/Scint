import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ScintRuntime


extension UTType {
    nonisolated static let space = UTType(exportedAs: "com.kaechle.scint.space")
    nonisolated static let document = UTType(exportedAs: "com.kaechle.scint.document")
    nonisolated static let artifact = UTType(exportedAs: "com.kaechle.scint.artifact")
    nonisolated static let control = UTType(exportedAs: "com.kaechle.scint.control")
    nonisolated static let service = UTType(exportedAs: "com.kaechle.scint.service")
    nonisolated static let block = UTType(filenameExtension: "scintblock", conformingTo: .data) ?? .data
    nonisolated static var scint: [UTType] { [.space, .space, .document, .artifact, .control, .service] }
}

enum ReferenceTransfer {
    private enum Payload: Codable {
        case reference(Reference)
        case file(URL, name: String)
    }

    static func origin(of ref: Reference) -> Reference? {
        if ref.type is Space.Type { return Space.with(ref, { $0.space }) ?? nil }
        if let origin = Document.with(ref, { $0.origin }) { return origin }
        return nil
    }

    static func canDrag(_ ref: Reference) -> Bool {
        guard exists(ref) else { return false }
        return origin(of: ref) != nil || canShare(ref)
    }

    static func canDrop(on ref: Reference) -> Bool {
        ref.type is Space.Type
    }

    static func dropTypes(for ref: Reference) -> [UTType] {
        canDrop(on: ref) ? UTType.scint : []
    }

    static func provider(for ref: Reference) -> NSItemProvider? {
        guard exists(ref), let type = type(for: ref) else { return nil }
        return provider(.reference(ref), as: type, named: ref.descriptor.name)
    }

    static func provider(forFile url: URL, named name: String) -> NSItemProvider? {
        provider(.file(url, name: name), as: .artifact, named: name)
    }

    static func handle(_ providers: [NSItemProvider], target: Reference, sharing: Bool = false) -> Bool {
        guard canDrop(on: target) else { return false }
        return receive(providers) { move($0, from: nil, to: target, sharing: sharing) }
    }

    static func detach(_ providers: [NSItemProvider]) -> Bool {
        receive(providers) { detach($0, from: nil) }
    }

    private static func receive(_ providers: [NSItemProvider], _ apply: @escaping @MainActor @Sendable (Reference) -> Bool) -> Bool {
        var accepted = false

        for provider in providers {
            for type in UTType.scint where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                accepted = true
                provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                    guard let data, let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
                    Task { @MainActor in
                        let moved = switch payload {
                            case .reference(let ref): apply(ref)
                            case .file(let url, let name): apply(Artifact.new(name, url))
                        }
                        if moved { await Runtime.shared.save() }
                    }
                }
                break
            }
        }

        return accepted
    }

    private static func provider(_ payload: Payload, as type: UTType, named name: String) -> NSItemProvider? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }

        let provider = NSItemProvider()
        provider.suggestedName = name
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    static func handle(_ providers: [NSItemProvider], target: ItemParams, sharing: Bool = false) -> Bool {
        guard target.path == nil, let ref = target.ref else { return false }
        return handle(providers, target: ref, sharing: sharing)
    }

    static func provider(for item: ItemParams) -> NSItemProvider? {
        guard let ref = item.ref else { return nil }
        guard let path = item.path else { return provider(for: ref) }
        guard ref.type is Artifact.Type else { return nil }
        if Artifact.with(ref, { $0.handler.url }) == path { return provider(for: ref) }
        return provider(forFile: path, named: item.name)
    }

    static func dropTypes(for target: ItemParams) -> [UTType] {
        guard target.path == nil, let ref = target.ref else { return [] }
        return dropTypes(for: ref)
    }

    static func canDrag(_ item: ItemParams) -> Bool {
        guard let ref = item.ref else { return false }
        guard item.path == nil else { return ref.type is Artifact.Type }
        return canDrag(ref)
    }

    static func canDrop(on target: ItemParams) -> Bool {
        guard target.path == nil, let ref = target.ref else { return false }
        return canDrop(on: ref)
    }

    static func exists(_ ref: Reference) -> Bool {
        switch ref.type {
            case is Space.Type: Space.with(ref, { _ in true }) == true
            case is Closure.Type: Closure.with(ref, { _ in true }) == true
            case is Bridge.Type: Bridge.with(ref, { _ in true }) == true
            case is ScintRuntime.Document.Type: Document.with(ref, { _ in true }) == true
            case is Transcript.Type: Transcript.with(ref, { _ in true }) == true
            case is Artifact.Type: Artifact.with(ref, { _ in true }) == true
            case is Command.Type: Command.with(ref, { _ in true }) == true
            case is Harness.Type: Harness.with(ref, { _ in true }) == true
            default: false
        }
    }

    static func canPaste(_ refs: [Reference], move: Bool, to origin: Reference) -> Bool {
        !refs.contains(origin) && (move || refs.allSatisfy(canShare))
    }

    static func canShare(_ ref: Reference) -> Bool {
        exists(ref) && (ref.type is any Functional.Type || ref.type is ScintRuntime.Document.Type)
    }

    @discardableResult
    static func paste(_ refs: [Reference], by source: Reference?, move shouldMove: Bool, to origin: Reference) -> Reference? {
        var pasted: Reference?
        for ref in refs {
            if shouldMove {
                if move(ref, from: source, to: origin) { pasted = ref }
            } else if canShare(ref), move(ref, from: nil, to: origin, sharing: true) {
                pasted = ref
            }
        }
        return pasted
    }

    @discardableResult
    static func detach(_ ref: Reference, from origin: Reference?) -> Bool {
        if ref.type is Space.Type {
            guard let parent = origin ?? (Space.with(ref, { $0.space }) ?? nil) else { return false }
            if Space.with(parent, { _ in true }) == true {
                Space.update(parent) { $0.detach(child: ref) }
                return true
            }
            return false
        }

        if ref.type is Bridge.Type {
            guard let origin else { return false }
            return Space.update(origin) { $0.bridges.remove(ref) != nil } ?? false
        }

        guard let origin else { return false }
        if let space = Space.with(origin, { $0 }) { space.remove(ref); return true }
        return false
    }

    @discardableResult
    private static func move(_ ref: Reference, from source: Reference?, to destination: Reference, sharing: Bool = false) -> Bool {
        guard ref != destination, type(for: ref) != nil else { return false }

        if ref.type is Space.Type {
            guard !contains(ref, destination) else { return false }
            if Space.with(destination, { _ in true }) == true {
                Space.update(destination) { $0.attach(child: ref) }
                return true
            }
            return false
        }

        if !sharing, let source = source ?? Self.origin(of: ref), source != destination, relocates(ref, from: source) {
            detach(ref, from: source)
        }

        if let space = Space.with(destination, { $0 }) {
            let origin = Self.origin(of: ref)
            space.add(ref)
            if sharing, let origin, ref.type is ScintRuntime.Document.Type {
                Document.update(ref) { $0.origin = origin }
            }
        }
        else { return false }

        return true
    }

    private static func relocates(_ ref: Reference, from source: Reference) -> Bool {
        ref.type is Space.Type || origin(of: ref) != nil
    }

    private static func contains(_ child: Reference, _ parent: Reference) -> Bool {
        var cursor: Reference? = parent
        while let current = cursor {
            if current == child { return true }
            cursor = Space.with(current) { $0.space } ?? nil
        }
        return false
    }

    private static func type(for ref: Reference) -> UTType? {
        switch ref.type {
            case is Space.Type: .space
            case is ScintRuntime.Document.Type: .document
            case is Artifact.Type: .artifact
            case is Command.Type: .control
            case is Harness.Type: .service
            default: nil
        }
    }
}

struct ItemContextMenu: View {
    let params: ItemParams
    let onRename: (() -> Void)?
    let onDuplicate: (() -> Void)?
    let onDelete: (() -> Void)?
    let onAddChild: (() -> Void)?

    var body: some View {
        if let onRename { Button("Rename", action: onRename) }
        if let onDuplicate { Button("Duplicate", action: onDuplicate) }
        if let onAddChild { Button("Add Item", action: onAddChild) }
        if let onDelete { Divider(); Button("Delete", role: .destructive, action: onDelete) }
    }
}
