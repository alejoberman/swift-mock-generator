import Foundation

/// Transforms semantic protocol information into the generator's mock model.
public final class MockTransformer {

    public init() {}

    public func generate(from protocolDescriptor: ProtocolDescriptor) -> MockDescriptor {
        MockDescriptor(protocolDescriptor: protocolDescriptor,
                       mockName: "Mock\(protocolDescriptor.name)")
    }

    /// Builds the model consumed by `MockToSwiftTransformer`.
    public func makeModel(from descriptor: MockDescriptor) -> MockModel {
        let protocolDescriptor = descriptor.protocolDescriptor

        return makeModel(from: protocolDescriptor, allProtocols: [protocolDescriptor])
    }

    /// Builds a mock model while resolving members inherited from protocols available
    /// in the current source set. Unknown/external protocols remain in the inheritance
    /// clause but cannot contribute members because their declarations are unavailable. !
    public func makeModel(from protocolDescriptor: ProtocolDescriptor,
                          allProtocols: [ProtocolDescriptor]) -> MockModel {
        let resolvedMembers = resolveMembers(for: protocolDescriptor,
                                             allProtocols: allProtocols,
                                             visited: [])
        let overloadedNames = Set(
            Dictionary(grouping: resolvedMembers.compactMap { member -> MethodDescriptor? in
                if case .method(let method) = member { return method }
                return nil
            }, by: \.name)
            .filter { $0.value.count > 1 }
            .keys
        )

        var usedStorageNames = Set<String>()
        let mockMembers = resolvedMembers.map { member -> MockMember in
            switch member {
            case .method(let method):
                var storage = makeStorage(for: method,
                                          disambiguate: overloadedNames.contains(method.name))
                // Also protect against rare sanitization collisions and method/property name collisions.
                if !usedStorageNames.insert(storage.invocationVariable).inserted {
                    storage = makeStorage(for: method, disambiguate: true, forceUnique: true)
                    usedStorageNames.insert(storage.invocationVariable)
                }
                return .method(MockMethod(descriptor: method, storage: storage))
            case .property(let property):
                return .property(MockProperty(descriptor: property))
            }
        }

        return MockModel(className: "Mock\(protocolDescriptor.name)",
                         accessLevel: protocolDescriptor.accessLevel,
                         modifiers: [.final],
                         inheritedTypes: [
                            .identifier(IdentifierType(name: protocolDescriptor.name))
                         ] + protocolDescriptor.inheritedTypes.map {
                             .identifier(IdentifierType(name: $0))
                         },
                         members: mockMembers,
                         imports: protocolDescriptor.imports)
    }

    /// Convenience entry point for the complete semantic → generator-model step.
    public func makeModel(from protocolDescriptor: ProtocolDescriptor) -> MockModel {
        makeModel(from: generate(from: protocolDescriptor))
    }

    private func resolveMembers(for descriptor: ProtocolDescriptor,
                                allProtocols: [ProtocolDescriptor],
                                visited: Set<String>) -> [MemberDescriptor] {
        guard !visited.contains(descriptor.name) else { return [] }
        var nextVisited = visited
        nextVisited.insert(descriptor.name)

        // Keep the child declarations first so a redeclaration shadows an inherited one.
        var members = descriptor.members
        for inheritedType in descriptor.inheritedTypes {
            let inheritedName = inheritedType.split(separator: ".").last.map(String.init) ?? inheritedType
            guard let inherited = allProtocols.first(where: { $0.name == inheritedName }) else { continue }
            members.append(contentsOf: resolveMembers(for: inherited,
                                                      allProtocols: allProtocols,
                                                      visited: nextVisited))
        }

        var seen = Set<String>()
        return members.filter { member in
            let key: String
            switch member {
            case .method(let method): 
                key = "method:\(methodSignature(method))"
            case .property(let property): 
                key = "property:\(property.name)"
            }
            return seen.insert(key).inserted
        }
    }

    private func methodSignature(_ method: MethodDescriptor) -> String {
        let renderer = SwiftTypeRenderer()
        let parameters = method.parameters.map { parameter in
            "\(parameter.externalName ?? "_"):\(renderer.render(parameter.type))\(parameter.isVariadic ? "..." : "")"
        }.joined(separator: ",")
        return "\(method.name)(\(parameters))->\(method.returnType.map(renderer.render) ?? "Void")\(method.isAsync ? " async" : "")\(method.isThrows ? " throws" : "")"
    }

    private func makeStorage(for method: MethodDescriptor,
                             disambiguate: Bool,
                             forceUnique: Bool = false) -> MethodStorage {
        let baseName: String
        if disambiguate || forceUnique {
            let renderer = SwiftTypeRenderer()
            let parameterPart = method.parameters.map { parameter in
                let label = parameter.externalName ?? "unnamed"
                return "\(label)_\(renderer.render(parameter.type))\(parameter.isVariadic ? "_variadic" : "")"
            }.joined(separator: "_")
            let returnPart = method.returnType.map(renderer.render) ?? "Void"
            let signature = "\(method.name)_\(parameterPart)_returns_\(returnPart)\(method.isAsync ? "_async" : "")\(method.isThrows ? "_throws" : "")"
            baseName = sanitizeIdentifier(signature)
        } else {
            baseName = method.name
        }
        let suffix = baseName.prefix(1).uppercased() + baseName.dropFirst()

        return MethodStorage(
            invocationVariable: "_\(baseName)Storage",
            callCountVariable: "_\(baseName)CallCount",
            returnValueVariable: method.returnType == nil ? nil : "_\(baseName)ReturnValue",
            handlerVariable: "_\(suffix)Handler"
        )
    }

    // Keep only ASCII letters, digits, and underscores.
    // Replace every other Unicode scalar with an underscore to ensure
    // the generated identifier uses a predictable character set.
    private func sanitizeIdentifier(_ value: String) -> String {
        let sanitized = value.unicodeScalars.map { scalar -> Character in
            let value = scalar.value
            if (value >= 65 && value <= 90) || (value >= 97 && value <= 122) ||
                (value >= 48 && value <= 57) || value == 95 {
                return Character(String(scalar))
            }
            return "_"
        }
        var result = String(sanitized).replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if result.first?.isNumber == true { result = "m_" + result }
        return result.isEmpty ? "method" : result
    }
}
