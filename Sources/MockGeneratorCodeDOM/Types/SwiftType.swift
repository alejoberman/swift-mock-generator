import Foundation

/// Generated Swift representation
public indirect enum SwiftType: Equatable {
    case identifier(String)
    case optional(SwiftType)
    case implicitlyUnwrappedOptional(SwiftType)
    case array(SwiftType)
    case dictionary(key: SwiftType, value: SwiftType)
    case tuple([SwiftTupleElement])
    case function(SwiftFunctionType)
    case composition([SwiftType])
    case attributed(SwiftAttributedType)
    case generic(SwiftGenericType)
    case metatype(SwiftType)
    case unknown(String)
}

public struct SwiftTupleElement: Equatable {
    public let label: String?
    public let type: SwiftType
    
    public init(label: String?, type: SwiftType) {
        self.label = label
        self.type = type
    }
}

public struct SwiftFunctionType: Equatable {
    public let parameters: [SwiftType]
    public let returnType: SwiftType
    public let isAsync: Bool
    public let isThrows: Bool
    
    public init(parameters: [SwiftType],
                returnType: SwiftType,
                isAsync: Bool = false,
                isThrows: Bool = false) {
        self.parameters = parameters
        self.returnType = returnType
        self.isAsync = isAsync
        self.isThrows = isThrows
    }
}

public struct SwiftAttributedType: Equatable {
    public let specifiers: [SwiftTypeSpecifier]
    public let baseType: SwiftType
    
    public init(specifiers: [SwiftTypeSpecifier], baseType: SwiftType) {
        self.specifiers = specifiers
        self.baseType = baseType
    }
}

public enum SwiftTypeSpecifier: Equatable {
    case `inout`
    case consuming
    case borrowing
    case isolated
    case unchecked
}

public struct SwiftGenericType: Equatable {
    public let name: String
    public let arguments: [SwiftType]
    
    public init(name: String, arguments: [SwiftType]) {
        self.name = name
        self.arguments = arguments
    }
}
