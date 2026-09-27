import SwiftUI
import ScintComponents


struct TaskTitleStack: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Review command runner states")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
            Text("Check for failed runs and summarize flaky tests.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StackedTaskRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("Complete task", isOn: .constant(false))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .fixedSize()
            VStack(alignment: .leading, spacing: 8) {
                TaskTitleStack()
                HStack {
                    IconLabel()
                    Spacer(minLength: 6)
                    Text("Mon, Sep 28")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct TaskColumn: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader()
                Text("Active work for this week.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                ForEach(0..<4) { _ in StackedTaskRow() }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 14)
        .overlay(alignment: .trailing) { Divider() }
    }
}

struct TaskColumns: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {} label: {
                    Image(systemName: "rectangle.compress.vertical")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 24)

            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<3) { _ in TaskColumn() }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
    }
}

#Preview {
    TaskColumns()
        .preferredColorScheme(.dark)
        .frame(width: 1440, height: 900)
}
