import UniformTypeIdentifiers
import SwiftUI
import AgencyRuntime
import Foundation


extension UTType {
    nonisolated static let artifact = UTType(exportedAs: "com.kaechle.Agency.artifact")
    nonisolated static let boundary = UTType(exportedAs: "com.kaechle.Agency.boundary")
}

enum TransferModel {
    static func boundary(for ref: Reference?, source: Reference) -> BoundaryTransfer? {
        guard let ref else { return nil }
        guard ref.type is Boundary.Type else { return nil }
        return BoundaryTransfer(ref: ref, source: source)
    }

    static func provider(for ref: Reference?, source: Reference) -> NSItemProvider? {
        guard let transfer = boundary(for: ref, source: source),
              let data = try? JSONEncoder().encode(transfer) else { return nil }

        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.boundary.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    static func drop(_ providers: [NSItemProvider], to target: Reference, perform: @escaping @MainActor (Bool) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.boundary.identifier) }) else {
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.boundary.identifier) { data, _ in
            guard let data,
                  let transfer = try? JSONDecoder().decode(BoundaryTransfer.self, from: data) else {
                Task { await perform(false) }
                return
            }

            Task {
                let moved = move(transfer, to: target)
                await perform(moved)
            }
        }

        return true
    }

    static func move(_ transfer: BoundaryTransfer, to target: Reference) -> Bool {
        guard transfer.ref != target else {
            return false
        }
        guard transfer.ref.type is Boundary.Type, target.type is Boundary.Type else {
            return false
        }
        guard Boundary.with(transfer.ref, { $0 }) != nil, Boundary.with(target, { $0 }) != nil else {
            return false
        }
        guard !contains(target, descendant: transfer.ref) else {
            return false
        }
        guard Boundary.with(transfer.ref, { $0.boundary }) != target else {
            return false
        }

        if let currentParent = Boundary.with(transfer.ref, { $0.boundary }) ?? nil,
           currentParent.type is Boundary.Type {
            Boundary.update(currentParent) { current in
                current.boundaries.remove(transfer.ref)
            }
        }

        Boundary.update(target) { boundary in
            boundary.boundaries.insert(transfer.ref)
        }

        Boundary.update(transfer.ref) { boundary in
            boundary.boundary = target
        }

        return true
    }

    private static func contains(_ target: Reference, descendant: Reference) -> Bool {
        var cursor: Reference? = target

        while let current = cursor {
            if current == descendant { return true }
            cursor = Boundary.with(current, { $0.boundary }) ?? nil
        }

        return false
    }
}

struct BoundaryTransfer: Codable, Transferable {
    let ref: Reference
    let source: Reference

    nonisolated static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .boundary)
    }
}

enum TransferProvider {
    static func provider(for request: InteractionRequest, source: Reference) -> NSItemProvider? {
        guard let ref = request.domain.reference else { return nil }
        return TransferModel.provider(for: ref, source: source)
    }

    static func dropTypes(for request: InteractionRequest) -> [UTType] {
        switch request.domain {
        case .boundary:
            [.boundary]
        default:
            []
        }
    }

    static func drop(_ providers: [NSItemProvider], on request: InteractionRequest) -> Bool {
        guard case .boundary(let target) = request.domain else { return false }
        return TransferModel.drop(providers, to: target, perform: { _ in })
    }

    @MainActor static func decorate(_ view: AnyView, request: InteractionRequest?, agency: AgencyModel) -> AnyView {
        guard let request else { return view }

        let withDrag: AnyView
        if let provider = provider(for: request, source: agency.session.space) {
            withDrag = AnyView(view.onDrag { provider })
        } else {
            withDrag = view
        }

        let types = dropTypes(for: request)
        guard !types.isEmpty else { return withDrag }

        return AnyView(
            withDrag.onDrop(of: types, isTargeted: nil) { providers in
                drop(providers, on: request)
            }
        )
    }
}

enum Domain: Hashable {
    case name(Key)
    case description(Key)
    case tags(Key)
    case context(Key)
    case boundary(Reference)
    case closure(Reference)
    case route(Reference)
    case space(Reference)
    case intent(Reference)
    case artifact(Reference)
    case control(Reference)
    case service(Reference)
    case journal(Reference)
    case sheet(Reference)
    case task(Reference, UUID)
    case content(Reference, UUID)

