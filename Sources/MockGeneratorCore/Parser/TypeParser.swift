import Foundation
import SwiftSyntax

// Parse from `TypeSyntax`to `TypeDescriptor`

public struct TypeParser {
    
    public init() {}
    
    func parse(_ syntax: TypeSyntax) -> TypeDescriptor {
        
        switch syntax.as(TypeSyntaxEnum.self) {
            
        case .identifierType(let node):
            return parseIdentifier(node)
            
        case .optionalType(let node):
            return .optional(parse(node.wrappedType))
            
        case .implicitlyUnwrappedOptionalType(let node):
            return .implicitlyUnwrappedOptional(parse(node.wrappedType))
            
        case .arrayType(let node):
            return .array(parse(node.element))
            
        case .dictionaryType(let node):
            return .dictionary(key: parse(node.key), value: parse(node.value))
            
        case .tupleType(let node):
            return parseTuple(node)
            
        case .functionType(let node):
            return parseFunction(node)
            
        case .attributedType(let node):
            return parseAttributed(node)
            
        default:
            return .unknown(syntax.description.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    
    //MARK: - Private
    
    private func parseIdentifier(_ node: IdentifierTypeSyntax) -> TypeDescriptor {
        guard let genericArgumentClause = node.genericArgumentClause else {
            return .identifier(IdentifierType(name: node.name.text))
        }

        return .generic(
            GenericType(name: node.name.text,
                        arguments: genericArgumentClause.arguments.map { argument in
                            parse(argument.argument)
                        }))
    }
    
    private func parseTuple(_ node: TupleTypeSyntax) -> TypeDescriptor {
        let elements = node.elements.map { element in
            TupleElement(label: element.firstName?.text, type: parse(element.type))
        }
        return .tuple(elements)
    }
    
    private func parseFunction(_ node: FunctionTypeSyntax) -> TypeDescriptor {
        
        let parameters = node.parameters.map { parameter in
            parse(parameter.type)
        }
        
        let returnType = parse(node.returnClause.type)
        let isAsync = node.effectSpecifiers?.asyncSpecifier != nil
        let isThrows = node.effectSpecifiers?.throwsClause != nil
        
        return .function(FunctionType(parameters: parameters,
                                      returnType: returnType,
                                      isAsync: isAsync,
                                      isThrows: isThrows))
    }
    
    private func parseAttributed(_ node: AttributedTypeSyntax) -> TypeDescriptor {
        let specifiers: [TypeSpecifier] = node.specifiers.compactMap { element in
            guard let simpleSpecifier = element.as(SimpleTypeSpecifierSyntax.self) else {
                return nil
            }
            
            switch simpleSpecifier.specifier.tokenKind { 
            case .keyword(.inout):
                return .inout
            case .keyword(.borrowing):
                return .borrowing
            case .keyword(.consuming):
                return .consuming
            case .keyword(.isolated):
                return .isolated
            default:
                return nil
            }
        }
        
        return .attributed(AttributedType(specifiers: specifiers,
                                          baseType: parse(node.baseType)))
    }
}
