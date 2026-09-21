import SwiftUI
import ScintRuntime
import ScintComponents


struct FoldersList: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selection.selected(ref, url) }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let expanded: Set<AnyHashable> = []

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

        func artifacts(_ space: Reference) -> [Reference] {
            Space.with(space) { space in
                space.artifacts.filter { ref in
                    Artifact.with(ref) {
                        switch $0.handler {
                            case .directory, .file: true
                            default: false
                        }
                    } == true
                }
            } ?? []
        }

        return .init(
            sections: [
                .init(
                    id: "folders",
                    name: "Folders",
                    items: sortFileItems(
                        artifacts(model.session.library)
                            .compactMap { folder(for: $0, in: model) })
                )
            ]
        )
    }
}

struct ArtifactsList: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selection.selected(ref, url) }
                return model.session.selection.selected(ref)
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

struct HarnessesList: Query {
    static func controls(_ model: any Model) -> Controls {
        .init()
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
            id: "harnesses",
            name: "Harnesses",
            header: true,
            sections: []
        )
    }
}

struct CommandsList: Query {
    static func controls(_ model: any Model) -> Controls {
        .init()
    }

    static func parameters(_ model: any Model) -> Params {
        .init(
            id: "commands",
            name: "Commands",
            header: true,
            sections: []
        )
    }
}

struct DocumentsList: Query {
    static func controls(_ model: any Model) -> Controls {
        return .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return model.session.document == ref || model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref, ref.type is ScintRuntime.Document.Type else { return }
                model.select(ref)
            },
            itemPalette: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }, itemLeadingAccessory: { item, _ in
                guard let ref = item.ref, ref.type is ScintRuntime.Document.Type else { return nil }
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

        let items = Runtime.shared.all(as: Document.self)
            .map { $0.0 }
            .filter { $0.descriptor.name != "Input" }
            .compactMap { ref -> ItemParams? in
                guard ref.type is ScintRuntime.Document.Type else { return nil }
                return .init(
                    ref: ref,
                    name: ref.descriptor.name
                )
            }.sorted {
                let lhs = position($0)
                let rhs = position($1)
                if lhs != rhs { return lhs < rhs }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        return .init(
            layout: .table,
            sections: [
                .init(
                    id: "documents",
                    name: "Documents",
                    header: false,
                    items: items
                )
            ],
        )
    }
}

struct MapList: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return model.session.focus == .structure(ref)
            },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selection.selected(ref, url) }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
                model.focus(ref)
            },
            surfaceDropTarget: {
                .init(name: "Spaces")
            },
            wrapLink: { view, item, _ in
                guard let ref = item.ref else { return view }
                return AnyView(view.contextMenu { ContextActionMenu(ref: ref) })
            },
            dropTypes: { item in
                item.ref == nil ? [.space] : ReferenceTransfer.dropTypes(for: item)
            },
            onDrop: { providers, target in
                target.ref == nil ? ReferenceTransfer.detach(providers) : ReferenceTransfer.handle(providers, target: target)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        func sorted(_ items: [ItemParams]) -> [ItemParams] {
            items
                .sorted {
                    let lhsBoundary = $0.ref?.type is Space.Type
                    let rhsBoundary = $1.ref?.type is Space.Type
                    if lhsBoundary != rhsBoundary { return lhsBoundary && !rhsBoundary }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
        }

        func space(for ref: Reference, origin: Reference) -> ItemParams {
            .init(
                ref: ref,
                origin: origin,
                name: ref.descriptor.name,
                image: "app",
                items: sorted(Space.with(ref, { $0.spaces.map { space(for: $0, origin: ref) }}) ?? [])
            )
        }

        return .init(
            id: "spaces",
            header: false,
            sections: [
                .init(
                    id: "spaces",
                    name: "Spaces",
                    items: sorted(model.session.spaces.map { space(for: $0, origin: $0) })
                )
            ]
        )
    }
}

