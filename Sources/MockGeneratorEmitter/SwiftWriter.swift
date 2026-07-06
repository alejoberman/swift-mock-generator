import Foundation

public final class SwiftWriter {
    private var buffer = ""
    private(set) public var indentationLevel = 0
    private var isAtLineStart = true

    public init() {}

    public var output: String { buffer }

    public func write(_ text: String) {
        guard !text.isEmpty else { return }
        if isAtLineStart {
            buffer += String(repeating: "    ", count: indentationLevel)
            isAtLineStart = false
        }
        buffer += text
    }

    public func newline() {
        buffer += "\n"
        isAtLineStart = true
    }

    public func indent() { indentationLevel += 1 }
    public func outdent() { indentationLevel = max(0, indentationLevel - 1) }

    public func space() { write(" ") }
    public func comma() { write(",") }
    public func colon() { write(":") }
    public func openBrace() { write("{") }
    public func closeBrace() { write("}") }
    public func openParen() { write("(") }
    public func closeParen() { write(")") }
}
