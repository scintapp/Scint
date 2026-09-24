import SwiftUI
import ScintRuntime
import ScintComponents



struct NewTaskButton: View {
    var model: any Model

    var body: some View {
        IconButton(systemImage: "plus") {
            guard let command = Runtime.shared.all(as: Command.self)
                .map({ $0.0 }).min(by: { $0.descriptor.name < $1.descriptor.name })
                    else { return }

            let sheet = Document.new(model.session.tasks, name: "New Task")
            let material = Document.new(model.session.tasks, name: "Instructions")
            Document.update(material) { $0.delete(at: 0) }
            Document.update(sheet) { document in
                document.delete(at: 0)
                document.insert([.task(UUID(), "New Task", false, nil), .command(command), .document(material)], at: 0)
            }
            model.open(sheet)
        }
        .help("New Task")
    }
}

struct TasksHeader: View {
    var completed: Int
    var showsCompleted: Bool
    var onToggleCompleted: () -> Void
    var onClearCompleted: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4 + 1) {
                Text("\(completed) Completed")
                    .foregroundStyle(Style.Foreground.secondary)

                Button("Clear", action: onClearCompleted)
                    .buttonStyle(.plain)
                    .foregroundStyle(completed > 0 ? Style.Tint.task.bright : Style.Foreground.secondary)
                    .disabled(completed == 0)

                Spacer(minLength: 8)

                Button(showsCompleted ? "Hide" : "Show", action: onToggleCompleted)
                    .buttonStyle(.plain)
                    .foregroundStyle(Style.Tint.task.bright)
            }
            .font(.system(size: 13, weight: .regular))

            Rectangle()
                .fill(Style.Border.hairline)
                .frame(height: 0.5)
        }
    }
}

struct TasksSection: Surface {
    @State private var expanded = true

    var panel: any Panel
    var model: any Model
    var ref: Reference
    var showsCompleted: Bool
    var scope: TasksContent.Scope = .all

    var allTasks: [ScintRuntime.Document.Block] {
        Document.with(ref) { document in
            document.blocks.filter { if case .task = $0 { true } else { false } }
        } ?? []
    }

    var tasks: [ScintRuntime.Document.Block] {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? .distantFuture
        return allTasks.filter { block in
            guard case .task(_, _, let done, let when) = block else { return false }
            let due = when.map { $0.next(after: today) ?? $0.moment }
            switch scope {
                case .inbox: return !done && when == nil
                case .today: return !done && due.map { $0 < tomorrow } == true
                case .all: return showsCompleted || !done
            }
        }
    }

    var body: some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button { model.open(ref) } label: {
                        Text(ref.descriptor.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Style.Foreground.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.smooth(duration: 0.18)) { expanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Style.Foreground.secondary)
                            .rotationEffect(.degrees(expanded ? .zero : -90))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(expanded ? "Collapse tasks" : "Expand tasks")
                }

