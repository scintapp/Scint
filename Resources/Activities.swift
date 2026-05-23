//import SwiftUI
//
//
//enum ReminderDisplayMode {
//    case list
//    case board
//}
//
//struct ReminderListItem: Identifiable {
//    let id = UUID()
//    let name: String
//    let icon: String
//    let color: Color
//    var count: Int
//    var trailingSystemImage: String?
//}
//
//struct MockReminder: Identifiable {
//    let id = UUID()
//    let title: String
//    var subtitle: String?
//    var checked: Bool = false
//}
//
//struct MockReminderSection: Identifiable {
//    let id = UUID()
//    let title: String
//    let reminders: [MockReminder]
//}
//
//enum RemindersMockData {
//    static let lists: [ReminderListItem] = [
//        ReminderListItem(name: "Agency", icon: "curlybraces", color: .pink, count: 1),
//        ReminderListItem(name: "Research", icon: "graduationcap.fill", color: .purple, count: 0),
//        ReminderListItem(name: "Writing", icon: "doc.fill", color: .orange, count: 0),
//        ReminderListItem(name: "Business", icon: "briefcase.fill", color: .blue, count: 0),
//        ReminderListItem(name: "Groceries", icon: "carrot.fill", color: .brown, count: 0, trailingSystemImage: "person.crop.circle"),
//        ReminderListItem(name: "Recently Deleted", icon: "trash", color: .black, count: 9)
//    ]
//
//    static let sections: [MockReminderSection] = [
//        MockReminderSection(
//            title: "Testing",
//            reminders: [
//                MockReminder(title: "New Reminder", subtitle: "4/18/26, 17:00:00"),
//                MockReminder(title: "New Reminder", subtitle: "4/18/26, 17:00:00"),
//                MockReminder(title: "")
//            ]
//        ),
//        MockReminderSection(
//            title: "More",
//            reminders: [
//                MockReminder(title: "AgencyTools"),
//                MockReminder(title: "")
//            ]
//        ),
//        MockReminderSection(
//            title: "Others",
//            reminders: [
//                MockReminder(title: "New Reminder", checked: true),
//                MockReminder(title: "New Reminder", subtitle: "4/18/26, 17:00:00"),
//                MockReminder(title: "")
//            ]
//        )
//    ]
//}
//
//struct Activities: View {
//    @State private var selectedListID = RemindersMockData.lists.first?.id
//    @State private var displayMode: ReminderDisplayMode = .list
//    @State private var searchText = ""
//    @State private var collapsedSectionIDs: Set<UUID> = []
//
//    private var selectedList: ReminderListItem {
//        RemindersMockData.lists.first { $0.id == selectedListID } ?? RemindersMockData.lists[0]
//    }
//
//    var body: some View {
//        NavigationSplitView {
//            remindersSidebar
//                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
//        } detail: {
//            VStack(alignment: .leading, spacing: 0) {
//                ReminderDetailHeader(list: selectedList)
//                    .padding(.horizontal, 28)
//                    .padding(.top, 24)
//                    .padding(.bottom, 10)
//
//                if displayMode == .list {
//                    remindersListLayout
//                } else {
//                    remindersBoardLayout
//                }
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
//            .background(Color(nsColor: .controlBackgroundColor))
//            .toolbar(removing: .title)
//            .toolbar {
//                ToolbarItemGroup {
//                    Button { } label: {
//                        Image(systemName: "square.and.arrow.up")
//                    }
//                    .help("Share")
//
//                    Button { } label: {
//                        Image(systemName: "text.pad.header.badge.plus")
//                    }
//                    .help("New List with Template")
//
//                    Button { } label: {
//                        Image(systemName: "plus")
//                    }
//                    .help("New Reminder")
//
//                    Button {
//                        displayMode = displayMode == .list ? .board : .list
//                    } label: {
//                        Image(systemName: displayMode == .list ? "rectangle.split.3x1" : "list.bullet")
//                    }
//                    .help("Toggle layout")
//                }
//
//                ToolbarItem {
//                    TextField("Search", text: $searchText)
//                        .textFieldStyle(.roundedBorder)
//                        .frame(width: 220)
//                }
//            }
//        }
//    }
//
//    private var remindersSidebar: some View {
//        List {
//            Section("My Lists") {
//                ForEach(RemindersMockData.lists) { list in
//                    Button {
//                        selectedListID = list.id
//                    } label: {
//                        ListSidebarRow(
//                            icon: list.icon,
//                            label: list.name,
//                            color: list.color,
//                            count: list.count,
//                            trailingSystemImage: list.trailingSystemImage,
//                            selected: selectedListID == list.id
//                        )
//                    }
//                    .buttonStyle(.plain)
//                }
//            }
//        }
//        .listStyle(.sidebar)
//    }
//
//    private var remindersListLayout: some View {
//        ScrollView {
//            LazyVStack(alignment: .leading, spacing: 0) {
//                ForEach(RemindersMockData.sections) { section in
//                    ReminderSectionHeader(
//                        title: section.title,
//                        expanded: !collapsedSectionIDs.contains(section.id)
//                    ) {
//                        if collapsedSectionIDs.contains(section.id) {
//                            collapsedSectionIDs.remove(section.id)
//                        } else {
//                            collapsedSectionIDs.insert(section.id)
//                        }
//                    }
//
//                    if !collapsedSectionIDs.contains(section.id) {
//                        ForEach(section.reminders) { reminder in
//                            ReminderRow(reminder: reminder, tint: selectedList.color)
//                        }
//                    }
//
//                    Divider()
//                        .padding(.vertical, 8)
//                }
//            }
//            .padding(.horizontal, 28)
//            .padding(.bottom, 28)
//        }
//    }
//
//    private var remindersBoardLayout: some View {
//        ScrollView(.horizontal) {
//            HStack(alignment: .top, spacing: 22) {
//                ForEach(RemindersMockData.sections) { section in
//                    VStack(alignment: .leading, spacing: 12) {
//                        HStack {
//                            Text(section.title)
//                                .font(.title2.weight(.semibold))
//
//                            Spacer()
//
//                            Button { } label: {
//                                Image(systemName: "ellipsis")
//                            }
//                            .buttonStyle(.borderless)
//                        }
//
//                        ForEach(section.reminders) { reminder in
//                            ReminderCard(reminder: reminder, tint: selectedList.color)
//                        }
//                    }
//                    .frame(width: 260, alignment: .topLeading)
//                }
//            }
//            .padding(.horizontal, 28)
//            .padding(.bottom, 28)
//        }
//    }
//}
//
//struct ReminderDetailHeader: View {
//    let list: ReminderListItem
//
//    var body: some View {
//        VStack(spacing: 8) {
//            HStack(alignment: .firstTextBaseline) {
//                Text(list.name)
//                    .font(.system(size: 42, weight: .bold))
//                    .foregroundStyle(list.color)
//
//                Spacer()
//
//                Text("\(list.count)")
//                    .font(.system(size: 42, weight: .regular))
//                    .foregroundStyle(list.color)
//            }
//
//            HStack {
//                Text("4 Completed")
//                    .foregroundStyle(.secondary)
//
//                Text("•")
//                    .foregroundStyle(.secondary)
//
//                Button("Clear") { }
//                    .buttonStyle(.plain)
//                    .foregroundStyle(list.color)
//
//                Spacer()
//
//                Button("Hide") { }
//                    .buttonStyle(.plain)
//                    .foregroundStyle(list.color)
//            }
//            .font(.title3.weight(.semibold))
//        }
//    }
//}
//
//struct ListSidebarRow: View {
//    let icon: String
//    let label: String
//    let color: Color
//    let count: Int
//    var trailingSystemImage: String?
//    var selected: Bool = false
//
//    var body: some View {
//        HStack(spacing: 10) {
//            ZStack {
//                Circle()
//                    .fill(color)
//                Image(systemName: icon)
//                    .font(.system(size: 13, weight: .bold))
//                    .foregroundStyle(.white)
//            }
//            .frame(width: 26, height: 26)
//
//            Text(label)
//                .fontWeight(selected ? .semibold : .regular)
//                .lineLimit(1)
//
//            Spacer(minLength: 8)
//
//            if let trailingSystemImage {
//                Image(systemName: trailingSystemImage)
//                    .foregroundStyle(.secondary)
//            }
//
//            Text("\(count)")
//                .foregroundStyle(.secondary)
//                .monospacedDigit()
//        }
//        .padding(.horizontal, 8)
//        .padding(.vertical, 6)
//        .background(selected ? Color.accentColor.opacity(0.16) : Color.clear)
//        .clipShape(.rect(cornerRadius: 7))
//    }
//}
//
//struct ReminderSectionHeader: View {
//    let title: String
//    let expanded: Bool
//    let toggle: () -> Void
//
//    var body: some View {
//        Button(action: toggle) {
//            HStack {
//                Text(title)
//                    .font(.title2.weight(.semibold))
//
//                Spacer()
//
//                Image(systemName: expanded ? "chevron.down" : "chevron.right")
//                    .font(.headline)
//                    .foregroundStyle(.secondary)
//            }
//            .contentShape(.rect)
//        }
//        .buttonStyle(.plain)
//        .padding(.top, 8)
//        .padding(.bottom, 6)
//    }
//}
//
//struct ReminderCheckbox: View {
//    let tint: Color
//    let checked: Bool
//    @State private var isChecked: Bool
//
//    init(tint: Color, checked: Bool = false) {
//        self.tint = tint
//        self.checked = checked
//        _isChecked = State(initialValue: checked)
//    }
//
//    var body: some View {
//        Button {
//            isChecked.toggle()
//        } label: {
//            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
//                .font(.system(size: 19, weight: .regular))
//                .foregroundStyle(isChecked ? tint : tint.opacity(0.85))
//        }
//        .buttonStyle(.plain)
//        .help(isChecked ? "Mark incomplete" : "Mark complete")
//    }
//}
//
//struct ReminderRow: View {
//    let reminder: MockReminder
//    let tint: Color
//    @State private var hovering = false
//
//    var body: some View {
//        HStack(alignment: .top, spacing: 12) {
//            ReminderCheckbox(tint: tint, checked: reminder.checked)
//                .padding(.top, 2)
//
//            VStack(alignment: .leading, spacing: 3) {
//                if reminder.title.isEmpty {
//                    Text(" ")
//                } else {
//                    Text(reminder.title)
//                        .font(.title3.weight(.semibold))
//
//                    if let subtitle = reminder.subtitle {
//                        Text(subtitle)
//                            .font(.callout)
//                            .foregroundStyle(.secondary)
//                    }
//                }
//            }
//
//            Spacer(minLength: 0)
//
//            if hovering || reminder.subtitle != nil {
//                Button { } label: {
//                    Image(systemName: "info.circle")
//                        .foregroundStyle(tint)
//                }
//                .buttonStyle(.borderless)
//            }
//        }
//        .padding(.vertical, 8)
//        .onHover { hovering = $0 }
//    }
//}
//
//struct ReminderCard: View {
//    let reminder: MockReminder
//    let tint: Color
//
//    var body: some View {
//        HStack(alignment: .top, spacing: 8) {
//            ReminderCheckbox(tint: tint, checked: reminder.checked)
//                .padding(.top, 1)
//
//            VStack(alignment: .leading, spacing: 3) {
//                if reminder.title.isEmpty {
//                    Text(" ")
//                } else {
//                    Text(reminder.title)
//                        .font(.headline)
//                        .lineLimit(2)
//
//                    if let subtitle = reminder.subtitle {
//                        Text(subtitle)
//                            .font(.callout)
//                            .foregroundStyle(.secondary)
//                            .lineLimit(1)
//                    }
//                }
//            }
//
//            Spacer(minLength: 0)
//        }
//        .padding(12)
//        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
//        .background(Color(nsColor: .textBackgroundColor).opacity(0.18))
//        .clipShape(.rect(cornerRadius: 8))
//    }
//}
