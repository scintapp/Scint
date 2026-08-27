import UniformTypeIdentifiers
import Foundation
import SwiftUI


extension UTType {
    nonisolated static let workspace = UTType(exportedAs: "com.kaechle.scint.workspace")
    nonisolated static let space = UTType(exportedAs: "com.kaechle.scint.space")
    nonisolated static let material = UTType(exportedAs: "com.kaechle.scint.material")
    nonisolated static let artifact = UTType(exportedAs: "com.kaechle.scint.artifact")
    nonisolated static let control = UTType(exportedAs: "com.kaechle.scint.control")
    nonisolated static let service = UTType(exportedAs: "com.kaechle.scint.service")
    nonisolated static var scint: [UTType] { [.workspace, .space, .material, .artifact, .control, .service] }
}

enum ReferenceTransfer {
    private struct Payload: Codable {
        let ref: Reference
        let origin: Reference?
    }

    static func handle(_ providers: [NSItemProvider], target: ItemParams) -> Bool {
        guard canDrop(on: target), let origin = target.ref else { return false }
        var accepted = false

        for provider in providers {
            for type in UTType.scint where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                accepted = true
                provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                    guard let data, let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
                    Task { @MainActor in
                        if move(payload.ref, by: payload.origin, to: origin) { await Runtime.shared.save() }
                    }
                }
                break
            }
        }

        return accepted
    }

    static func provider(for item: ItemParams) -> NSItemProvider? {
        guard
            let ref = transferableRef(for: item, create: true), let type = type(for: ref),
            let data = try? JSONEncoder().encode(Payload(ref: ref, origin: item.path == nil ? item.origin : nil))
                else { return nil }

        let provider = NSItemProvider()
        provider.suggestedName = item.name
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    static func dropTypes(for target: ItemParams) -> [UTType] {
        canDrop(on: target) ? UTType.scint : []
    }

    static func exists(_ ref: Reference) -> Bool {
        switch ref.type {
            case is Workspace.Type: Workspace.with(ref, { _ in true }) == true
            case is Space.Type: Space.with(ref, { _ in true }) == true
            case is Closure.Type: Closure.with(ref, { _ in true }) == true
            case is Bridge.Type: Bridge.with(ref, { _ in true }) == true
            case is Material.Type: Material.with(ref, { _ in true }) == true
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
        exists(ref) && (ref.type is any Functional.Type || ref.type is Transcript.Type)
    }

    static func canDrag(_ item: ItemParams) -> Bool {
        guard item.path == nil else { return transferableRef(for: item, create: false) != nil }
        guard let ref = item.ref, exists(ref) else { return false }
        return item.origin != nil || ref.type is Space.Type || canShare(ref)
    }

    static func canDrop(on target: ItemParams) -> Bool {
        guard target.path == nil, let ref = target.ref else { return false }
        return ref.type is Workspace.Type || ref.type is Space.Type
    }

    @discardableResult
    static func paste(_ refs: [Reference], by: Reference?, move: Bool, to origin: Reference) -> Reference? {
        var pasted: Reference?
        for ref in refs {
            if move {
                if Self.move(ref, by: origin, to: origin) { pasted = ref }
            } else if canShare(ref), attach(ref, to: origin) {
                pasted = ref
            }
        }
        return pasted
    }

    @discardableResult
    static func detach(_ ref: Reference, from origin: Reference?) -> Bool {
        if ref.type is Space.Type {
            let parent = origin ?? Space.with(ref, { $0.space }) ?? nil
            if let parent { return Space.update(ref) { $0.detach(from: parent) } != nil }
            return false
        }

        if ref.type is Bridge.Type {
            guard let origin else { return false }
            return Space.update(origin) { $0.bridges.remove(ref) != nil } ?? false
        }

        guard let origin else { return false }
        if let space = Space.with(origin, { $0 }) { space.remove(ref); return true }
        if let workspace = Workspace.with(origin, { $0 }) { workspace.remove(ref); return true }
        return false
    }

    private static func transferableRef(for item: ItemParams, create: Bool) -> Reference? {
        guard let ref = item.ref else { return nil }
        guard let path = item.path else { return ref }
        guard ref.type is Artifact.Type else { return nil }
        if Artifact.with(ref, { $0.handler.url }) == path { return ref }
        return create ? Artifact.register(item.name, path) : ref
    }

    private static func move(_ ref: Reference, by: Reference?, to origin: Reference) -> Bool {
        guard ref != origin else { return false }
        if ref.type is Space.Type, contains(ref, origin) { return false }
        detach(ref, from: origin)
        return attach(ref, to: origin)
    }

    private static func attach(_ ref: Reference, to origin: Reference) -> Bool {
        switch ref.type {
            case is Space.Type:
                return Space.update(ref) { $0.attach(to: origin) } != nil
            case is Artifact.Type, is Material.Type, is Transcript.Type, is any Functional.Type:
                if let space = Space.with(origin, { $0 }) { space.add(ref) }
                else if let workspace = Workspace.with(origin, { $0 }) { workspace.add(ref) }
                else { return false }
                if ref.type is Material.Type { Material.update(ref) { $0.origin = origin } }
                return true
            default:
                return false
        }
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
            case is Workspace.Type: .workspace
            case is Space.Type: .space
            case is Material.Type: .material
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