                if expanded {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(tasks) { task in
                            TaskItem(panel: panel, model: model, ref: ref, task: task)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

struct TasksContent: Surface {
    var panel: any Panel
    var model: any Model

    @State private var showsCompleted = true
    @State private var confirmsClear = false
    @State private var scope: Scope = .all

    enum Scope: String, CaseIterable {
        case inbox, today, all

        var label: String {
            switch self {
                case .inbox: "Inbox"
                case .today: "Today"
                case .all: "All Tasks"
            }
        }
    }

    var sheets: [Reference] { Documents.documents(under: [model.session.tasks]).filter { Self.sheet($0) != nil } }

    var visible: [Reference] {
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? .distantFuture
        return sheets.filter { ref in
            guard let task = Self.sheet(ref) else { return false }
            let due = task.when.map { $0.next(after: today) ?? $0.moment }
            switch scope {
                case .inbox: return !task.done && task.when == nil
                case .today: return !task.done && due.map { $0 < tomorrow } == true
                case .all: return showsCompleted || !task.done
            }
        }
    }

    var completed: Int { sheets.filter { Self.sheet($0)?.done == true }.count }

    var hide: Void {
        for sheet in sheets {
            guard let task = Self.sheet(sheet), task.done else { continue }
            Space.with(model.session.tasks, { $0 })?.remove(sheet)
            Space.with(model.session.tasks, { $0 })?.remove(task.material)
        }
    }

    static func sheet(_ ref: Reference) -> (id: UUID, text: String, done: Bool, when: When?, command: Reference, material: Reference)? {
        guard let blocks = Document.with(ref, { $0.blocks }), blocks.count == 3,
              case .task(let id, let text, let done, let when) = blocks[0],
              case .command(let command) = blocks[1],
              case .document(let material) = blocks[2]
                else { return nil }
        return (id, text, done, when, command, material)
    }

    static func update(_ ref: Reference, task: AnyHashable, _ transform: (UUID, String, Bool, When?) -> ScintRuntime.Document.Block) {
        let changed = Document.update(ref) { document -> Bool in
            guard let index = document.blocks.firstIndex(where: { $0.id == task }),
                  case .task(let id, let text, let done, let when) = document.blocks[index]
                    else { return false }
            let block = transform(id, text, done, when)
            document.update(block, at: index)
            guard case .task(_, _, let finished, let moment) = block else { return true }
            return finished != done || moment != when
        } ?? false
        if changed { schedule(ref) }
    }

    static func schedule(_ ref: Reference) {
        guard let task = sheet(ref) else { return }
        guard !task.done, let when = task.when, when.next(after: .now) != nil, let url = CallbackRouter.callback("run", for: ref)
        else { return Automation.stop(ref) }
        Automation.start(ref, line: "/usr/bin/open '\(url.absoluteString)'", when: when)
    }

    @discardableResult
    static func run(_ ref: Reference) -> Bool {
        guard let task = sheet(ref), let space = Document.with(ref, { $0.origin }) else { return false }
        var values = Dictionary(uniqueKeysWithValues: (Space.with(space, { $0.config }) ?? [:]).map { ($0.key, $0.value) })
        if let link = Reference.Link.url(for: ref) { values["input"] = .string(link.absoluteString) }

        let log = UUID()
        let header = "**\(task.command.descriptor.name)** · \(Date.now.formatted(date: .abbreviated, time: .shortened))"
        Document.update(task.material) { $0.insert(.text(log, header + "\n\n```"), at: nil) }

        return Command.run(task.command, with: values) { line, exit in
            Task { @MainActor in
                Document.update(task.material) { document in
                    guard let index = document.blocks.firstIndex(where: { $0.id == AnyHashable(log) }),
                          case .text(_, let text) = document.blocks[index]
                            else { return }
                    let result = exit.map { text + "\n```\n\n" + ($0 == 0 ? "Completed." : "Failed with exit code \($0).") } ?? text + "\n" + line
                    document.update(.text(log, result), at: index)
                }
                if exit == 0, (task.when?.repeats ?? .never) == .never { update(ref, task: task.id) { .task($0, $1, true, $3) } }
            }
        }
    }

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Style.Spacing.entry) {
//                    TasksHeader(
//                        completed: completed,
//                        showsCompleted: showsCompleted,
//                        onToggleCompleted: { showsCompleted.toggle() },
//                        onClearCompleted: { confirmsClear = true }
//                    )

                    LazyVStack(alignment: .leading, spacing: Style.Spacing.entry) {
                        ForEach(visible) { ref in
                            if let task = Document.with(ref, { $0.blocks.first }) ?? nil {
                                TaskItem(panel: panel, model: model, ref: ref, task: task)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, Style.Spacing.page)
                    .padding(.top, 2)
                    .padding(.bottom, Style.Spacing.page)
                }

                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .confirmationDialog("Clear completed tasks?", isPresented: $confirmsClear, titleVisibility: .visible) {
                    Button("Clear \(completed) Completed \(completed == 1 ? "Task" : "Tasks")", role: .destructive) {
                        hide
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This removes completed tasks from Tasks.")
                }
            }
        }
        .background(Style.Background.canvas)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .safeAreaBar(edge: .top) {
            HStack(alignment: .center, spacing: 16) {
                NewTaskButton(model: model)

                PageHeader("Tasks") {
                    SegmentedTabs(
                        selection: $scope,
                        options: Scope.allCases,
                        title: \.label
                    )
                }
                
                IconButton(systemImage: "ellipsis") { }
            }
            .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}
