import Foundation
import SwiftUI


struct CanvasZoom: View {
    var viewport: CanvasViewport

    var body: some View {
        Group {
            Button { viewport.zoom(-1) } label: { Image(systemName: "minus") }
            Button { viewport.actual() } label: { Text(viewport.percentage) }
            Button { viewport.zoom(-1) } label: { Image(systemName: "plus") }
        }
        .buttonStyle(.automatic)
        .font(.system(size: 11, weight: .medium))
    }
}

struct CanvasPresentation: View {
    var panel: ContentPanel

    var body: some View {
        ForEach(CanvasAxis.allCases) { option in
            Toggle(isOn: .init(get: { panel.axis == option }, set: { if $0 { panel.axis = option } })) {
                Image(systemName: option.symbol)
            }
        }
    }
}

struct CanvasControl<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ControlGroup {
            content
        }
        .controlSize(.extraLarge)
        .controlGroupStyle(.navigation)
        .glassEffect(.regular.tint(Style.Background.glass.opacity(0.75)), in: Capsule())
        .foregroundStyle(Style.Foreground.primary, Style.Foreground.faint, Style.Foreground.muted)
        .tint(Style.Background.control)
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
                    HStack(alignment: .center, spacing: Style.Spacing.lg) {
                        Text(scope.descriptor.name)
                            .font(.system(size: 13.5, weight: .medium))
                            .lineLimit(Style.Limit.singleLine)
                    }
                    .padding(.horizontal, 8)
                }
            }
            .popover(isPresented: $presented) {
                VStack(spacing: 8) {
                    Filter(text: $text)

                    if text.isEmpty {
                        surface.render(surface, SpacesList.parameters(model), SpacesList.controls(model))
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

struct CanvasSurface: Surface {
    var panel: any Panel
    var model: any Model

    @State var viewport: CanvasViewport = .init()
    @State var axis: CanvasAxis = .vertical

    var body: some View {
        Canvas(refs: model.session.bridged, axis: axis, viewport: viewport, onBackground: { model.focus(nil) }) { ref in
            NodeSurface(ref: ref, panel: panel, model: model)
                .frame(width: 320)
        }
        .ignoresSafeArea(.container, edges: .trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Style.Background.void)
    }
}
