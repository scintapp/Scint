import SwiftUI


struct ActionButton: View {
    let title: String
    let onAction: (String) -> Void

    var symbol: String {
        switch title {
            case "Approve": return "checkmark"
            case "Pause": return "pause"
            case "Resume": return "play.fill"
            case "Stop": return "stop"
            case "Open": return "text.bubble"
            default: return "ellipsis"
        }
    }

    var opensTranscript: Bool { title == "Open" }
    var controlSize: CGFloat { opensTranscript ? 27 : 25 }
    var iconSize: CGFloat { opensTranscript ? 10.5 : 10 }
    var fill: Color { Color.primary.opacity(opensTranscript ? 0.065 : 0.07) }
    var stroke: Color { Color.primary.opacity(opensTranscript ? 0.09 : 0.08) }
    var helpText: String { opensTranscript ? "Open transcript" : title }

    var body: some View {
        Button { onAction(title) } label: {
            Iconography.Icon(symbol: symbol, tint: Style.Foreground.primary, sizing: iconSize)
                .frame(width: controlSize, height: controlSize)
        }
        .help(helpText)
        .buttonStyle(.plain)
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(Style.Foreground.primary)
        .background { Circle().fill(fill) }
        .overlay {
            if opensTranscript { Circle().strokeBorder(stroke, lineWidth: 0.75) }
            else { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(stroke, lineWidth: 0.75) }
        }
    }
}

struct NavigationButtons: View {
    let model: any Model

    var body: some View {
        ControlGroup {
            Button { model.session.back() } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!model.session.navigation.canGoBack)

            Button { model.session.forward() } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(!model.session.navigation.canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}

struct BackButton: View {
    let model: any Model

    var body: some View {
        if model.session.navigation.canGoBack {
            Button { model.session.back() } label: {
                Image(systemName: "chevron.backward")
            }
        }
    }
}

struct CreateButton: View {
    var model: any Model

    @State var text: String = ""
    @State var presented: Bool = false

    private func create() {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        presented = false
        Action.createSpace(
            in: model.session.origin,
            name: name.isEmpty ? "New Space" : name,
            model: model
        )
    }

    var body: some View {
        var scoped: Bool { model.session.origin.type is Space.Type }

        SwiftUI.Menu {
            Button {
                text = ""
                presented = true
            } label: {
                Label("New Space", systemImage: "plus")
            }

            if scoped {
                Button {
                    Action.createMaterial(in: model.session.origin, model: model)
                } label: {
                    Label("New Material", systemImage: "plus")
                }
            }
        } label: { Image(systemName: "plus") }
            .menuIndicator(.hidden)
            .sheet(isPresented: $presented) {
                VStack(alignment: .trailing, spacing: Style.Spacing.xl) {
                    TextField("Name", text: $text)
                        .onSubmit { create() }

                    HStack(spacing: Style.Spacing.md) {
                        Button("Cancel", role: .cancel) { presented = false }
                        Button("Create") { create() }
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(Style.Spacing.xxl)
                .frame(width: Style.Spacing.menuWidth)
            }
    }
}


struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

struct CountButton: View {
    let count: Int?
    var label = "Load"
    let onLoad: () -> Void

    var body: some View {
        HStack {
            if let count {
                Text(count == 0 ? "None" : count == 1 ? "1 Loaded" : "\(count) Loaded")
                    .font(.system(size: 12))
                    .foregroundStyle(count == 0 ? .tertiary : .secondary)
            }
            Button(label, action: onLoad)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

