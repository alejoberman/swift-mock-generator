import Foundation

public struct MockVariable: Equatable {

    public let accessLevel: AccessLevel
    public let isMutable: Bool
    public let modifiers: [MockVariableModifier]
    public let name: String
    public let type: TypeDescriptor
    public let initializer: String?

    public init(accessLevel: AccessLevel = .internal,
                isMutable: Bool = true,
                modifiers: [MockVariableModifier] = [],
                name: String,
                type: TypeDescriptor,
                initializer: String? = nil) {
        self.accessLevel = accessLevel
        self.isMutable = isMutable
        self.modifiers = modifiers
        self.name = name
        self.type = type
        self.initializer = initializer
    }
}

public enum MockVariableModifier: Equatable {
    case `static`
    case `lazy`
    case `weak`
    case `unowned`
}
