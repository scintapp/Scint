import SwiftUI


struct FoldersList: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let expanded = (model as? StudioModel)?.navigator.state.expanded ?? []

        func sortFileItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                let lhsDirectory = $0.isParent
                let rhsDirectory = $1.isParent
                if lhsDirectory != rhsDirectory { return lhsDirectory && !rhsDirectory }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        func file(for entry: Artifact.Handler, root: Reference, in model: some Model) -> ItemParams? {
            guard let url = entry.url else { return nil }
            let children: [ItemParams] = entry.directory && expanded.contains(AnyHashable(url))
            ? sortFileItems(entry.children.compactMap { file(for: $0, root: root, in: model) })
            : []

            return .init(
                ref: root,
                path: url,
                name: entry.name,
                image: entry.directory ? "folder" : "doc",
                items: children,
                isParent: entry.directory
            )
        }

        func folder(for ref: Reference, in model: some Model) -> ItemParams? {
            guard let entry = Artifact.with(ref, { $0.handler }), let url = entry.url else { return nil }
            let isDirectory = entry.directory
            let isExpanded = expanded.contains(AnyHashable(url))
            let children: [ItemParams] = isDirectory && isExpanded
            ? sortFileItems(entry.children.compactMap { file(for: $0, root: ref, in: model) })
            : []

            return .init(
                ref: ref,
                path: url,
                name: Runtime.shared.get(ref).name,
                image: isDirectory ? "folder" : "doc",
                items: children,
                isParent: isDirectory
            )
        }

        return .init(
            nesting: .recursive,
            sections: [
                .init(
                    id: "folders",
                    name: "Folders",
                    items: sortFileItems(model.artifacts(model.session.origin).compactMap { folder(for: $0, in: model) })
                )
            ]
        )
    }
}

struct ArtifactsList: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref)
            },
            itemPalette: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
            sections: [
                .init(
                    items: [
                        .init(
                            name: "Apps",
                            image: "square.grid.3x3.square"
                        ),
                        .init(
                            name: "Bookmarks",
                            image: "bookmark"
                        ),
                        .init(
                            name: "Skills",
                            image: "brain.head.profile"
                        ),
                    ]
                )
            ]
        )
    }
}

struct HarnessesList: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init()
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
            id: "harnesses",
            name: "Harnesses",
            nesting: .recursive,
            header: true,
            sections: []
        )
    }
}

struct CommandsList: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init()
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
            id: "commands",
            name: "Commands",
            nesting: .recursive,
            header: true,
            sections: []
        )
    }
}

struct MaterialsList: Mapper {
    static func controls(_ model: any Model) -> Controls {
        return .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return model.session.material == ref || model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref, ref.type is Material.Type else { return }
                model.select(ref)
            },
            itemPalette: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }, itemLeadingAccessory: { item, _ in
                guard let ref = item.ref, ref.type is Material.Type else { return nil }
                return AnyView(
                    Button {
                        model.session.close(ref)
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 18, height: 18, alignment: .center)
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.secondary.opacity(0.8))
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.tertiary.opacity(0.3))
                            )
                    }
                        .buttonStyle(.plain)
                        .help("Close")
                )
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let order: [Reference: Int] = [:]

        func position(_ item: ItemParams) -> Int {
            guard let ref = item.ref else { return .max }
            return order[ref] ?? .max
        }

        let items = Runtime.shared.all(as: Material.self)
            .map { $0.0 }
            .filter { $0.descriptor.name != "Input" }
            .compactMap { ref -> ItemParams? in
                guard ref.type is Material.Type else { return nil }
                return .init(
                    ref: ref,
                    name: ref.descriptor.name,
                    image: Iconography.icon(for: ref).symbol
                )
            }.sorted {
                let lhs = position($0)
                let rhs = position($1)
                if lhs != rhs { return lhs < rhs }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        return .init(
            layout: .table,
            nesting: .flat,
            sections: [
                .init(
                    id: "materials",
                    name: "Materials",
                    header: false,
                    items: items
                )
            ],
        )
    }
}

struct SpacesList: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
                model.focus(ref)
            },
            surfacePalette: {
                Action.surfaceItems(for: model.session.workspace)
            },
            surfaceDropTarget: {
                .init(ref: model.session.workspace, name: "Workspace")
            },
            itemPalette: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let workspace = model.session.workspace

        func sorted(_ items: [ItemParams]) -> [ItemParams] {
            items
                .sorted {
                    let lhsBoundary = $0.ref?.type is Space.Type
                    let rhsBoundary = $1.ref?.type is Space.Type
                    if lhsBoundary != rhsBoundary { return lhsBoundary && !rhsBoundary }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
        }

        func space(for ref: Reference, owner: Reference) -> ItemParams {
            .init(
                ref: ref,
                origin: owner,
                name: ref.descriptor.name,
                image: "app",
                items: sorted(Space.with(ref, { $0.spaces.map { space(for: $0, owner: ref) }}) ?? [])
            )
        }

        let spaces = Workspace.with(workspace, { $0.spaces.map { space(for: $0, owner: workspace) } }) ?? []

        return .init(
            id: "spaces",
            nesting: .recursive,
            header: false,
            sections: [
                .init(
                    id: "spaces",
                    name: "Spaces",
                    items: sorted(spaces)
                )
            ]
        )
    }
}

struct TranscriptsList: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return model.session.transcript == ref
            },
            onSelect: { item in
                guard let ref = item.ref, ref.type is Transcript.Type else { return }
                model.select(ref)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let calendar = Calendar.autoupdatingCurrent
        let items = Runtime.shared.all(as: Transcript.self)
            .compactMap { ref, transcript -> Reference? in
                transcript.origin.type is Transcript.Type ? nil : ref
            }
            .map { ref -> (ref: Reference, date: Date) in
                let date = Transcript.with(ref, { $0.entries.last?.created ?? ref.descriptor.created })!
                return (ref, date)
            }
            .sorted { $0.date > $1.date }
            .map { ref, date in
                let day: String
                if calendar.isDateInToday(date) { day = "Today" }
                else if calendar.isDateInYesterday(date) { day = "Yesterday" }
                else { day = date.formatted(.dateTime.month(.abbreviated).day()) }

                return ItemParams(
                    ref: ref,
                    name: ref.descriptor.name,
                    description: "\(day), \(date.formatted(date: .omitted, time: .shortened))"
                )
            }

        return .init(
            layout: .table,
            nesting: .single,
            header: false,
            sections: [
                .init(
                    id: "transcripts",
                    name: "Transcripts",
                    header: false,
                    items: items
                )
            ]
        )
    }
}
