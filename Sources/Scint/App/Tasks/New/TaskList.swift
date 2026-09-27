import SwiftUI



struct TaskListRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("9:00 AM")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Toggle("Complete task", isOn: .constant(false))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .fixedSize()
            TaskTitleStack()
            IconLabel()
                .frame(width: 110, alignment: .leading)
            Text("45m")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) { Divider() }
    }
}

struct TaskSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader()
            ForEach(0..<3) { _ in TaskListRow() }
        }
        .padding(.horizontal, 24)
    }
}

struct TaskList: View {
    var body: some View {
        VStack(spacing: 0) {
            TaskQuickAdd()

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<3) { _ in TaskSection() }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
    }
}

#Preview {
    TaskList()
        .preferredColorScheme(.dark)
        .frame(width: 1440, height: 900)
}
