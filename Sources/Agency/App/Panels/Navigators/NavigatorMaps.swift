import AgencyRuntime
import SwiftUI


struct SheetsNavigator: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        return .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.active == ref || agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref, ref.type is Sheet.Type else { return }
                agency.select(ref)
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }, itemLeadingAccessory: { item, _ in
                guard let ref = item.ref, ref.type is Sheet.Type else { return nil }
                return AnyView(
                    Button {
                        agency.session.close(ref)
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

    static func parameters(_ agency: AgencyModel) -> Params {
        var order: [Reference: Int] = [:]
        for (index, ref) in agency.session.opened.sheets.enumerated() {
            order[ref] = index
        }

        func position(_ item: ItemParams) -> Int {
            guard let ref = item.ref else { return .max }
            return order[ref] ?? .max
        }

        let items = agency.session.opened.sheets.compactMap { ref -> ItemParams? in
            guard ref.type is Sheet.Type else { return nil }
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
            nesting: .flat,
            components: [
                .init(
                    id: "sheets",
                    name: "Sheets",
                    header: false,
                    items: items
                )
            ],
        )
    }
}

struct LibraryNavigator: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref)
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        func sort(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        func items<T: Resolvable>(for type: T.Type, image: String) -> [ItemParams] {
            sort(Runtime.shared.all(as: type).compactMap { (ref, entry) in ItemParams(ref: ref, name: entry.name, image: image) })
        }

        return .init(
            nesting: .recursive,
            header: false,
            components: [
                .init(
                    id: "library",
                    name: "Library",
                    header: true,
                    items: [
                        .init(
                            name: "Apps",
                            image: "square.grid.2x2.fill"
                        ),
                        .init(
                            name: "Commands",
                            image: "switch.2"
                        ),
                        .init(
                            name: "Harnesses",
                            image: "gear"
                        ),
                        .init(
                            name: "Skills",
                            image: "brain.head.profile"
                        )
                    ]
                ),
                .init(
                    id: "resources",
                    name: "Resources",
                    header: true,
                    items: [
                        .init(
                            name: "Bookmarks",
                            image: "bookmark"
                        ),
                        .init(
                            name: "Scripts",
                            image: "scroll"
                        ),
                        .init(
                            name: "Templates",
                            image: "text.alignleft"
                        )
                    ]
                )
            ]
        )
    }
}

struct TranscriptsNavigator: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return agency.session.active == ref
            },
            onSelect: { item in
                guard let ref = item.ref, ref.type is Transcript.Type else { return }
                agency.open(ref)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        let space = agency.session.selected.space ?? agency.session.workspace
        let calendar = Calendar.autoupdatingCurrent
        let items = Runtime.shared.transcripts(for: space)
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
            components: [
                .init(
                    id: "transcripts",
                    name: "Transcripts",
                    header: false,
                    items: items
                )
            ],
        )
    }
}

struct DirectoriesNavigator: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, entry: item.entryId, url: item.path)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        let expanded = agency.app.navigator.state.expanded

        func sortFileItems(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                let lhsDirectory = $0.path.map { agency.files.directory(at: $0) } ?? false
                let rhsDirectory = $1.path.map { agency.files.directory(at: $0) } ?? false
                if lhsDirectory != rhsDirectory { return lhsDirectory && !rhsDirectory }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        func file(for entry: Artifact.Handler, root: Reference, in agency: AgencyModel) -> ItemParams? {
            guard let url = entry.url else { return nil }
            let children: [ItemParams] = (entry.directory && expanded.contains(AnyHashable(url)))
            ? sortFileItems(agency.files.children(for: entry).compactMap { file(for: .file($0), root: root, in: agency) })
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

        func folder(for ref: Reference, in agency: AgencyModel) -> ItemParams? {
            guard let entry = Artifact.with(ref, { $0.handler }), let url = entry.url else { return nil }
            let isDirectory = entry.directory
            let isExpanded = expanded.contains(AnyHashable(url))
            let children: [ItemParams] = (isDirectory && isExpanded)
            ? sortFileItems(agency.files.children(for: entry).compactMap { file(for: .file($0), root: ref, in: agency) })
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
            components: [
                .init(
                    id: "folders",
                    name: "Folders",
                    items: sortFileItems(agency.files.artifacts.compactMap { folder(for: $0, in: agency) })
                )
            ]
        )
    }
}

