import SwiftUI


enum LibraryDisplayMode {
    case gallery
    case list
}

struct LibrarySidebarItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    var trailingSystemImage: String?
}

struct MockNote: Identifiable {
    let id = UUID()
    let title: String
    let preview: String
    let date: String
    let timestamp: String
    let year: Int
    var tag: String?
    let body: String
}

enum LibraryMockData {
    static let shared = LibrarySidebarItem(name: "Shared", icon: "person.crop.circle")

    static let topFolders: [LibrarySidebarItem] = [
        LibrarySidebarItem(name: "All iCloud", icon: "folder"),
        LibrarySidebarItem(name: "Library", icon: "folder"),
        LibrarySidebarItem(name: "Projects", icon: "folder")
    ]

    static let subjects: [LibrarySidebarItem] = [
        LibrarySidebarItem(name: "Journalism", icon: "folder.badge.person.crop", trailingSystemImage: "person.crop.circle"),
        LibrarySidebarItem(name: "Language", icon: "folder"),
        LibrarySidebarItem(name: "Literature", icon: "folder"),
        LibrarySidebarItem(name: "Philosophy", icon: "folder"),
        LibrarySidebarItem(name: "Psychology", icon: "folder"),
        LibrarySidebarItem(name: "Science", icon: "folder"),
        LibrarySidebarItem(name: "Sociology", icon: "folder"),
        LibrarySidebarItem(name: "Visual Arts", icon: "folder"),
        LibrarySidebarItem(name: "Travel", icon: "folder")
    ]

    static let utilities: [LibrarySidebarItem] = [
        LibrarySidebarItem(name: "Pinned Library", icon: "gearshape"),
        LibrarySidebarItem(name: "Untagged", icon: "gearshape")
    ]

    static let library: [MockNote] = [
        MockNote(
            title: "Philosophy Reading List",
            preview: "A book on dialectics",
            date: "2/21/23",
            timestamp: "February 21, 2023 at 09:12:10",
            year: 2023,
            tag: "#readinglist",
            body: "A book on dialectics\n\nHegel, Plato, and a handful of modern library to revisit."
        ),
        MockNote(
            title: "Philosophy",
            preview: "Ah, where to begin. What exactly do I hope to gain by studying philosophy?",
            date: "1/25/23",
            timestamp: "January 25, 2023 at 18:42:03",
            year: 2023,
            tag: nil,
            body: "Ah, where to begin. What exactly do I hope to gain by studying philosophy? I think that's the wrong question to ask. I think it more pertinent to examine what I stand to lose if I don't.\n\nA quote from Sophie's World explains quite nicely."
        ),
        MockNote(
            title: "Courage",
            preview: "How to live more courageously.",
            date: "1/21/23",
            timestamp: "January 21, 2023 at 16:00:41",
            year: 2023,
            tag: nil,
            body: "How to live more courageously.\n\nWrite plainly. Decide sooner. Let the small discomfort happen."
        ),
        MockNote(
            title: "Life happens where fear and curiosity meet",
            preview: "Interesting I wrote this days or weeks ago and yesterday found myself reading a book about vulnerability.",
            date: "12/28/22",
            timestamp: "December 28, 2022 at 10:04:18",
            year: 2022,
            tag: "#thoughts",
            body: "Interesting I wrote this days or weeks ago and yesterday found myself reading a book about vulnerability.\n\nThe overlap was not subtle."
        ),
        MockNote(
            title: "Thoughts on career",
            preview: "With Crowd Content, I constantly worry about what's coming next.",
            date: "10/30/22",
            timestamp: "October 30, 2022 at 11:55:24",
            year: 2022,
            tag: nil,
            body: "With Crowd Content, I constantly worry about what's coming next. I think to myself, I could do this writing, and I might even enjoy it, but then what?"
        ),
        MockNote(
            title: "Transitions",
            preview: "Caren said to me, you're often either in a transition or preparing for one.",
            date: "10/30/22",
            timestamp: "October 30, 2022 at 14:22:09",
            year: 2022,
            tag: "#thoughts",
            body: "Caren said to me, you're often either in a transition or preparing for one. That feels right."
        ),
        MockNote(
            title: "Why productivity software is trash",
            preview: "It does a great job at making you feel more productive, not so much at actually making you more so.",
            date: "10/30/22",
            timestamp: "October 30, 2022 at 16:41:00",
            year: 2022,
            tag: "#thoughts",
            body: "It does a great job at making you feel more productive, not so much at actually making you more so."
        ),
        MockNote(
            title: "Dialectic thinking",
            preview: "Theses, antitheses, and syntheses.",
            date: "10/25/22",
            timestamp: "October 25, 2022 at 13:39:11",
            year: 2022,
            tag: "#thoughts",
            body: "Theses, antitheses, and syntheses.\n\nHegel's something or other, and it's also the foundation of a lot of analysis."
        ),
        MockNote(
            title: "Friedrich Nietzsche",
            preview: "He who has a why to live for can bear almost any how.",
            date: "9/10/22",
            timestamp: "September 10, 2022 at 09:20:30",
            year: 2022,
            tag: "#quotes",
            body: "He who has a why to live for can bear almost any how."
        ),
        MockNote(
            title: "Myself as a gadfly",
            preview: "A gadfly is a person who interferes with the status quo of a society or community.",
            date: "9/10/22",
            timestamp: "September 10, 2022 at 10:12:13",
            year: 2022,
            tag: "#thoughts",
            body: "A gadfly is a person who interferes with the status quo of a society or community by posing novel, potentially upsetting questions."
        ),
        MockNote(
            title: "On running away",
            preview: "Never really feels like how the movies make it seem.",
            date: "9/10/22",
            timestamp: "September 10, 2022 at 17:33:47",
            year: 2022,
            tag: "#thoughts",
            body: "Never really feels like how the movies make it seem. You spend all this time wanting to get away, trying so hard to get where you want to be."
        ),
        MockNote(
            title: "Nietzsche",
            preview: "How does Nietzsche recommend escaping mediocrity?",
            date: "6/24/22",
            timestamp: "June 24, 2022 at 11:38:55",
            year: 2022,
            tag: nil,
            body: """
            How does Nietzsche recommend escaping mediocrity? Also, what is his advice for social outcasts?

            He says quite a lot about this, though one thing to note is that most people are going to be inescapably mediocre by Nietzsche's standards, and aside from a few great minds who have not found the proper conditions for flourishing most people are unlikely to transition from mediocre to exceptional.

            You might ask whether you would not be happy being mediocre? Nietzsche suggests that many people would:

            "Let us not underestimate the privileges of the mediocre. Life becomes harder and harder as it approaches the heights."

            The Antichrist

            With that said:

            "For believe me! The secret for harvesting from existence the greatest fruitfulness and the greatest enjoyment is to live dangerously."

            The Gay Science

            I remember Kaufman's Nietzsche making a great point about social pressure that pulls you away from your interests.
            """
        )
    ]
}

