import SwiftUI


struct OutlineActivity: View {
    var outline: Outline

    var body: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.md) {
            if outline.spaces.isEmpty {
                Text("Not given to a space yet")
                    .foregroundStyle(Style.Foreground.secondary)
            }

            ForEach(outline.spaces) { space in
                let dot = Iconography.dot(for: space)
                HStack(spacing: Style.Spacing.md) {
                    Iconography.icon(symbol: dot.symbol, tint: dot.tint, ref: space)
                    Text(space.descriptor.name)
                    Spacer()
                }
            }
        }
        .padding(Style.Spacing.xxl)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
    }
}

struct OutlineDetail: View {
    var panel: any Panel
    var model: any Model
    var outline: Outline

    var body: some View {
        VStack(spacing: 0) {
            MaterialSurface(ref: outline.ref, panel: panel, model: model)
            Divider()
            OutlineActivity(outline: outline)
                .frame(height: 240, alignment: .top)
        }
    }
}

struct OutlinesSurface: Surface {
    var panel: any Panel
    var model: any Model

    var list: AnySurface { .init(panel: panel, model: model) }

    var outline: Outline? {
        let home = model.session.outlines
        guard let ref = model.session.material, Space.with(home, { $0 })?.materials.contains(ref) == true else { return nil }
        return Outline(ref: ref, outlines: home)
    }

    var body: some View {
        HStack(spacing: 0) {
            list.render(list, OutlinesList.parameters(model), OutlinesList.controls(model))
                .frame(width: 320)

            Divider()

            if let outline { OutlineDetail(panel: panel, model: model, outline: outline) }
            else { NoSpace(title: "No Outline Selected") }
        }
        .background(Style.Background.base)
    }
}
