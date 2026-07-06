import Foundation

public indirect enum TypeDescriptor: Equatable {

    case identifier(IdentifierType)

    case optional(TypeDescriptor)

    case implicitlyUnwrappedOptional(TypeDescriptor)

    case array(TypeDescriptor)

    case dictionary(key: TypeDescriptor, value: TypeDescriptor)

    case tuple([TupleElement])

    case function(FunctionType)

    case composition([TypeDescriptor])

    case attributed(AttributedType)

    case generic(GenericType)

    case metatype(TypeDescriptor)

    case unknown(String)
}
