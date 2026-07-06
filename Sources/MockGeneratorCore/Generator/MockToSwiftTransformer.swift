import Foundation
import MockGeneratorCodeDOM

public struct MockToSwiftTransformer {
    private let typeTransformer: TypeTransformer

    public init(typeTransformer: TypeTransformer = TypeTransformer()) {
        self.typeTransformer = typeTransformer
    }

    public func transform(_ model: MockModel) -> SwiftFile {
        SwiftFile(imports: makeImports(from: model.imports),
                  declarations: [.type(transformNominalType(model))])
    }

    private func makeImports(from modules: [String]) -> [SwiftImport] {
        var seen = Set<String>()
        return (modules + ["MockRuntime"]).compactMap { module in
            guard seen.insert(module).inserted else { return nil }
            return SwiftImport(module: module)
        }
    }

    private func transformNominalType(_ model: MockModel) -> SwiftNominalType {
        SwiftNominalType(
            kind: .class,
            name: model.className,
            modifiers: transformModifiers(model.accessLevel, model.modifiers),
            inheritedTypes: transformInheritedTypes(model.inheritedTypes),
            members: model.members.flatMap { transformMember($0, accessLevel: model.accessLevel) }
        )
    }

    private func transformMember(_ member: MockMember, accessLevel: AccessLevel) -> [SwiftDeclaration] {
        switch member {
        case .method(let method):
            return transformMethod(method, accessLevel: accessLevel)
        case .property(let property):
            return transformProperty(property, accessLevel: accessLevel)
        case .variable(let variable):
            return [.variable(transformVariable(variable))]
        }
    }

    private func transformMethod(_ mockMethod: MockMethod, accessLevel: AccessLevel) -> [SwiftDeclaration] {
        let descriptor = mockMethod.descriptor
        let invocationType = makeInvocationType(for: descriptor.parameters)
        let returnType = swiftTypeOrNil(descriptor.returnType) ?? .identifier("Void")
        let storageType = SwiftType.generic(SwiftGenericType(
            name: "MockMethodStorage",
            arguments: [invocationType, returnType]
        ))

        let storage = SwiftVariable(modifiers: [.private],
                                    isMutable: true,
                                    name: mockMethod.storage.invocationVariable,
                                    type: storageType,
                                    initializer: .raw("MockMethodStorage()"))

        let invocation = makeInvocationExpression(descriptor.parameters)
        let recordInvocation = SwiftExpression.raw(
            "MockRuntime.recordInvocation(owner: self, method: \"\(descriptor.name)\", storage: \(mockMethod.storage.invocationVariable))"
        )
        let invocationExpression = SwiftExpression.raw(
            "\(mockMethod.storage.invocationVariable).\(invocationMethodName(for: descriptor))(\(emitExpression(invocation)), arguments: \(makeArgumentArrayExpression(descriptor.parameters)), callArguments: \(makeCallArgumentArrayExpression(descriptor.parameters)))"
        )

        let resultExpression: SwiftExpression
        if descriptor.isThrows || descriptor.isAsync {
            resultExpression = .raw(
                invocationPrefix(for: descriptor) + emitExpression(invocationExpression)
            )
        } else {
            resultExpression = invocationExpression
        }

        let body: [SwiftStatement]
        let recordStatement = SwiftStatement.expression(recordInvocation)
        if descriptor.returnType == nil {
            body = [recordStatement, .expression(resultExpression)]
        } else {
            body = [recordStatement, .return(resultExpression)]
        }

        let method = SwiftMethod(
            modifiers: [transformAccessLevel(accessLevel)],
            name: descriptor.name,
            parameters: transformParameters(descriptor.parameters),
            returnType: swiftTypeOrNil(descriptor.returnType),
            isAsync: descriptor.isAsync,
            isThrows: descriptor.isThrows,
            body: body
        )

        let configurationMethod = SwiftMethod(
            modifiers: [transformAccessLevel(accessLevel)],
            name: descriptor.name,
            parameters: transformConfigurationParameters(
                descriptor.parameters,
                isAsync: descriptor.isAsync
            ),
            returnType: .generic(SwiftGenericType(
                name: "Mockable",
                arguments: [returnType]
            )),
            isAsync: descriptor.isAsync,
            isThrows: descriptor.isThrows,
            body: [
                .return(.raw(
                    "MockRuntime.invocation(owner: self, method: \"\(descriptor.name)\", storage: \(mockMethod.storage.invocationVariable), arguments: \(makeArgumentArrayExpression(descriptor.parameters)))"
                ))
            ]
        )
        
        if descriptor.parameters.count > 0 {
            
            let matcherConfigurationMethod = SwiftMethod(
                modifiers: [transformAccessLevel(accessLevel)],
                name: descriptor.name,
                parameters: transformMatcherConfigurationParameters(
                    descriptor.parameters
                ),
                returnType: .generic(SwiftGenericType(
                    name: "Mockable",
                    arguments: [returnType]
                )),
                isAsync: descriptor.isAsync,
                isThrows: descriptor.isThrows,
                body: [
                    .return(.raw(
                        "MockRuntime.invocation(owner: self, method: \"\(descriptor.name)\", storage: \(mockMethod.storage.invocationVariable), arguments: \(makeArgumentArrayExpression(descriptor.parameters)))"
                    ))
                ]
            )
            return [
                .variable(storage),
                .method(method),
                .method(configurationMethod),
                .method(matcherConfigurationMethod)
            ]
        }

        return [
            .variable(storage),
            .method(method),
            .method(configurationMethod),
        ]
    }

