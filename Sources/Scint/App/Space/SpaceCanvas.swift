import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct CanvasZoom: View {
    @Binding var viewport: CanvasViewport

    var body: some View {
        Group {
            Button { viewport.zoom(-1) } label: { Image(systemName: "minus") }
            Button { viewport.actual() } label: { Text(viewport.percentage) }
            Button { viewport.zoom(+1) } label: { Image(systemName: "plus") }
        }
        .buttonStyle(.automatic)
        .font(.system(size: 11, weight: .medium))
    }
}

struct CanvasPresentation: View {
    @Binding var axis: CanvasAxis

    var body: some View {
        ForEach(CanvasAxis.allCases) { option in
            Toggle(isOn: .init(get: { axis == option }, set: { if $0 { axis = option } })) {
                Image(systemName: option.symbol)
            }
            .toggleStyle(.button)
        }
    }
}

struct CanvasMap: Surface {
    var panel: any Panel
    var model: any Model

    var scope: Reference? { model.session.scope }
    var path: [Reference] { model.session.navigation.path(for: selection) }
    var spaces: [Reference] { path.filter { $0.type is Space.Type } }
    var selection: Selection { model.session.selection }
    var surface: AnySurface { .init(panel: panel, model: model) }
    var matches: [Reference] { path.filter { $0.descriptor.name.localizedCaseInsensitiveContains(text) } }

    @State private var presented = false
    @State private var text = ""

    var body: some View {
        if let scope {
            CanvasControl {
                Button { presented.toggle() } label: {
                    HStack(alignment: .center, spacing: Style.Spacing.icon) {
                        Text(scope.descriptor.name)
                            .font(.system(size: 13.5, weight: .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                }
            }
            .popover(isPresented: $presented) {
                VStack(spacing: 8) {
                    Filter(text: $text)

                    if text.isEmpty {
                        surface.render(surface, PathQuery.parameters(model), PathQuery.controls(model))
                    } else if matches.isEmpty {
                        Text("No Matches")
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(matches, id: \.self) { match in
                                    ListLink(
                                        name: match.descriptor.name,
                                        ref: match,
                                        image: "",
                                        selected: selection.selected(match),
                                        focused: model.session.focus == .structure(match)
                                    ) {
                                        model.select(match)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .frame(width: 260, height: 280)
                .padding(.top, 8)
            }
            .onChange(of: presented) { _, shown in if !shown { text = "" } }
            .onChange(of: model.session.selection) { presented = false }
        }
    }
}

struct CanvasControl<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ControlGroup { content }
            .controlGroupStyle(.navigation)
            .controlSize(.extraLarge)
            .foregroundStyle(Style.Foreground.primary, Style.Foreground.secondary)
            .tint(Style.Background.selection)
            .glassEffect(.regular.tint(.black.opacity(0.2)), in: Capsule())
    }
}

struct SpaceCanvas: Surface {
    var panel: any Panel
    var model: any Model

    @State var viewport: CanvasViewport = .init()
    @State var axis: CanvasAxis = .vertical

    var body: some View {
        Canvas(refs: model.session.bridged, axis: axis, viewport: viewport, onBackground: { model.focus(nil) }) { ref in
            SpaceNode(ref: ref, panel: panel, model: model)
                .frame(width: 320)
        }
        .ignoresSafeArea(.container, edges: .trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Style.Background.canvas)
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .bottom) {
                CanvasMap(panel: panel, model: model)
                Spacer()
                CanvasControl { CanvasPresentation(axis: $axis) }
                CanvasControl { CanvasZoom(viewport: $viewport) }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
}
