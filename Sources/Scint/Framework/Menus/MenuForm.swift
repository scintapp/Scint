import SwiftUI
import ScintRuntime
import ScintComponents


struct MenuForm: View {
    @Binding var primary: String
    let kind: MenuFormKind
    let updating: Bool
    let size: CGSize
    let focus: FocusState<MenuFocus?>.Binding
    let onCancel: () -> Void
    let onCommit: () -> Void

    var header: some View {
        HStack {
            Iconography.Icon(
                symbol: kind.icon,
                tint: Iconography.menuTint(for: kind),
                sizing: Metrics.rowIcon
            )
            .frame(width: Style.Dimension.control(.small), height: Style.Dimension.control(.small))

            Text(kind.title(updating: updating))
                .font(Typography.body.weight(.medium))
                .foregroundStyle(Style.Foreground.primary)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    var fields: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.heading) {
            formField(
                placeholder: kind.primaryPlaceholder,
                text: $primary,
                focusValue: .form,
                commit: onCommit
            )

            actions
        }
        .padding(2)
    }

    var actions: some View {
        HStack(spacing: 8) {
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(Typography.detail)
                .foregroundStyle(Style.Foreground.secondary)
            Button(action: onCommit) {
                Text(updating ? "Update" : "Insert")
                    .font(Typography.detail)
                    .foregroundStyle(Style.Foreground.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: Style.Dimension.control(.small))
                    .background(Style.Background.surface)
                    .clipShape(Style.Shape.card)
                    .overlay {
                        Style.Shape.card
                            .strokeBorder(
                                Style.Background.surface,
                                lineWidth: 1
                            )
                    }
            }
            .buttonStyle(.plain)
        }
    }

    func formField(placeholder: String, text: Binding<String>, focusValue: MenuFocus, commit: @escaping () -> Void) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(Typography.body.weight(.medium))
            .foregroundStyle(Style.Foreground.secondary)
            .padding(.horizontal, 8)
            .frame(height: Style.Dimension.control(.small))
            .background(
                Style.Shape.control
                    .fill(Style.Background.surface)
                    .overlay(
                        Style.Shape.control
                            .stroke(
                                Style.Background.surface,
                                lineWidth: 1
                            )
                    )
            )
            .focused(focus, equals: focusValue)
            .onKeyPress(.return) {
                commit()
                return .handled
            }
            .onKeyPress(.escape) {
                onCancel()
                return .handled
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            header
            Divider().opacity(Style.Opacity.outline)
            fields
        }
        .frame(width: 280, height: 400, alignment: .top)
        .glassEffect(.regular, in: Style.Shape.control)
    }
}
