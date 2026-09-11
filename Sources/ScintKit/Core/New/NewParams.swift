import SwiftUI


/// Sketch implementation of the rebuilt parameter primitives.
///
/// Parallel to `Params`/`Controls`. Nothing here is referenced by the live path.
///
/// Two deviations from the sketch, both forced by making it compile:
///
/// - `Component` and `Control` carry associated values. A control has to carry the closure it
///   maps to and those closures differ in shape per case; a component has to say where it sits
///   when the position isn't implied by its layout.
/// - Identity therefore lives in `id` alone, since associated closures cost `Hashable`. Every
///   initializer requires an id, and the reference-backed one derives it from the reference, so
///   there is no path by which an id goes unpopulated.
struct NewParam {
    /// Where a component or control sits in its row. `stack` means it shares one slot with the
    /// other stacked entries, the first drawn at rest and the next on hover.
    enum Position: Hashable { case top, bottom, leading, trailing, stack }

    /// A discriminator naming a view. Payload only where the reference cannot answer.
    enum Component {
        case badge(Badge, Position = .trailing)
        case block
        case card
        case chip(String, Position = .trailing)
        case icon(Position = .leading)
        case model(Iconography.Model, Position = .leading)
        case symbol(String, Color, Position = .leading)
        case text(Text)

        /// `name` and `description` resolve through the reference. `literal` and `detail` are the
        /// same two roles for a node the runtime does not back — a config key has no reference to
        /// resolve a subtitle from, and styling it by role beats adding a component case per style.
        enum Text { case name, description, literal(String), detail(String) }
        enum Badge { case count(Int), label(String), tasks }
    }

    /// Behavior bound at construction, so nothing has to be identified on the way back up.
    ///
    /// `disclosure` is an addition to the sketch. Expansion is behavior bound at construction like
    /// any other control, and modelling it as one keeps it inside the row it belongs to; the
    /// alternative is a fixed disclosure slot on the row view, which is the kind of slot this
    /// design exists to avoid. It sits at `.stack`, so a row that also stacks an icon trades the
    /// one for the other on hover.
    ///
    /// `date`, `field` and `toggle` feed a `Binding` setter, which requires an `@isolated(any) @Sendable`
    /// function. Their handlers all run main-actor model code, so they are marked `@MainActor`.
    enum Control {
        case action(() -> Void)
        case button(String, () -> Void)
        case date(Date, @MainActor (Date) -> Void)
        case disclosure(Bool, () -> Void)
        case field(String, @MainActor (String) -> Void)
        case load(String, [Reference], (Reference) -> Void)
        case picker([String], String, (String) -> Void)
        case range([String], String, (String) -> Void)
        case toggle(Bool, @MainActor (Bool) -> Void)
    }

    struct Sizing: Hashable {
        let min: CGSize?
        let ideal: CGSize
        let max: CGSize?

        init(size: CGSize, min: CGSize? = nil, max: CGSize? = nil) {
            self.min = min
            self.ideal = size
            self.max = max
        }
    }
}

enum NewParams {
    case surface(Surface), panel(Panel)

    enum Surface {
        case item(Item), section(Section)

        var id: AnyHashable {
            switch self {
                case .item(let item): item.id
                case .section(let section): section.id
            }
        }
    }

    struct Item: Identifiable {
        let id: AnyHashable
        let ref: Reference?
        let layout: Layout
        let components: [NewParam.Component]
        let controls: [NewParam.Control]

        enum Layout: CaseIterable { case column, row }

        init(
            id: AnyHashable,
            ref: Reference? = nil,
            layout: Layout = .row,
            components: [NewParam.Component] = [],
            controls: [NewParam.Control] = []
        ) {
            self.id = id
            self.ref = ref
            self.layout = layout
            self.components = components
            self.controls = controls
        }

        init(
            _ ref: Reference,
            layout: Layout = .row,
            components: [NewParam.Component] = [],
            controls: [NewParam.Control] = []
        ) {
            self.init(
                id: AnyHashable(ref),
                ref: ref,
                layout: layout,
                components: components,
                controls: controls
            )
        }
    }

    struct Section: Identifiable {
        let id: AnyHashable
        let ref: Reference?
        let layout: Layout
        let components: [NewParam.Component]
        let controls: [NewParam.Control]
        let params: [Surface]

        enum Layout: CaseIterable { case grid, group, list, table }

        init(
            id: AnyHashable,
            ref: Reference? = nil,
            layout: Layout = .list,
            components: [NewParam.Component] = [],
            controls: [NewParam.Control] = [],
            params: [Surface] = []
        ) {
            self.id = id
            self.ref = ref
            self.layout = layout
            self.components = components
            self.controls = controls
            self.params = params
        }

        init(
            _ ref: Reference,
            layout: Layout = .list,
            components: [NewParam.Component] = [],
            controls: [NewParam.Control] = [],
            params: [Surface] = []
        ) {
            self.init(
                id: AnyHashable(ref),
                ref: ref,
                layout: layout,
                components: components,
                controls: controls,
                params: params
            )
        }
    }

    struct Panel: Identifiable {
        let key: PanelKey
        let type: PanelType
        let layout: Layout
        let sizing: NewParam.Sizing
        let controls: [NewParam.Control]
        let params: [NewParams]

        var id: PanelKey { key }

        enum Layout: CaseIterable { case list }
        enum PanelType: CaseIterable { case fixed, floating }

        init(
            key: PanelKey,
            type: PanelType = .fixed,
            layout: Layout = .list,
            sizing: NewParam.Sizing,
            controls: [NewParam.Control] = [],
            params: [NewParams] = []
        ) {
            self.key = key
            self.type = type
            self.layout = layout
            self.sizing = sizing
            self.controls = controls
            self.params = params
        }
    }
}

extension NewParams.Surface: Identifiable {

}

