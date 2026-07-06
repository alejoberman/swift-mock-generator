import Foundation

public struct ProtocolDescriptor: Equatable {
    public let module: String?
    public let name: String
    public let accessLevel: AccessLevel
    public let inheritedTypes: [String]
    public let members: [MemberDescriptor]
    public let imports: [String]
    
    public init(module: String? = nil, name: String, accessLevel: AccessLevel, inheritedTypes: [String], members: [MemberDescriptor], imports: [String] = []) {
        self.module = module
        self.name = name
        self.accessLevel = accessLevel
        self.inheritedTypes = inheritedTypes
        self.members = members
        self.imports = imports
    }
}
