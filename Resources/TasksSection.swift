import SwiftUI
import ScintRuntime
import ScintComponents


//struct TasksSection: Surface {
//    var panel: any Panel
//    var model: any Model
//    var ref: Reference
//    var showsCompleted: Bool
//    var scope: AgendaContent.Scope = .today
//
//    @State private var expanded = true
//
//    var allTasks: [Block] {
//        Document.with(ref) { document in
//            document.blocks.filter { if case .task = $0 { true } else { false } }
//        } ?? []
//    }
//
//    var tasks: [Block] {
//        let today = Calendar.current.startOfDay(for: .now)
//        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? .distantFuture
//        return allTasks.filter { block in
//            guard case .task(_, _, let done, let when) = block else { return false }
//            let due = when.map { $0.next(after: today) ?? $0.date }
//            switch scope {
//                case .today: return !done && when == nil
//                case .upcoming: return !done && due.map { $0 < tomorrow } == true
//                case .later: return showsCompleted || !done
//                case .all: return showsCompleted || !done
//            }
//        }
//    }
//
//    var body: some View {
//        if !tasks.isEmpty {
//            VStack(alignment: .leading, spacing: 8) {
//                HStack(spacing: 8) {
//                    Button { model.open(ref) } label: {
//                        Text(ref.descriptor.name)
//                            .font(.system(size: 16, weight: .semibold))
//                            .foregroundStyle(Style.Foreground.primary)
//                            .lineLimit(1)
//                            .frame(maxWidth: .infinity, alignment: .leading)
//                            .contentShape(Rectangle())
//                    }
//                    .buttonStyle(.plain)
//
//                    Button { withAnimation(.smooth(duration: 0.18)) { expanded.toggle() } } label: {
//                        Image(systemName: "chevron.down")
//                            .font(.system(size: 9, weight: .bold))
//                            .foregroundStyle(Style.Foreground.secondary)
//                            .rotationEffect(.degrees(expanded ? .zero : -90))
//                            .frame(width: 22, height: 22)
//                            .contentShape(Rectangle())
//                    }
//                    .buttonStyle(.plain)
//                    .help(expanded ? "Collapse tasks" : "Expand tasks")
//                }
//
//                if expanded {
//                    VStack(alignment: .leading, spacing: 4) {
//                        ForEach(tasks) { task in
//                            TaskItem(ref: ref, onOpen: { model.open(ref) }, onStart: { model.observe(ref) }, onStop: { model.stop(ref) })
//                        }
//                    }
//                    .transition(.opacity.combined(with: .move(edge: .top)))
//                }
//            }
//        }
//    }
//}
