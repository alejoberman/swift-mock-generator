import Foundation

public struct SwiftExtension: Equatable {
    public var extendedType: SwiftType
    public var conformances: [SwiftType]
    public var members: [SwiftDeclaration]
}
