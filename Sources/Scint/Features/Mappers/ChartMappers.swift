import SwiftUI


private func childSpaces(of ref: Reference) -> [Reference] {
    let children: Set<Reference>
    if ref.type is Workspace.Type { children = Workspace.with(ref, { $0.spaces }) ?? [] }
    else if ref.type is Space.Type { children = Space.with(ref, { $0.spaces }) ?? [] }
    else { children = [] }

    return children.sorted {
        let comparison = $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name)
        if comparison == .orderedSame { return $0.id.uuidString < $1.id.uuidString }
        return comparison == .orderedAscending
    }
}

private func structures(in workspace: Reference) -> [Reference] {
    var visited: Set<Reference> = []
    var result: [Reference] = []

    func visit(_ ref: Reference) {
        guard visited.insert(ref).inserted else { return }
        result.append(ref)
        for child in childSpaces(of: ref) { visit(child) }
    }

    visit(workspace)
    return result
}

private func structurePath(_ ref: Reference) -> String {
    var visited: Set<Reference> = []
    var cursor: Reference? = ref
    var names: [String] = []

    while let current = cursor, visited.insert(current).inserted {
        names.append(current.descriptor.name)
        cursor = Space.with(current, { $0.space }).flatMap { $0 }
    }

    return names.reversed().joined(separator: " / ")
}

private func structureMaterials(_ ref: Reference) -> [Reference] {
    var materials: [Reference] = []
    let input: Reference?

    if ref.type is Workspace.Type {
        materials = Workspace.with(ref, { $0.materials }) ?? []
        input = Workspace.with(ref, { $0.input }).flatMap { $0 }
    } else if ref.type is Space.Type {
        materials = Space.with(ref, { $0.materials }) ?? []
        input = Space.with(ref, { $0.input }).flatMap { $0 }
    } else {
        input = nil
    }

    if let input { materials.append(input) }
    var seen: Set<Reference> = []
    return materials.filter { seen.insert($0).inserted }
}

private func structureHarness(_ ref: Reference) -> Reference? {
    let harness: Reference?
    if ref.type is Workspace.Type { harness = Workspace.with(ref, { $0.harness }) }
    else if ref.type is Space.Type { harness = Space.with(ref, { $0.harness }).flatMap { $0 } }
    else { harness = nil }

    guard let harness, harness.type is Harness.Type else { return nil }
    return harness
}

struct WorkspaceHierarchyMapper: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
                model.focus(ref)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        func item(for ref: Reference, ancestors: Set<Reference>) -> ItemParams {
            var next = ancestors
            next.insert(ref)
            let children = childSpaces(of: ref)
                .filter { !next.contains($0) }
                .map { item(for: $0, ancestors: next) }
            let harness = structureHarness(ref)
            let description = ref.descriptor.description

            return .init(
                ref: ref,
                name: ref.descriptor.name,
                count: structureMaterials(ref).filter { !$0.descriptor.tags.contains("input") }.count,
                value: harness?.descriptor.name,
                description: description,
                items: children,
                isParent: true
            )
        }

        let workspace = model.session.workspace
        return .init(
            id: "workspace-hierarchy",
            ref: workspace,
            name: workspace.descriptor.name,
            sections: [
                .init(
                    id: "workspace",
                    name: "Workspace",
                    header: false,
                    items: [item(for: workspace, ancestors: [])]
                )
            ]
        )
    }
}


