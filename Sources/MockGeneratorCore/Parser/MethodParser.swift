import Foundation
import SwiftSyntax

public struct MethodParser {
    private let typeParser: TypeParser
    private let parameterParser: ParameterParser
    
    public init(typeParser: TypeParser, parameterParser: ParameterParser) {
        self.typeParser = typeParser
        self.parameterParser = parameterParser
    }

    func parse(_ function: FunctionDeclSyntax) -> MethodDescriptor {

        let signature = function.signature
        let parameters = signature.parameterClause.parameters.map { parameterParser.parse($0) }
        let returnType = signature.returnClause.map { typeParser.parse($0.type) }
        let isAsync = signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrows = signature.effectSpecifiers?.throwsClause != nil

        return MethodDescriptor(name: function.name.text,
                                parameters: parameters,
                                returnType: returnType,
                                isAsync: isAsync,
                                isThrows: isThrows,
                                isRethrows: false) //TODO: fix rethrows
    }
}
