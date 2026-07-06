import Foundation

public struct SwiftParameter: Equatable {
    public let externalName: String?
    public let localName: String
    public let type: SwiftType
    public let isVariadic: Bool
    public let isAutoclosure: Bool
    public let isEscaping: Bool
    public let defaultValue: String?

    public init(externalName: String?,
                localName: String,
                type: SwiftType,
                isVariadic: Bool = false,
                isAutoclosure: Bool = false,
                isEscaping: Bool = false,
                defaultValue: String? = nil) {
        self.externalName = externalName
        self.localName = localName
        self.type = type
        self.isVariadic = isVariadic
        self.isAutoclosure = isAutoclosure
        self.isEscaping = isEscaping
        self.defaultValue = defaultValue
    }
}
