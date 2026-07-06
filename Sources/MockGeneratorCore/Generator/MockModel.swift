import Foundation

public struct MockModel {
    public let className: String
    public let accessLevel: AccessLevel
    public let modifiers: [MockModifier]
    public let inheritedTypes: [TypeDescriptor]
    public let members: [MockMember]
    public let imports: [String]

    public init(className: String,
                accessLevel: AccessLevel,
                modifiers: [MockModifier] = [],
                inheritedTypes: [TypeDescriptor] = [],
                members: [MockMember] = [],
                imports: [String] = []) {
        self.className = className
        self.accessLevel = accessLevel
        self.modifiers = modifiers
        self.inheritedTypes = inheritedTypes
        self.members = members
        self.imports = imports
    }
}
