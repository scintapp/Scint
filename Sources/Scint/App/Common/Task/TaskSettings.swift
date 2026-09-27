import SwiftUI


struct TaskSettings: Surface {
    var panel: any Panel
    var model: any Model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorHeader()
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
