import Foundation

public struct SwiftArgument: Equatable {
    public let label: String?
    public let expression: SwiftExpression

    public init(label: String?, expression: SwiftExpression) {
        self.label = label
        self.expression = expression
    }
}
