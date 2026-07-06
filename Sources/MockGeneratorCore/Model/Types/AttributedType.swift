import Foundation

// TODO: check if needs attributes (@Sendable, @escaping) separately.

public struct AttributedType: Equatable {
    public let specifiers: [TypeSpecifier]
    public let baseType: TypeDescriptor
}
