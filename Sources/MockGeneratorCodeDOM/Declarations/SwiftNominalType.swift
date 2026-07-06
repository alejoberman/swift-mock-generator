import Foundation

public struct SwiftNominalType: Equatable {
    public let kind: SwiftTypeKind
    public let name: String
    public let modifiers: [SwiftModifier]
    public let inheritedTypes: [SwiftType]
    public let members: [SwiftDeclaration]
    
    public init(
        kind: SwiftTypeKind,
        name: String,
        modifiers: [SwiftModifier] = [],
        inheritedTypes: [SwiftType] = [],
        members: [SwiftDeclaration] = []
    ) {
        self.kind = kind
        self.name = name
        self.modifiers = modifiers
        self.inheritedTypes = inheritedTypes
        self.members = members
    }
}

public enum SwiftTypeKind {
    case `class`
    case `struct`
    case `enum`
    case `actor`
    case `protocol`
}

public extension SwiftNominalType {

    static func `class`(name: String,
                        modifiers: [SwiftModifier] = [],
                        inheritedTypes: [SwiftType] = [],
                        members: [SwiftDeclaration] = []) -> Self {
        Self(kind: .class,
             name: name,
             modifiers: modifiers,
             inheritedTypes: inheritedTypes,
             members: members)
    }
}