    /// Arguments used for matching exclude closure parameters because closure identity
    /// is not a meaningful equality criterion.
    private func makeArgumentArrayExpression(_ parameters: [ParameterDescriptor]) -> String {
        let arguments = parameters
            .filter { !containsFunction($0.type) }
            .map { $0.localName }
            .joined(separator: ", ")
        return "[\(arguments)]"
    }

    /// Full arguments are retained for configured answers, which may need to invoke
    /// completion handlers supplied to the mock method.
    private func makeCallArgumentArrayExpression(_ parameters: [ParameterDescriptor]) -> String {
        let capturable = parameters.filter { !containsFunction($0.type) || $0.isEscaping }
        return "[\(capturable.map(\.localName).joined(separator: ", "))]"
    }

    private func invocationMethodName(for descriptor: MethodDescriptor) -> String {
        switch (descriptor.isAsync, descriptor.isThrows) {
        case (true, true): return "invokeAsyncThrowing"
        case (true, false): return "invokeAsync"
        case (false, true): return "invokeThrowing"
        case (false, false): return "invoke"
        }
    }

    private func invocationPrefix(for descriptor: MethodDescriptor) -> String {
        switch (descriptor.isAsync, descriptor.isThrows) {
        case (true, true): return "try await "
        case (true, false): return "await "
        case (false, true): return "try "
        case (false, false): return ""
        }
    }

    private func emitExpression(_ expression: SwiftExpression) -> String {
        switch expression {
        case .identifier(let value):
            return value
        case .raw(let value):
            return value
        case .member(let base, let name): 
            return "\(emitExpression(base)).\(name)"
        case .call(let call):
            let arguments = call.arguments.map { argument in
                let label = argument.label.map { "\($0): " } ?? ""
                return label + emitExpression(argument.expression)
            }.joined(separator: ", ")
            return "\(emitExpression(call.callee))(\(arguments))"
        case .assignment(let left, let right):
            return "\(emitExpression(left)) = \(emitExpression(right))"
        case .literal(let literal):
            switch literal {
            case .string(let value): 
                return "\"\(value)\""
            case .integer(let value):
                return String(value)
            case .floatingPoint(let value):
                return String(value)
            case .boolean(let value): 
                return value ? "true" : "false"
            case .nil: 
                return "nil"
            }
        case .closure:
            return "{ ... }"
        }
    }