struct Library: View {
    @State private var selectedFolderID = LibraryMockData.subjects[3].id
    @State private var selectedNoteID = LibraryMockData.library.last?.id
    @State private var displayMode: LibraryDisplayMode = .gallery
    @State private var searchText = ""
    @State private var subjectsExpanded = true

    private var selectedNote: MockNote {
        LibraryMockData.library.first { $0.id == selectedNoteID } ?? LibraryMockData.library[0]
    }

    var body: some View {
        NavigationSplitView {
            librarySidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } content: {
            LibraryCollectionPane(
                library: LibraryMockData.library,
                selectedNoteID: selectedNoteID,
                displayMode: displayMode
            ) { noteID in
                selectedNoteID = noteID
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: displayMode == .gallery ? 760 : 360, max: 900)
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Philosophy")
                            .font(.headline)
                        Text("13 library")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItemGroup {
                    Button {
                        displayMode = displayMode == .gallery ? .list : .gallery
                    } label: {
                        Image(systemName: displayMode == .gallery ? "list.bullet" : "square.grid.2x2")
                    }
                    .help("Toggle note view")

                    Button { } label: {
                        Image(systemName: "ellipsis")
                    }
                    .help("More")

                    Button { } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .help("New Note")
                }
            }
        } detail: {
            NoteDetailPane(note: selectedNote)
                .toolbar(removing: .title)
                .toolbar {
                    ToolbarItemGroup {
                        Button { } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .help("Share")

                        Button { } label: {
                            Image(systemName: "ellipsis")
                        }
                        .help("More")
                    }

                    ToolbarItem {
                        TextField("Search", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                    }
                }
        }
    }

