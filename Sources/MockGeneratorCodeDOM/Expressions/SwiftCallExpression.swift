import Foundation

public struct SwiftCallExpression: Equatable {
    public let callee: SwiftExpression
    public let arguments: [SwiftArgument]

    public init(callee: SwiftExpression, arguments: [SwiftArgument] = []) {
        self.callee = callee
        self.arguments = arguments
    }
}
