import Foundation

public enum SwiftDeclaration: Equatable {
    case type(SwiftNominalType)
    case `extension`(SwiftExtension)
    case method(SwiftMethod)
    case property(SwiftProperty)
    case variable(SwiftVariable)
    // TODO: future
    // case protocol(SwiftProtocol)
    // case typealias(SwiftTypeAlias)
}