    private func transformProperty(_ property: MockProperty, accessLevel: AccessLevel) -> [SwiftDeclaration] {
        let descriptor = property.descriptor
        let storageName = "_\(descriptor.name)Storage"
        let valueType = typeTransformer.transform(descriptor.type)
        let storageType = SwiftType.generic(SwiftGenericType(
            name: "MockPropertyStorage",
            arguments: [valueType]
        ))

        let storage = SwiftVariable(
            modifiers: [.private],
            isMutable: true,
            name: storageName,
            type: storageType,
            initializer: .raw("MockPropertyStorage()")
        )
        
        // The companion handle lets tests configure a property with a given stub value
        var stubReference: SwiftProperty?
        if case .optional(_) = valueType {
            // nothig
        } else {
            let stubName = "\(descriptor.name)Stub"
            stubReference = SwiftProperty(
                modifiers: [transformAccessLevel(accessLevel)],
                isMutable: true,
                name: stubName,
                type: .optional(valueType)
            )
        }
        var getterArguements: [SwiftArgument] = []
        if let stubReference {
            getterArguements = [.init(label: nil, expression: .identifier(stubReference.name))]
        }

        let getter: [SwiftStatement] = descriptor.getter == nil ? [] : [
            .expression(.raw(
                "MockRuntime.recordPropertyAccess(owner: self, method: \"\(descriptor.name)\", storage: \(storageName))"
            )),
            .return(SwiftExpression.call(SwiftCallExpression(
                callee: .member(base: .identifier(storageName), name: "get"),
                arguments: getterArguements
            )))
        ]

        let setter: [SwiftStatement]?
        if descriptor.setter != nil {
            setter = [
                .expression(SwiftExpression.call(SwiftCallExpression(
                    callee: .member(base: .identifier(storageName), name: "set"),
                    arguments: [SwiftArgument(label: nil, expression: .identifier("newValue"))]
                )))
            ]
        } else {
            setter = nil
        }

        let swiftProperty = SwiftProperty(
            modifiers: [transformAccessLevel(accessLevel)],
            isMutable: true,
            name: descriptor.name,
            type: valueType,
            getter: getter,
            setter: setter
        )
        var property: [SwiftDeclaration] = [.variable(storage), .property(swiftProperty)]
        if let stubReference {
            property.append(.property(stubReference))
        }
        return property
    }

    private func transformVariable(_ variable: MockVariable) -> SwiftVariable {
        SwiftVariable(
            modifiers: [transformAccessLevel(variable.accessLevel)] + variable.modifiers.compactMap(transformModifier),
            isMutable: variable.isMutable,
            name: variable.name,
            type: swiftTypeOrNil(variable.type),
            initializer: variable.initializer.map(SwiftExpression.raw)
        )
    }

    private func transformParameters(_ parameters: [ParameterDescriptor]) -> [SwiftParameter] {
        parameters.map {
            SwiftParameter(
                externalName: $0.externalName,
                localName: $0.localName,
                type: typeTransformer.transform($0.type),
                isVariadic: $0.isVariadic,
                isEscaping: $0.isEscaping
            )
        }
    }

    private func transformConfigurationParameters(
        _ parameters: [ParameterDescriptor],
        isAsync: Bool
    ) -> [SwiftParameter] {
        var result = parameters.map { parameter in
            let isInout = containsInout(parameter.type)
            let parameterType: SwiftType

            if parameter.isVariadic {
                parameterType = .array(typeTransformer.transform(parameter.type))
            } else {
                parameterType = typeTransformer.transform(parameter.type)
            }

            return SwiftParameter(
                externalName: parameter.externalName,
                localName: parameter.localName,
                type: parameterType,
                isVariadic: false,
                isAutoclosure: !isInout && !isAsync && !containsFunction(parameter.type)
            )
        }

        result.append(
            SwiftParameter(
                externalName: "_",
                localName: "__mocking",
                type: .identifier("Bool"),
                defaultValue: "true"
            )
        )
        return result
    }

    private func transformMatcherConfigurationParameters(_ parameters: [ParameterDescriptor]
    ) -> [SwiftParameter] {
        var result = parameters.map { parameter in
            SwiftParameter(externalName: parameter.externalName,
                           localName: parameter.localName,
                           type: .identifier("Any"),
                           isVariadic: false,
                           isAutoclosure: false)
        }

        result.append(SwiftParameter(externalName: "_",
                                     localName: "__mocking",
                                     type: .identifier("Bool"),
                                     defaultValue: "true"))
        return result
    }

    private func containsInout(_ type: TypeDescriptor) -> Bool {
        switch type {
        case .attributed(let attributed):
            return attributed.specifiers.contains(.inout) || containsInout(attributed.baseType)
        case .optional(let wrapped),
             .implicitlyUnwrappedOptional(let wrapped),
             .array(let wrapped),
             .metatype(let wrapped):
            return containsInout(wrapped)
        case .dictionary(let key, let value):
            return containsInout(key) || containsInout(value)
        case .tuple(let elements):
            return elements.contains { containsInout($0.type) }
        case .function(let function):
            return function.parameters.contains { containsInout($0) }
                || containsInout(function.returnType)
        case .composition(let types):
            return types.contains(where: containsInout)
        case .generic(let generic):
            return generic.arguments.contains(where: containsInout)
        case .identifier, .unknown:
            return false
        }
    }

