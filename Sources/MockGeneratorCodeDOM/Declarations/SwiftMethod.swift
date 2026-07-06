import Foundation

public struct SwiftMethod: Equatable {
    public var modifiers: [SwiftModifier]
    public var name: String
    public var parameters: [SwiftParameter]
    public var returnType: SwiftType?
    public var isAsync: Bool
    public var isThrows: Bool
    public var body: [SwiftStatement]

    public init(modifiers: [SwiftModifier] = [],
                name: String,
                parameters: [SwiftParameter] = [],
                returnType: SwiftType? = nil,
                isAsync: Bool = false,
                isThrows: Bool = false,
                body: [SwiftStatement] = []) {
        self.modifiers = modifiers
        self.name = name
        self.parameters = parameters
        self.returnType = returnType
        self.isAsync = isAsync
        self.isThrows = isThrows
        self.body = body
    }
}
