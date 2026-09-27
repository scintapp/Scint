import SwiftUI


struct TaskDayCell: View {
    var body: some View {
        VStack(spacing: 5) {
            Text("Sat")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("26")
                .font(.title3.weight(.medium))
            Circle()
                .fill(.blue)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
    }
}

struct TaskAgendaHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<5) { _ in TaskDayCell() }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider().padding(.horizontal, 24) }
    }
}

struct TaskAgenda: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader()
            ForEach(0..<2) { _ in TaskListRow() }
        }
        .padding(.horizontal, 24)
    }
}

struct TaskInbox: View {
    var body: some View {
        VStack(spacing: 0) {
            TaskAgendaHeader()
            
            ScrollView {
                VStack(spacing: 18) {
                    ForEach(0..<3) { _ in TaskAgenda() }
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
    }
}

#Preview {
    TaskInbox()
        .preferredColorScheme(.dark)
        .frame(width: 1100, height: 820)
}