    private func makeInvocationType(for parameters: [ParameterDescriptor]) -> SwiftType {
        let storableParameters = parameters.filter { !containsFunction($0.type) || $0.isEscaping }

        switch storableParameters.count {
        case 0:
            return .identifier("Void")
        case 1:
            return invocationType(storableParameters[0])
        default:
            return .tuple(storableParameters.map {
                SwiftTupleElement(label: nil, type: invocationType($0))
            })
        }
    }

    private func invocationType(_ parameter: ParameterDescriptor) -> SwiftType {
        let baseType = invocationType(parameter.type)
        return parameter.isVariadic ? .array(baseType) : baseType
    }

    private func containsFunction(_ type: TypeDescriptor) -> Bool {
        switch type {
        case .function:
            return true
        case .attributed(let attributed):
            return containsFunction(attributed.baseType)
        case .optional(let wrapped), .implicitlyUnwrappedOptional(let wrapped), .array(let wrapped), .metatype(let wrapped):
            return containsFunction(wrapped)
        case .dictionary(let key, let value):
            return containsFunction(key) || containsFunction(value)
        case .tuple(let elements):
            return elements.contains { containsFunction($0.type) }
        case .composition(let types):
            return types.contains(where: containsFunction)
        case .generic(let generic):
            return generic.arguments.contains(where: containsFunction)
        case .identifier, .unknown:
            return false
        }
    }

    private func containsNonEscapingFunction(_ type: TypeDescriptor) -> Bool {
        switch type {
        case .function:
            return true
        case .optional(let wrapped),
             .implicitlyUnwrappedOptional(let wrapped),
             .array(let wrapped),
             .metatype(let wrapped):
            return containsNonEscapingFunction(wrapped)
        case .attributed(let attributed):
                return containsNonEscapingFunction(attributed.baseType)
        case .dictionary(let key, let value):
            return containsNonEscapingFunction(key) || containsNonEscapingFunction(value)
        case .tuple(let elements):
            return elements.contains { containsNonEscapingFunction($0.type) }
        case .composition(let types):
            return types.contains(where: containsNonEscapingFunction)
        case .generic(let generic):
            return generic.arguments.contains(where: containsNonEscapingFunction)
        case .identifier, .unknown:
            return false
        }
    }

    private func invocationType(_ type: TypeDescriptor) -> SwiftType {
        switch type {
        case .attributed(let attributed):
            return invocationType(attributed.baseType)
        default:
            return typeTransformer.transform(type)
        }
    }

    private func makeInvocationExpression(_ parameters: [ParameterDescriptor]) -> SwiftExpression {
        let storableParameters = parameters.filter { !containsFunction($0.type) || $0.isEscaping }

        switch storableParameters.count {
        case 0:
            return .raw("()")
        case 1:
            return .identifier(storableParameters[0].localName)
        default:
            return .raw("(\(storableParameters.map(\.localName).joined(separator: ", ")))" )
        }
    }

    private func swiftTypeOrNil(_ type: TypeDescriptor?) -> SwiftType? {
        type.map(typeTransformer.transform)
    }

    private func transformInheritedTypes(_ inheritedTypes: [TypeDescriptor]) -> [SwiftType] {
        inheritedTypes.map { type in
            switch type {
            case .identifier(let identifier) where identifier.name == "Sendable":
                return .attributed(SwiftAttributedType(specifiers: [.unchecked],
                                                       baseType: .identifier("Sendable")))
            default:
                return typeTransformer.transform(type)
            }
        }
    }

    private func transformModifiers(_ accessLevel: AccessLevel, _ modifiers: [MockModifier]) -> [SwiftModifier] {
        [transformAccessLevel(accessLevel)] + modifiers.map(transformModifier)
    }

    private func transformAccessLevel(_ accessLevel: AccessLevel) -> SwiftModifier {
        switch accessLevel {
        case .public:
            return .public
        case .package:
            return .package
        case .internal:
            return .internal
        case .fileprivate:
            return .fileprivate
        case .private:
            return .private
        }
    }

    private func transformModifier(_ modifier: MockModifier) -> SwiftModifier {
        switch modifier {
        case .public:
            return .public
        case .private:
            return .private
        case .fileprivate:
            return .fileprivate
        case .internal:
            return .internal
        case .open:
            return .open
        case .final:
            return .final
        case .static:
            return .static
        case .override:
            return .override
        case .privateSet:
            return .privateSet
        }
    }

    private func transformModifier(_ modifier: MockVariableModifier) -> SwiftModifier? {
        switch modifier {
        case .static:
            return .static
        case .lazy:
            return .lazy
        case .weak:
            return .weak
        case .unowned:
            return .unowned
        }
    }
}
