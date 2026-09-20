import Foundation


/// Where a caret sits when a surface takes focus, and which way it was heading when it
/// left one.
enum EditEdge: Equatable {
    case start
    case end
    case offset(Int)
}

/// A `/` or `@` a text surface noticed, with the screen rect to hang something from.
/// The surface reports the character it saw; what that means is the host's business.
struct EditTrigger: Equatable {
    let symbol: String
    let query: String
    let range: NSRange
    let anchor: CGRect
}

/// Everything a block's surface tells the canvas. Nothing here names a block type, a
/// menu or a component: a surface reports what happened to it, never what it should mean.
/// The canvas answers whether it did anything, so a surface can keep a key it offered.
enum EditEvent {
    case focused
    case changed(String)
    case trigger(EditTrigger?)
    case newline
    case deleteAtStart
    case escape
    case exit(EditEdge)
}