struct SpacesNavigator: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, entry: item.entryId, url: item.path)
                agency.focus(ref)
            },
            surfaceActions: {
                Action.surfaceItems(for: agency.session.workspace)
            },
            surfaceDropTarget: {
                .init(ref: agency.session.workspace, name: "Workspace")
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        func sorted(_ items: [ItemParams]) -> [ItemParams] {
            items.sorted {
                let lhsBoundary = $0.ref?.type is Space.Type
                let rhsBoundary = $1.ref?.type is Space.Type
                if lhsBoundary != rhsBoundary { return lhsBoundary && !rhsBoundary }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        func space(for ref: Reference, owner: Reference, in agency: AgencyModel) -> ItemParams {
            let spaces = Space.with(ref, { $0.spaces.map { space(for: $0, owner: ref, in: agency) }}) ?? []

            return .init(
                ref: ref,
                origin: owner,
                name: ref.descriptor.name,
                image: "app",
                items: sorted(spaces)
            )
        }

        return .init(
            nesting: .recursive,
            components: [
                .init(
                    id: "spaces",
                    name: "Spaces",
                    items: sorted(Workspace.with(agency.session.workspace, {
                        $0.spaces.map { space(for: $0, owner: agency.session.workspace, in: agency) } }) ?? [])
                )
            ]
        )
    }
}

struct WorkspaceNavigator: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        let sheets = SheetsNavigator.controls(agency)

        return .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if ref.type is Sheet.Type { return sheets.selected?(item) ?? false }
                if let url = item.path { return agency.session.selected.selected(ref, url) }
                return agency.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, entry: item.entryId, url: item.path)
                agency.focus(ref)
            },
            surfaceActions: {
                Action.surfaceItems(for: agency.session.workspace)
            },
            surfaceDropTarget: {
                .init(ref: agency.session.workspace, name: "Workspace")
            },
            itemActions: { item in
                item.path == nil ? Action.itemItems(for: item) : []
            }, itemLeadingAccessory: { item, depth in
                guard let ref = item.ref, ref.type is Sheet.Type else { return nil }
                guard let accessory = sheets.itemLeadingAccessory else { return nil }
                return accessory(item, depth)
            },
            itemAccessory: { item, depth in
                guard let ref = item.ref, ref.type is Sheet.Type else { return nil }
                guard let accessory = sheets.itemAccessory else { return nil }
                return accessory(item, depth)
            }
        )
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        return .init(
            nesting: .recursive,
            components: [
                .init(
                    id: "spaces",
                    name: "Spaces",
                    header: true,
                    items: SpacesNavigator
                        .parameters(agency)
                        .components
                        .flatMap { $0.items }
                )
            ]
        )
    }
}

struct NavigatorMaps: Mapper {
    static func controls(_ agency: AgencyModel) -> Controls {
        switch agency.app.navigator.model {
            case .workspace: WorkspaceNavigator.controls(agency)
            case .transcripts: TranscriptsNavigator.controls(agency)
            case .directories: DirectoriesNavigator.controls(agency)
            case .library: LibraryNavigator.controls(agency)
        }
    }

    static func parameters(_ agency: AgencyModel) -> Params {
        switch agency.app.navigator.model {
            case .workspace: WorkspaceNavigator.parameters(agency)
            case .transcripts: TranscriptsNavigator.parameters(agency)
            case .directories: DirectoriesNavigator.parameters(agency)
            case .library: LibraryNavigator.parameters(agency)
        }
    }
}

