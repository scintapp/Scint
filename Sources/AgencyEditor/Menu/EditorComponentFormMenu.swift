import SwiftUI


struct EditorComponentFormMenu: View {
    @Environment(EditorModel.self) private var editor

    let kind: ComponentFormKind
    let focus: FocusState<EditorMenuFocus?>.Binding

    private var menu: MenuModel { editor.menu }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.08))
            fields
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(width: menu.size.width, height: menu.size.height, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: kind.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)

            Text(kind.title)
                .font(.system(size: 13, weight: .semibold))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 10) {
            formField(
                placeholder: kind.primaryPlaceholder,
                text: Binding(get: { menu.formPrimary }, set: { menu.formPrimary = $0 }),
                focusValue: .formPrimary,
                submit: submitPrimaryField
            )

            if kind == .link {
                formField(
                    placeholder: "URL",
                    text: Binding(get: { menu.formSecondary }, set: { menu.formSecondary = $0 }),
                    focusValue: .formSecondary,
                    submit: { editor.commitMenu() }
                )
            }

            actions
        }
        .padding(12)
    }

    private var actions: some View {
        HStack {
            Spacer()
            Button("Cancel") { menu.close() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Button("Insert") { editor.commitMenu() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    private func formField(
        placeholder: String,
        text: Binding<String>,
        focusValue: EditorMenuFocus,
        submit: @escaping () -> Void
    ) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
            .focused(focus, equals: focusValue)
            .onSubmit(submit)
            .onKeyPress(.escape) { menu.close(); return .handled }
    }

    private func submitPrimaryField() {
        if kind == .link {
            focus.wrappedValue = .formSecondary
        } else {
            editor.commitMenu()
        }
    }
}