    var reference: Reference? {
        switch self {
        case .boundary(let ref),
             .closure(let ref),
             .route(let ref),
             .space(let ref),
             .intent(let ref),
             .artifact(let ref),
             .control(let ref),
             .service(let ref),
             .journal(let ref),
             .sheet(let ref),
             .task(let ref, _),
             .content(let ref, _):
            ref
        case .name, .description, .tags, .context:
            nil
        }
    }

    static func from(_ ref: Reference) -> Domain {
        switch ref.type {
        case is Space.Type: .space(ref)
        case is Boundary.Type: .boundary(ref)
        case is Closure.Type: .closure(ref)
        case is Route.Type: .route(ref)
        case is Artifact.Type: .artifact(ref)
        case is Control.Type: .control(ref)
        case is Service.Type: .service(ref)
        case is Journal.Type: .journal(ref)
        case is Sheet.Type: .sheet(ref)
        default: .context(.context(ref.contextId))
        }
    }
}

enum MenuContext {
    enum Interface {
        enum Inspector {
            case composition
            case preview
            case thread
        }

        enum Content {
            case boundary
            case pathfinder
            case statusbar

            enum Console {
                case activity
                case statusbar
            }

            enum Editor {
                case canvas
                case component
            }
        }

        enum Navigator {
            case library
            case notifications
            case threads
            case space
        }

        enum Toolbar {
            case badge
            case breadcrumb
        }
    }
}

enum MenuSurface {
    case sheet
    case boundary
    case editor
    case content
    case console
    case inspector
    case navigator
    case panel
}

struct InteractionRequest {
    let surface: MenuSurface
    let domain: Domain
}

@MainActor enum AppCommands {
    static func open(_ ref: Reference, in agency: AgencyModel) {
//        agency.open(ref)
    }

    static func newBoundary(in parent: Reference, agency: AgencyModel) {
        let ref = Boundary.new("New Boundary", in: parent)
        agency.select(ref)
    }
}

@MainActor enum MenuProvider {
    static func actions(for request: InteractionRequest, in agency: AgencyModel) -> [ContextMenuAction] {
        switch request.domain {
        case .space(let ref):
            spaceActions(ref, surface: request.surface)
        case .boundary(let ref):
            boundaryActions(ref, surface: request.surface)
        case .sheet(let ref):
            sheetActions(ref, surface: request.surface)
        case .artifact(let ref),
             .control(let ref),
             .service(let ref),
             .journal(let ref),
             .closure(let ref),
             .route(let ref),
             .intent(let ref):
            referenceActions(ref)
        case .task(let ref, _),
             .content(let ref, _):
            referenceActions(ref)
        case .name, .description, .tags, .context:
            []
        }
    }

    @ViewBuilder
    static func menu(for request: InteractionRequest, in agency: AgencyModel) -> some View {
        ForEach(actions(for: request, in: agency)) { action in
            Button(role: action.role) {
                action.perform(agency)
            } label: {
                if let systemImage = action.systemImage {
                    Label(action.title, systemImage: systemImage)
                } else {
                    Text(action.title)
                }
            }
        }
    }

    private static func spaceActions(_ ref: Reference, surface: MenuSurface) -> [ContextMenuAction] {
        referenceActions(ref) + [
            .init(id: "new-boundary", title: "New Boundary", systemImage: "rectangle.stack.badge.plus") { agency in
                AppCommands.newBoundary(in: ref, agency: agency)
            }
        ]
    }

    private static func boundaryActions(_ ref: Reference, surface: MenuSurface) -> [ContextMenuAction] {
        referenceActions(ref) + [
            .init(id: "new-child-boundary", title: "New Child Boundary", systemImage: "rectangle.stack.badge.plus") { agency in
                AppCommands.newBoundary(in: ref, agency: agency)
            }
        ]
    }

    private static func sheetActions(_ ref: Reference, surface: MenuSurface) -> [ContextMenuAction] {
        [
            .init(id: "open-sheet", title: "Open Sheet", systemImage: "list.bullet.rectangle") { agency in
                AppCommands.open(ref, in: agency)
            }
        ] + referenceActions(ref)
    }

    private static func referenceActions(_ ref: Reference) -> [ContextMenuAction] {
        [
            .init(id: "select", title: "Select", systemImage: "cursorarrow") { agency in

            }
        ]
    }
}


struct ContextMenuAction: Identifiable {
    let id: String
    let role: ButtonRole?
    let title: String
    let systemImage: String?
    let perform: @MainActor (AgencyModel) -> Void

    init(id: String,title: String,systemImage: String? = nil,role: ButtonRole? = nil,perform: @escaping @MainActor (AgencyModel) -> Void) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.perform = perform
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
