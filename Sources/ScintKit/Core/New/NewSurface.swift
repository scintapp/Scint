import SwiftUI


/// A query in the rebuilt shape. One method, because controls now travel inside the params they
/// belong to rather than in a parallel object that has to be told which node it is acting on.
@MainActor protocol NewQuery {
    static func params(_ model: any Model) -> NewParams
}

/// The generic surface for the sketch factory, parallel to `AnySurface`.
///
/// It conforms to the existing `Surface`, so it inherits the seam that already works: the surface
/// passes itself into the factory, and through it the factory reaches `panel.state` and
/// `model.session` without any of that being described in params.
struct NewSurface: Surface {
    var panel: any Panel
    var model: any Model
    var params: NewParams

    init(panel: any Panel, model: any Model, params: NewParams) {
        self.panel = panel
        self.model = model
        self.params = params
    }

    init(panel: any Panel, model: any Model, query: any NewQuery.Type) {
        self.init(panel: panel, model: model, params: query.params(model))
    }

    var body: some View {
        switch params {
            case .panel(let params):
                NewFactory.build(self, panel: params)

            case .surface(.section(let params)):
                ScrollView {
                    NewFactory.build(self, section: params)
                        .padding(Style.Spacing.md)
                }

            case .surface(.item(let params)):
                NewFactory.build(self, item: params)
        }
    }
}
