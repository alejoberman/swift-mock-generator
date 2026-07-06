import Foundation
import MockGeneratorCodeDOM

public struct TypeTransformer {

    public init() {}
    
    public func transform(_ type: TypeDescriptor) -> SwiftType {
        switch type {
        case .identifier(let identifier):
            return .identifier(identifier.name)
        case .optional(let type):
            return SwiftType.optional(transform(type))
        case .implicitlyUnwrappedOptional(let type):
            return .implicitlyUnwrappedOptional(transform(type))
        case .array(let type):
            return .array(transform(type))
        case .dictionary(key: let key, value: let value):
            return .dictionary(key: transform(key), value: transform(value))
        case .tuple(let tuple):
            return .tuple(tuple.map(transformTuple))
        case .function(let function):
            return .function(transformFunctionType(function))
        case .composition(let types):
            return .composition(types.map(transform))
        case .attributed(let attributed):
            return .attributed(transformAttributedType(attributed))
        case .generic(let generic):
            return .generic(SwiftGenericType(name: generic.name,
                                             arguments: generic.arguments.map(transform)))
        case .metatype(let meta):
            return .metatype(transform(meta))
        case .unknown(let name):
            return .unknown(name)
        }
    }
}

extension TypeTransformer { //Function
    func transformFunctionType(_ functionType: FunctionType) -> SwiftFunctionType {
        SwiftFunctionType(parameters: functionType.parameters.map(transform),
                          returnType: transform(functionType.returnType),
                          isAsync: functionType.isAsync,
                          isThrows: functionType.isThrows)
    }
}

extension TypeTransformer { //Tuple
    func transformTuple(_ tuple: TupleElement) -> SwiftTupleElement {
        SwiftTupleElement(label: tuple.label,
                          type: transform(tuple.type))
    }
}

extension TypeTransformer { //Attributed
    func transformAttributedType(_ attributed: AttributedType) -> SwiftAttributedType {
        return SwiftAttributedType(specifiers: attributed.specifiers.map(swiftAttributedTypeSpecifier),
                                   baseType: transform(attributed.baseType))
    }
    
    func swiftAttributedTypeSpecifier(_ typeSpecifier: TypeSpecifier) -> SwiftTypeSpecifier {
        switch typeSpecifier {
        case .inout:
            return .inout
        case .consuming:
            return.consuming
        case .borrowing:
            return .borrowing
        case .isolated:
            return .isolated
        }
    }
}
