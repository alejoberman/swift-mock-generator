import Foundation
import SwiftSyntax

public final class ProtocolVisitor: SyntaxVisitor {

    private let methodParser: MethodParser
    private let propertyParser: PropertyParser
    
    public init(methodParser: MethodParser, propertyParser: PropertyParser) {
        self.methodParser = methodParser
        self.propertyParser = propertyParser
        super.init(viewMode: .sourceAccurate)
    }

    var protocols: [ProtocolDescriptor] = []
    var imports: [String] = []

    func reset() {
        protocols.removeAll(keepingCapacity: true)
        imports.removeAll(keepingCapacity: true)
    }

    public override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        let members: [MemberDescriptor] = node.memberBlock.members
            .compactMap { member in

                let decl = member.decl

                if let function = decl.as(FunctionDeclSyntax.self) {
                    return .method(methodParser.parse(function))
                }
                
                if let variable = decl.as(VariableDeclSyntax.self) {
                    guard let property = propertyParser.parse(variable) else {
                        return nil
                    }
                    return .property(property)
                }
                // nothing found.
                return nil
            }
        //TODO: Fix missing parameters
        protocols.append(ProtocolDescriptor(
            module: nil,
            name: node.name.text,
            accessLevel: accessLevel(for: node),
            inheritedTypes: node.inheritanceClause?.inheritedTypes.map {
                $0.type.trimmedDescription
            } ?? [],
            members: members,
            imports: imports
        ))
        
        return .skipChildren
    }
    
    private func accessLevel(for node: ProtocolDeclSyntax) -> AccessLevel {
        guard let modifier = node.modifiers.first(where: { modifier in
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.package), .keyword(.private),
                 .keyword(.fileprivate), .keyword(.internal):
                return true
            default:
                return false
            }
        }) else {
            return .internal
        }

        switch modifier.name.tokenKind {
        case .keyword(.public): return .public
        case .keyword(.package): return .package
        case .keyword(.private): return .private
        case .keyword(.fileprivate): return .fileprivate
        case .keyword(.internal): return .internal
        default: return .internal
        }
    }

    //TODO: for now this is only to adds -> classes (still unused)
    public override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
    
    // Imports
    public override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        let module = node.path.map { $0.name.text }.joined(separator: ".")
        if !module.isEmpty && !imports.contains(module) {
            imports.append(module)
        }
        return .skipChildren
    }
}
