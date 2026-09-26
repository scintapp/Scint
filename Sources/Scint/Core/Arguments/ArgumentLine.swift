import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct ArgumentLine: View {
    let parameters: [Parameter]
    let values: [String: Value]

    init(_ parameters: [Parameter], values: [String: Value]) {
        self.parameters = parameters
        self.values = values
    }

    var tokens: [(text: String, literal: Bool)] {
        parameters.flatMap { parameter -> [(text: String, literal: Bool)] in
            switch parameter {
                case .fixed(let value):
                    return value.rendered.map { ($0, true) }
                case .argument(let name, let type, let required, let fallback):
                    guard let value = values[name] ?? fallback, let built = try? type.construct(value, name: name)
                    else { return required ? [("‹\(name)›", false)] : [] }
                    return built.rendered.map { ($0, false) }
                case .command(let name, let ref):
                    return [("‹\((values[name] ?? ref).references.first?.descriptor.name ?? name)›", false)]
                case .callback(let name, _):
                    return [("open", true), ("‹\(values[name]?.references.first?.descriptor.name ?? name)›", false)]
            }
        }
    }

    var body: some View {
        tokens.reduce(Text("")) { line, token in
            line + Text(token.text + " ").foregroundStyle(token.literal ? Style.Foreground.subtle : Style.Foreground.primary)
        }
        .font(Typography.code)
        .textSelection(.enabled)
    }
}
