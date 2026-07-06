import Foundation

public struct ParameterDescriptor: Equatable {
    public let externalName: String?
    public let localName: String
    public let type: TypeDescriptor
    public let isVariadic: Bool
    public let isEscaping: Bool
    public let defaultValue: String?
    
    public init(externalName: String?,
                localName: String,
                type: TypeDescriptor,
                isVariadic: Bool,
                isEscaping: Bool = false,
                defaultValue: String?) {
        self.externalName = externalName
        self.localName = localName
        self.type = type
        self.isVariadic = isVariadic
        self.isEscaping = isEscaping
        self.defaultValue = defaultValue
    }
}
