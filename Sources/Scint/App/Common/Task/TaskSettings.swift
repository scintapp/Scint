import SwiftUI


struct TaskSettings: Surface {
    var panel: any Panel
    var model: any Model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TaskInspectorHeader()
            Picker("Space", selection: .constant(0)) {
                Label("Engineering", systemImage: "folder").tag(0)
                Label("Composition", systemImage: "folder").tag(1)
            }
            .pickerStyle(.menu)
            HStack(spacing: 8) {
                Picker("Date", selection: .constant(0)) {
                    Label("Sat, Sep 26, 2026", systemImage: "calendar").tag(0)
                }
                .pickerStyle(.menu)
                Picker("Time", selection: .constant(0)) {
                    Text("10:00 AM").tag(0)
                }
                .pickerStyle(.menu)
            }
            Divider().padding(.vertical, 10)
            TaskField()
            VStack(alignment: .leading, spacing: 8) {
                Text("Parameters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(0..<3) { _ in TaskInspectorRow() }
                }
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.vertical, 12)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Links")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {} label: { Image(systemName: "plus") }
                        .buttonStyle(.plain)
                }
                TaskInspectorRow()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.vertical, 12)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {} label: { Image(systemName: "plus") }
                        .buttonStyle(.plain)
                }
                TextField("Add a note…", text: .constant(""))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 360, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.background)
    }
}

struct TaskField: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            TextEditor(text: .constant("Validate edge cases and error handling for command runner state transitions, including cancellation and timeout behavior."))
                .font(.body)
                .frame(height: 82)
                .scrollContentBackground(.hidden)
                .padding(7)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.vertical, 12)
    }
}

struct TaskInspectorRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Label("Model", systemImage: "gearshape")
                .font(.subheadline)
            Spacer()
            Text("Default")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider() }
    }
}

struct TaskInspectorHeader: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("Complete task", isOn: .constant(false))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .fixedSize()
            Text("Review command runner states")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}
