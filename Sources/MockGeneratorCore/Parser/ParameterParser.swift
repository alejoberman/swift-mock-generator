import Foundation
import SwiftSyntax

public struct ParameterParser {
    private let typeParser: TypeParser
    
    public init(typeParser: TypeParser) {
        self.typeParser = typeParser
    }

    func parse(_ parameter: FunctionParameterSyntax) -> ParameterDescriptor {

        let firstName = parameter.firstName.text
        let externalName = firstName == "_" ? nil : firstName
        let localName = parameter.secondName?.text ?? firstName

        return ParameterDescriptor(
            externalName: externalName,
            localName: localName,
            type: typeParser.parse(parameter.type),
            isVariadic: parameter.ellipsis != nil,
            isEscaping: parameter.type.description.contains("@escaping"),
            defaultValue: parameter.defaultValue?.value.description)
    }
}
