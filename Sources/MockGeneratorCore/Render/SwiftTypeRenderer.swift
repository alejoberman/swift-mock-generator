import Foundation

public struct SwiftTypeRenderer {

    public init() {}

    public func render(_ type: TypeDescriptor) -> String {

        switch type {

        case .identifier(let identifier):
            return identifier.name

        case .optional(let wrapped):
            return "\(render(wrapped))?"

        case .implicitlyUnwrappedOptional(let wrapped):
            return "\(render(wrapped))!"

        case .array(let element):
            return "[\(render(element))]"

        case .dictionary(let key, let value):
            return "[\(render(key)): \(render(value))]"

        case .tuple(let elements):
            return renderTuple(elements)

        case .function(let function):
            return renderFunction(function)

        case .attributed(let attributed):
            return renderAttributed(attributed)

        case .generic(let generic):
            return renderGeneric(generic)

        case .composition(let types):
            return types
                .map(render)
                .joined(separator: " & ")

        case .metatype(let base):
            return "\(render(base)).Type"

        case .unknown(let text):
            return text
        }
    }
}

private extension SwiftTypeRenderer {

    func renderTuple(_ elements: [TupleElement]) -> String {

        let rendered = elements.map { element in

            if let label = element.label {
                return "\(label): \(render(element.type))"
            }

            return render(element.type)
        }

        return "(\(rendered.joined(separator: ", ")))"
    }

    func renderFunction(_ function: FunctionType) -> String {
        let parameters = function.parameters
            .map(render)
            .joined(separator: ", ")
        
        var signature = "(\(parameters))"

        if function.isAsync {
            signature += " async"
        }
        if function.isThrows {
            signature += " throws"
        }
        signature += " -> \(render(function.returnType))"

        return signature
    }

    func renderAttributed(_ attributed: AttributedType) -> String {
        let specifiers =
            attributed.specifiers
                .map {
                    switch $0 {
                    case .inout:
                        return "inout"
                    case .borrowing:
                        return "borrowing"
                    case .consuming:
                        return "consuming"
                    case .isolated:
                        return "isolated"
                    }
                }
                .joined(separator: " ")
        if specifiers.isEmpty {
            return render(attributed.baseType)
        }
        return "\(specifiers) \(render(attributed.baseType))"
    }

    func renderGeneric(_ generic: GenericType) -> String {
        let arguments = generic.arguments
            .map(render)
            .joined(separator: ", ")
        return "\(generic.name)<\(arguments)>"
    }
}
