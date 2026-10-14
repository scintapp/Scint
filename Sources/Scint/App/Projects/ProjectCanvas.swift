import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct CanvasZoom: View {
    @Binding var viewport: CanvasViewport

    var body: some View {
        HStack(spacing: 2) {
            Button { viewport.zoom(-1) } label: {
                Image(systemName: "minus")
                    .padding(.horizontal, 14)
                    .frame(height: 24)
                    .contentShape(Style.Shape.button)
            }
            Button { viewport.actual() } label: {
                Text(viewport.percentage)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .contentShape(Style.Shape.button)
            }
            Button { viewport.zoom(+1) } label: {
                Image(systemName: "plus")
                    .padding(.horizontal, 14)
                    .frame(height: 24)
                    .contentShape(Style.Shape.button)
            }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Style.Foreground.primary)
        .padding(3)
        .surface(RoundedRectangle(cornerRadius: Style.Shape.buttonRadius + 3, style: .continuous))
    }
}

struct CanvasPresentation: View {
    @Binding var axis: CanvasAxis

    var body: some View {
        SegmentedTabs(selection: $axis, options: CanvasAxis.allCases, image: \.symbol)
    }
}

struct CanvasMap: Surface {
    var host: any Host
    var model: any Model

    var scope: Reference? { model.session.scope }
    var path: [Reference] { model.session.navigation.path(for: selection) }
    var spaces: [Reference] { path.filter { $0.type is Space.Type } }
    var selection: Selection { model.session.selection }
    var surface: AnySurface { .init(host: host, model: model) }
    var matches: [Reference] { path.filter { $0.descriptor.name.localizedCaseInsensitiveContains(text) } }

    @State private var presented = false
    @State private var text = ""

    var body: some View {
        if let scope {
            Button { presented.toggle() } label: {
                HStack(alignment: .center, spacing: Style.Spacing.icon) {
                    Text(scope.descriptor.name)
                        .font(.system(size: 13.5, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Style.Foreground.primary)
            .surface(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .popover(isPresented: $presented) {
                VStack(spacing: 8) {
                    FilterField(text: $text)

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

struct CanvasHeader: Surface {
    var host: any Host
    var model: any Model

    @Binding var viewport: CanvasViewport
    @Binding var axis: CanvasAxis

    var body: some View {
        HStack(alignment: .center) {
            CanvasMap(host: host, model: model)
            Spacer()
            CanvasPresentation(axis: $axis)
            CanvasZoom(viewport: $viewport)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

struct CanvasContent: Surface {
    var host: any Host
    var model: any Model

    @State var viewport: CanvasViewport = .init()
    @State var axis: CanvasAxis = .vertical

    var body: some View {
        Canvas(refs: model.session.space.map { [$0] } ?? [], axis: axis, viewport: viewport, onBackground: { model.focus(nil) }) { ref in
            CanvasNode(host: host, model: model, ref: ref)
                .frame(width: 320)
        }
        .background(Style.Background.canvas)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .trailing)
        .safeAreaBar(edge: .bottom) {
            CanvasHeader(host: host, model: model, viewport: $viewport, axis: $axis)
        }
    }
}
