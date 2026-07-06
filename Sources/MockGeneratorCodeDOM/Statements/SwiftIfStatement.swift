import Foundation

public struct SwiftIfStatement: Equatable {
    public var condition: SwiftExpression
    public var body: [SwiftStatement]
    public var elseBody: [SwiftStatement]

    public init(condition: SwiftExpression,
                body: [SwiftStatement],
                elseBody: [SwiftStatement] = []) {
        self.condition = condition
        self.body = body
        self.elseBody = elseBody
    }
}
