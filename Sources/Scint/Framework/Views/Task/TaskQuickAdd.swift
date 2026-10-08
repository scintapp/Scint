import SwiftUI


struct TaskQuickAdd: View {
    var body: some View {
        HStack(spacing: 12) {
            Toggle("Complete Task", isOn: .constant(false))
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