struct TranscriptsList: Query {
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


struct NestedLibraryList: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return model.session.focus == .structure(ref)
            },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selection.selected(ref, url) }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
                model.focus(ref)
            },
            surfaceDropTarget: {
                .init(name: "Spaces")
            },
            wrapLink: { view, item, _ in
                guard let ref = item.ref else { return view }
                return AnyView(view.contextMenu { ContextActionMenu(ref: ref) })
            },
            dropTypes: { item in
                item.ref == nil ? [.space] : ReferenceTransfer.dropTypes(for: item)
            },
            onDrop: { providers, target in
                target.ref == nil ? ReferenceTransfer.detach(providers) : ReferenceTransfer.handle(providers, target: target)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let library = model.session.library
        let libraryItems = Space.with(library, { $0 })?.spaces ?? []

        func sorted(_ items: [ItemParams]) -> [ItemParams] {
            items
                .sorted {
                    let lhsBoundary = $0.ref?.type is Space.Type
                    let rhsBoundary = $1.ref?.type is Space.Type
                    if lhsBoundary != rhsBoundary { return lhsBoundary && !rhsBoundary }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
        }

        func space(for ref: Reference, origin: Reference) -> ItemParams {
            .init(
                ref: ref,
                origin: origin,
                name: ref.descriptor.name,
                image: "folder",
                items: sorted(Space.with(ref, { $0.spaces.map { space(for: $0, origin: ref) }}) ?? [])
            )
        }

        return .init(
            id: "library",
            header: false,
            sections: [
                .init(
                    id: "library",
                    name: "Library",
                    image: "folder",
                    tint: Style.Foreground.secondary,
                    items: libraryItems.compactMap { space(for: $0, origin: $0) }
                )
            ]
        )
    }
}

struct FlatSpacesList: Query {
    static func controls(_ model: any Model) -> Controls {
        .init(
            focused: { item in
                guard let ref = item.ref else { return false }
                return model.session.focus == .structure(ref)
            },
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selection.selected(ref, url) }
                return model.session.selection.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
                model.focus(ref)
            },
            surfaceDropTarget: {
                .init(name: "Spaces")
            },
            wrapLink: { view, item, _ in
                guard let ref = item.ref else { return view }
                return AnyView(view.contextMenu { ContextActionMenu(ref: ref) })
            },
            dropTypes: { item in
                item.ref == nil ? [.space] : ReferenceTransfer.dropTypes(for: item)
            },
            onDrop: { providers, target in
                target.ref == nil ? ReferenceTransfer.detach(providers) : ReferenceTransfer.handle(providers, target: target)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        func sorted(_ refs: [Reference]) -> [Reference] {
            refs.sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
        }

        func children(of ref: Reference) -> [Reference] {
            sorted(Space.with(ref, { Array($0.spaces) }) ?? [])
        }

        func descendants(of ref: Reference) -> [Reference] {
            children(of: ref).flatMap { [$0] + descendants(of: $0) }
        }

        func item(_ ref: Reference, origin: Reference) -> ItemParams {
            let dot = Iconography.dot(for: ref)
            return .init(ref: ref, origin: origin, name: ref.descriptor.name, image: dot.symbol, tint: dot.tint.bright)
        }

        func working(_ refs: [Reference]) -> Int {
            refs.count { ref in
                switch ref.context?.state {
                    case .active, .working: true
                    default: false
                }
            }
        }

        func root(_ ref: Reference) -> ItemParams {
            let below = descendants(of: ref)
            let active = working(below)

            return .init(
                ref: ref,
                origin: ref,
                name: ref.descriptor.name,
                image: "app",
                count: active > 0 ? active : nil,
                items: below.map { item($0, origin: ref) }
            )
        }

        return .init(
            id: "spaces",
            header: false,
            sections: [
                .init(
                    id: "spaces",
                    name: "Spaces",
                    items: sorted(model.session.spaces).map(root)
                )
            ]
        )
    }
}
