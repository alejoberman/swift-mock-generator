import Foundation

public struct SwiftClosureExpression: Equatable {
    public var parameters: [String]
    public var body: [SwiftStatement]

    public init(parameters: [String] = [], body: [SwiftStatement] = []) {
        self.parameters = parameters
        self.body = body
    }
}
