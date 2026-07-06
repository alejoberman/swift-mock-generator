import Foundation
import SwiftSyntax

public struct PropertyParser {
    private let typeParser: TypeParser
    
    public init(typeParser: TypeParser) {
        self.typeParser = typeParser
    }
    
    func parse(_ variable: VariableDeclSyntax) -> PropertyDescriptor? {

        guard let binding = variable.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation else { return nil }
        
        return PropertyDescriptor(name: identifier.identifier.text,
                                  type: typeParser.parse(typeAnnotation.type),
                                  getter: parseGetter(binding.accessorBlock),
                                  setter: parseSetter(binding.accessorBlock))
    }
    
    //MARK: - Private
    
    private func parseGetter(_ accessorBlock: AccessorBlockSyntax?) -> AccessorDescriptor? {
        guard let accessorBlock,
              case .accessors(let accessors) = accessorBlock.accessors else { return nil }

        guard accessors.contains(where: { $0.accessorSpecifier.text == "get" }) else {
            return nil
        }

        return AccessorDescriptor(isAsync: false, isThrows: false)
    }
    
    private func parseSetter(_ accessorBlock: AccessorBlockSyntax?) -> AccessorDescriptor? {
        guard let accessorBlock,
              case .accessors(let accessors) = accessorBlock.accessors else { return nil }

        guard accessors.contains(where: { $0.accessorSpecifier.text == "set" }) else {
            return nil
        }

        return AccessorDescriptor(isAsync: false, isThrows: false)
    }
}
