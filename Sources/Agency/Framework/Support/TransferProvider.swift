import UniformTypeIdentifiers
import SwiftUI
import AgencyRuntime
import Foundation


extension UTType {
    nonisolated static let workspace = UTType(exportedAs: "com.kaechle.Agency.workspace")
    nonisolated static let space = UTType(exportedAs: "com.kaechle.Agency.space")
    nonisolated static let sheet = UTType(exportedAs: "com.kaechle.Agency.sheet")
    nonisolated static let artifact = UTType(exportedAs: "com.kaechle.Agency.artifact")
    nonisolated static let control = UTType(exportedAs: "com.kaechle.Agency.control")
    nonisolated static let service = UTType(exportedAs: "com.kaechle.Agency.service")

    nonisolated static var agency: [UTType] { [.workspace, .space, .sheet, .artifact, .control, .service] }
}

enum ReferenceTransfer {
    private struct Payload: Codable {
        let ref: Reference
        let origin: Reference?
    }

    static func provider(for item: ItemParams) -> NSItemProvider? {
        guard let ref = transferableRef(for: item, create: true), let type = type(for: ref),
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

    static func canDrag(_ item: ItemParams) -> Bool {
        guard item.path == nil else { return transferableRef(for: item, create: false) != nil }
        guard let ref = item.ref, exists(ref) else { return false }
        return item.origin != nil || ref.type is Space.Type || canShare(ref)
    }

    static func dropTypes(for target: ItemParams) -> [UTType] {
        canDrop(on: target) ? UTType.agency : []
    }

    static func handle(_ providers: [NSItemProvider], target: ItemParams) -> Bool {
        guard canDrop(on: target), let owner = target.ref else { return false }
        var accepted = false

        for provider in providers {
            for type in UTType.agency where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                accepted = true
                provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                    guard let data, let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
                    Task { @MainActor in
                        if move(payload.ref, from: payload.origin, to: owner) {
                            try? await Runtime.shared.save()
                        }
                    }
                }
                break
            }
        }

        return accepted
    }

    @discardableResult
    static func paste(_ refs: [Reference], from origin: Reference?, move: Bool, to owner: Reference) -> Reference? {
        var pasted: Reference?
        for ref in refs {
            if move {
                if Self.move(ref, from: origin, to: owner) { pasted = ref }
            } else if canShare(ref), attach(ref, to: owner) {
                pasted = ref
            }
        }
        return pasted
    }

    static func canPaste(_ refs: [Reference], move: Bool, to owner: Reference) -> Bool {
        !refs.contains(owner) && (move || refs.allSatisfy(canShare))
    }

    static func canShare(_ ref: Reference) -> Bool {
        exists(ref) && (ref.type is any Functional.Type || ref.type is Transcript.Type)
    }

    @discardableResult
    static func detach(_ ref: Reference, from origin: Reference?) -> Bool {
        if ref.type is Space.Type {
            let parent = origin ?? Space.with(ref, { $0.space }) ?? nil
            if let parent { return Space.with(parent) { $0.remove(child: ref) } != nil }
            return false
        }

        if ref.type is Route.Type {
            guard let origin else { return false }
            return Space.update(origin) { $0.routes.remove(ref) != nil } ?? false
        }

        guard let origin, let closure = closure(for: origin) else { return false }
        return Closure.update(closure) {
            let sheets = $0.sheets.count
            let components = $0.components.count
            $0.sheets.removeAll { $0 == ref }
            $0.components.removeAll { $0 == ref }
            return sheets != $0.sheets.count || components != $0.components.count
        } ?? false
    }

    static func exists(_ ref: Reference) -> Bool {
        switch ref.type {
        case is Workspace.Type: Workspace.with(ref, { _ in true }) == true
        case is Space.Type: Space.with(ref, { _ in true }) == true
        case is Closure.Type: Closure.with(ref, { _ in true }) == true
        case is Route.Type: Route.with(ref, { _ in true }) == true
        case is Sheet.Type: Sheet.with(ref, { _ in true }) == true
        case is Transcript.Type: Transcript.with(ref, { _ in true }) == true
        case is Artifact.Type: Artifact.with(ref, { _ in true }) == true
        case is Control.Type: Control.with(ref, { _ in true }) == true
        case is Service.Type: Service.with(ref, { _ in true }) == true
        default: false
        }
    }

    private static func canDrop(on target: ItemParams) -> Bool {
        guard target.path == nil, let ref = target.ref else { return false }
        return ref.type is Workspace.Type || ref.type is Space.Type
    }

    private static func transferableRef(for item: ItemParams, create: Bool) -> Reference? {
        guard let ref = item.ref else { return nil }
        guard let path = item.path else { return ref }
        guard ref.type is Artifact.Type else { return nil }
        if Artifact.with(ref, { $0.entry.url }) == path { return ref }
        return create ? Artifact.register(item.name, path) : ref
    }

    private static func move(_ ref: Reference, from origin: Reference?, to owner: Reference) -> Bool {
        guard ref != owner else { return false }
        if ref.type is Space.Type, contains(ref, owner) { return false }
        detach(ref, from: origin)
        return attach(ref, to: owner)
    }

    private static func attach(_ ref: Reference, to owner: Reference) -> Bool {
        switch ref.type {
        case is Space.Type:
            guard let space = Space.with(ref, { $0 }) else { return false }
            space.attach(to: owner)
            return true
        case is Sheet.Type:
            guard let closure = closure(for: owner) else { return false }
            Closure.update(closure) { if !$0.sheets.contains(ref) { $0.sheets.append(ref) } }
            Sheet.update(ref) { $0.owner = closure }
            return true
        case is Transcript.Type:
            return attachComponent(ref, to: owner)
        case is any Functional.Type:
            return attachComponent(ref, to: owner)
        default:
            return false
        }
    }

    private static func attachComponent(_ ref: Reference, to owner: Reference) -> Bool {
        guard let closure = closure(for: owner) else { return false }
        Closure.update(closure) { if !$0.components.contains(ref) { $0.components.append(ref) } }
        return true
    }

    private static func closure(for owner: Reference) -> Reference? {
        Space.with(owner, { $0.closure }) ?? Workspace.with(owner, { $0.closure })
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
        case is Sheet.Type: .sheet
        case is Artifact.Type: .artifact
        case is Control.Type: .control
        case is Service.Type: .service
        default: nil
        }
    }
}

struct ItemContextMenu: View {
    let item: ItemParams
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