    private var librarySidebar: some View {
        List {
            Section {
                Button {
                    selectedFolderID = LibraryMockData.shared.id
                } label: {
                    SidebarFolderRow(
                        icon: LibraryMockData.shared.icon,
                        label: LibraryMockData.shared.name,
                        selected: selectedFolderID == LibraryMockData.shared.id
                    )
                }
                .buttonStyle(.plain)
            }

            Section("iCloud") {
                ForEach(LibraryMockData.topFolders) { folder in
                    Button {
                        selectedFolderID = folder.id
                    } label: {
                        SidebarFolderRow(
                            icon: folder.icon,
                            label: folder.name,
                            trailingSystemImage: folder.trailingSystemImage,
                            selected: selectedFolderID == folder.id
                        )
                    }
                    .buttonStyle(.plain)
                }

                DisclosureGroup(isExpanded: $subjectsExpanded) {
                    ForEach(LibraryMockData.subjects) { folder in
                        Button {
                            selectedFolderID = folder.id
                        } label: {
                            SidebarFolderRow(
                                icon: folder.icon,
                                label: folder.name,
                                trailingSystemImage: folder.trailingSystemImage,
                                selected: selectedFolderID == folder.id
                            )
                            .padding(.leading, 18)
                        }
                        .buttonStyle(.plain)
                    }
                } label: {
                    Label("Subjects", systemImage: "folder")
                }

                ForEach(LibraryMockData.utilities) { folder in
                    Button {
                        selectedFolderID = folder.id
                    } label: {
                        SidebarFolderRow(
                            icon: folder.icon,
                            label: folder.name,
                            selected: selectedFolderID == folder.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Tags") {
                Text("")
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItemGroup {
                Button { } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .help("New Folder")

                Button { } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
            }
        }
    }
}

struct LibraryCollectionPane: View {
    let library: [MockNote]
    let selectedNoteID: UUID?
    let displayMode: LibraryDisplayMode
    let select: (UUID) -> Void

    var body: some View {
        ScrollView {
            if displayMode == .gallery {
                libraryGallery
            } else {
                libraryList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var years: [Int] {
        Array(Set(library.map(\.year))).sorted(by: >)
    }

    private var libraryGallery: some View {
        LazyVStack(alignment: .leading, spacing: 26) {
            ForEach(years, id: \.self) { year in
                let yearLibrary = library.filter { $0.year == year }

                VStack(alignment: .leading, spacing: 16) {
                    Text(String(year))
                        .font(.title2.weight(.semibold))

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 18)],
                        alignment: .leading,
                        spacing: 24
                    ) {
                        ForEach(yearLibrary) { note in
                            NoteCard(note: note, selected: selectedNoteID == note.id)
                                .onTapGesture {
                                    select(note.id)
                                }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var libraryList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(years, id: \.self) { year in
                Text(String(year))
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 10)

                ForEach(library.filter { $0.year == year }) { note in
                    NoteListRow(note: note, selected: selectedNoteID == note.id)
                        .padding(.horizontal, 24)
                        .onTapGesture {
                            select(note.id)
                        }
                }
            }
        }
        .padding(.bottom, 24)
    }
}

struct SidebarRow: View {
    let icon: String
    let label: String
    var tint: Color = .secondary
    var trailingText: String?
    var trailingSystemImage: String?
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 18)

            Text(label).lineLimit(1)

            Spacer(minLength: 8)

            if let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let trailingText {
                Text(trailingText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(selected ? Color.accentColor.opacity(0.16) : Color.clear)
        .clipShape(.rect(cornerRadius: 7))
    }
}


struct SidebarFolderRow: View {
    let icon: String
    let label: String
    var trailingSystemImage: String?
    var selected: Bool = false

    var body: some View {
        SidebarRow(
            icon: icon,
            label: label,
            tint: .secondary,
            trailingSystemImage: trailingSystemImage,
            selected: selected
        )
    }
}

struct NoteCard: View {
    let note: MockNote
    var selected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(note.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)

                if let tag = note.tag {
                    TagChip(label: tag)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(height: 132, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.18))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: selected ? 2 : 1)
            }
            .clipShape(.rect(cornerRadius: 7))

            Text(note.title)
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Text(note.date)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 210)
    }
}

struct NoteListRow: View {
    let note: MockNote
    var selected: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(note.date)
                        .foregroundStyle(.primary)

                    Text(note.preview)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .font(.callout)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(selected ? Color.accentColor.opacity(0.24) : Color.clear)
        .clipShape(.rect(cornerRadius: 7))
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 12)
        }
    }
}

struct TagChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.blue)
            .lineLimit(1)
    }
}

struct NoteDetailPane: View {
    let note: MockNote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(note.timestamp)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(note.title)
                    .font(.title.weight(.semibold))

                Text(note.body)
                    .font(.title3)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.08))
    }
}
