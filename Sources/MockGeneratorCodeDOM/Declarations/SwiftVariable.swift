import Foundation

public struct SwiftVariable: Equatable {
    public var modifiers: [SwiftModifier]
    public var isMutable: Bool
    public var name: String
    public var type: SwiftType?
    public var initializer: SwiftExpression?

    public init(modifiers: [SwiftModifier] = [],
                isMutable: Bool = true,
                name: String,
                type: SwiftType? = nil,
                initializer: SwiftExpression? = nil) {
        self.modifiers = modifiers
        self.isMutable = isMutable
        self.name = name
        self.type = type
        self.initializer = initializer
    }
}
