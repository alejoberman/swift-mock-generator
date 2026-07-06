import Foundation

public enum SwiftStatement: Equatable {
    case expression(SwiftExpression)
    case variable(SwiftVariable)
    case `return`(SwiftExpression)
    case ifStatement(SwiftIfStatement)
}
