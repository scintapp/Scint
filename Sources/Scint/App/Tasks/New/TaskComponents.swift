import SwiftUI


struct SectionHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Morning")
                .font(.headline)
            Text("3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
            Spacer()
            Button {} label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct TaskQuickAdd: View {
    var body: some View {
        HStack(spacing: 12) {
            Toggle("Complete task", isOn: .constant(false))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .disabled(true)
                .fixedSize()
            TextField("Add a task…", text: .constant(""))
                .textFieldStyle(.plain)
            Button {} label: {
                Image(systemName: "arrow.right.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(11)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}

struct IconLabel: View {
    var body: some View {
        Label("Engineering", systemImage: "folder")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

struct TaskChip: View {
    var body: some View {
        Label("Engineering", systemImage: "folder")
            .font(.caption)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
    }
}

struct CountBadge: View {
    var body: some View {
        Text("4")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }
}
