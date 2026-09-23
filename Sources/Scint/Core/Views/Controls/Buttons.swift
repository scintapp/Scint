import SwiftUI
import ScintRuntime
import ScintComponents


struct CreateDocumentButton: View {
    var panel: any Panel
    var model: any Model

    var library: Reference { model.session.library }
    @State var presented: Bool = false

    var body: some View {
        Button {
            model.open(Document.new(library, name: "New Draft"))
            presented.toggle()
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .sheet(isPresented: $presented) {
            DocumentContent(panel: panel, model: model)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollIndicators(.hidden)
                .background(Style.Background.canvas)
                .frame(width: 660, height: 380)
                .presentationSizing(.fitted)

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
        .glassEffect(.regular.tint(Style.Background.canvas.opacity(0.4)))
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

struct CreateSpaceButton: View {
    var ref: Reference
    var model: any Model

    @State var text: String = ""
    @State var presented: Bool = false

    private func create() {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        presented = false
        Action.createSpace(
            in: ref,
            name: name.isEmpty ? "New Space" : name,
            model: model
        )
    }

    var body: some View {
        Button {
            text = ""
            presented = true
        } label: {
            Image(systemName: "plus")
        }
        .menuIndicator(.hidden)
        .sheet(isPresented: $presented) {
            VStack(alignment: .trailing, spacing: Style.Spacing.heading) {
                TextField("Name", text: $text)
                    .onSubmit { create() }

                HStack(spacing: 8) {
                    Button("Cancel", role: .cancel) { presented = false }
                    Button("Create") { create() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(Style.Spacing.page)
            .frame(width: Metrics.menuWidth)
        }
    }
}

struct CreateButton: View {
    var model: any Model

    var ref: Reference? { model.session.selection.root }

    @State var text: String = ""
    @State var presented: Bool = false

    private func create(_ ref: Reference) {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        presented = false
        Action.createSpace(in: ref, name: name.isEmpty ? "New Space" : name, model: model)
    }

    var body: some View {
        SwiftUI.Menu {
            Button { text = ""; presented = true } label: { Label("New Space", systemImage: "plus") }
                .modifier(SpaceButtonStyle())

            Button { text = ""; presented = true } label: { Label("New Document", systemImage: "plus") }
                .modifier(SpaceButtonStyle())
        } label: { Image(systemName: "plus") }
            .menuIndicator(.hidden)
            .sheet(isPresented: $presented) {
                if let ref {
                    VStack(alignment: .trailing, spacing: Style.Spacing.heading) {
                        TextField("Name", text: $text)
                            .onSubmit { create(ref) }

                        HStack(spacing: 8) {
                            Button("Cancel", role: .cancel) { presented = false }
                            Button("Create") { create(ref) }
                                .keyboardShortcut(.defaultAction)
                        }
                    }
                    .padding(Style.Spacing.page)
                    .frame(width: Metrics.menuWidth)
                }
            }
    }
}

struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle")
                .font(.system(size: 14))
                .foregroundStyle(Style.Foreground.secondary)
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

struct SpaceButtonStyle: ViewModifier {
    func body(content: Self.Content) -> some View {
        content
            .font(.system(size: 24))
            .foregroundStyle(Style.Foreground.primary)
            .frame(width: 24, height: 24, alignment: .center)
            .controlSize(.extraLarge)
            .buttonBorderShape(.circle)
            .buttonStyle(.glass)
    }
}
