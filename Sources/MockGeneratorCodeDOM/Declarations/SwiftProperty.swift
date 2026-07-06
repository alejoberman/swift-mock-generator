import Foundation

public struct SwiftProperty: Equatable {
    public var modifiers: [SwiftModifier]
    public var isMutable: Bool
    public var name: String
    public var type: SwiftType
    public var getter: [SwiftStatement]
    public var setter: [SwiftStatement]?

    public init(modifiers: [SwiftModifier] = [],
                isMutable: Bool = true,
                name: String,
                type: SwiftType,
                getter: [SwiftStatement] = [],
                setter: [SwiftStatement]? = nil) {
        self.modifiers = modifiers
        self.isMutable = isMutable
        self.name = name
        self.type = type
        self.getter = getter
        self.setter = setter
    }
}
