//import SwiftUI
//import CodeEditSourceEditor
//import ScintComponents
//
//
//struct DocumentCode: View {
//    @State var text = "let x = 1.0"
//    @State var editorState = SourceEditorState()
//    @State var font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
//    @State var autoCompleteCoordinator = AutoCompleteCoordinator()
//    @State var theme = EditorTheme(
//        text: .init(color: NSColor(Color(red: 0.89804, green: 0.9098, blue: 0.91373))),
//        insertionPoint: .alternateSelectedControlTextColor,
//        invisibles: .init(color: NSColor(Color(red: 0.78824, green: 0.92157, blue: 0.92157))),
//        background: NSColor(Color(red: 0.10588, green: 0.1098, blue: 0.1098)),
//        lineHighlight: NSColor(Style.Background.canvas),
//        selection: NSColor(Color(red: 0.51765, green: 0.38431, blue: 0.45882)),
//        keywords: .init(color: NSColor(Color(red: 0.51765, green: 0.38431, blue: 0.45882))),
//        commands: .init(color: NSColor(Color(red: 0.78824, green: 0.92157, blue: 0.92157))),
//        types: .init(color: NSColor(Color(red: 0.78824, green: 0.92157, blue: 0.92157))),
//        attributes: .init(color: NSColor(Color(red: 0.78824, green: 0.92157, blue: 0.92157))),
//        variables: .init(color: NSColor(Color(red: 0.78824, green: 0.92157, blue: 0.92157))),
//        values: .init(color: NSColor(Color(red: 0.78824, green: 0.92157, blue: 0.92157))),
//        numbers: .init(color: NSColor(Color(red: 0.78824, green: 0.92157, blue: 0.92157))),
//        strings: .init(color: NSColor(Color(red: 0.78824, green: 0.92157, blue: 0.92157))),
//        characters: .init(color: NSColor(Color(red: 0.78824, green: 0.92157, blue: 0.92157))),
//        comments: .init(color: NSColor(Color(red: 0.78824, green: 0.92157, blue: 0.92157))),
//    )
//
//    var body: some View {
//        SourceEditor(
//            $text,
//            language: .swift,
//            configuration: SourceEditorConfiguration(
//                appearance: .init(
//                    theme: theme,
//                    font: .monospacedSystemFont(ofSize: 14, weight: .light),
//                    wrapLines: true
//                ),
//                behavior: .init(indentOption: .spaces(count: 4))
//            ),
//            state: $editorState,
//            coordinators: [autoCompleteCoordinator]
//        )
//    }
//
//    final class AutoCompleteCoordinator: @MainActor TextViewCoordinator {
//        func prepareCoordinator(controller: TextViewController) { }
//
//        @MainActor func textViewDidChangeText(controller: TextViewController) {
//            for cursorPosition in controller.cursorPositions where cursorPosition.range.location >= 5 {
//                let location = cursorPosition.range.location
//                let previousRange = NSRange(start: location - 5, end: location)
//                let string = (controller.text as NSString).substring(with: previousRange)
//
//                if string.lowercased() == "hello" {
//                    controller.textView.replaceCharacters(in: NSRange(location: location, length: 0), with: " world!")
//                }
//            }
//        }
//    }
//}
//
