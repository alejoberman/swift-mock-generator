import Foundation
import MockGeneratorCodeDOM

public struct SwiftEmitter {
    public init() {}

    public func emit(_ file: SwiftFile) -> String {
        let writer = SwiftWriter()
        emit(file, into: writer)
        return writer.output
    }

    private func emit(_ file: SwiftFile, into writer: SwiftWriter) {
        for (index, imp) in file.imports.enumerated() {
            emit(imp, into: writer)
            if index == file.imports.count - 1 && !file.declarations.isEmpty { writer.newline() }
        }
        for (index, declaration) in file.declarations.enumerated() {
            emit(declaration, into: writer)
            if index < file.declarations.count - 1 { writer.newline() }
        }
    }

    private func emit(_ imp: SwiftImport, into writer: SwiftWriter) {
        writer.write("import \(imp.module)")
        writer.newline()
    }

    private func emit(_ declaration: SwiftDeclaration, into writer: SwiftWriter) {
        switch declaration {
        case .type(let type):
            emit(type, into: writer)
        case .extension(let ext):
            emit(ext, into: writer)
        case .method(let method):
            emit(method, into: writer)
        case .property(let property):
            emit(property, into: writer)
        case .variable(let variable):
            emit(variable, into: writer)
        }
    }

    private func emit(_ type: SwiftNominalType, into writer: SwiftWriter) {
        emitModifiers(type.modifiers, into: writer)
        writer.write(keyword(for: type.kind))
        writer.space()
        writer.write(type.name)
        emitInheritedTypes(type.inheritedTypes, into: writer)
        writer.space()
        writer.openBrace()
        writer.newline()
        writer.indent()
        for (index, member) in type.members.enumerated() {
            emit(member, into: writer)
            if index < type.members.count - 1 { writer.newline() }
        }
        writer.outdent()
        writer.newline()
        writer.closeBrace()
        writer.newline()
    }

    private func emit(_ ext: SwiftExtension, into writer: SwiftWriter) {
        writer.write("extension ")
        emit(ext.extendedType, into: writer, inline: true)
        if !ext.conformances.isEmpty {
            emitInheritedTypes(ext.conformances, into: writer)
        }
        writer.space()
        writer.openBrace()
        writer.newline()
        writer.indent()
        for (index, member) in ext.members.enumerated() {
            emit(member, into: writer)
            if index < ext.members.count - 1 { writer.newline() }
        }
        writer.outdent()
        writer.newline()
        writer.closeBrace()
        writer.newline()
    }

    private func emit(_ method: SwiftMethod, into writer: SwiftWriter) {
        emitModifiers(method.modifiers, into: writer)
        writer.write("func ")
        writer.write(method.name)
        writer.openParen()
        for (index, parameter) in method.parameters.enumerated() {
            if index > 0 { writer.write(", ") }
            emit(parameter, into: writer)
        }
        writer.closeParen()
        if method.isAsync { writer.write(" async") }
        if method.isThrows { writer.write(" throws") }
        if let returnType = method.returnType {
            writer.write(" -> ")
            emit(returnType, into: writer, inline: true)
        }
        writer.space()
        writer.openBrace()
        writer.newline()
        writer.indent()
        for (index, statement) in method.body.enumerated() {
            emit(statement, into: writer)
            if index < method.body.count - 1 { writer.newline() }
        }
        writer.outdent()
        writer.newline()
        writer.closeBrace()
        writer.newline()
    }

    private func emit(_ property: SwiftProperty, into writer: SwiftWriter) {
        emitModifiers(property.modifiers, into: writer)
        writer.write(property.isMutable ? "var " : "let ")
        writer.write(property.name)
        writer.write(": ")
        emit(property.type, into: writer, inline: true)
        if property.getter.isEmpty && property.setter == nil {
            writer.newline()
            return
        }
        writer.space()
        writer.openBrace()
        writer.newline()
        writer.indent()
        if !property.getter.isEmpty {
            writer.write("get")
            writer.space()
            writer.openBrace()
            writer.newline()
            writer.indent()
            emitStatements(property.getter, into: writer)
            writer.outdent()
            writer.newline()
            writer.closeBrace()
        }
        if let setter = property.setter {
            if !property.getter.isEmpty { writer.newline() }
            writer.write("set")
            writer.space()
            writer.openBrace()
            writer.newline()
            writer.indent()
            emitStatements(setter, into: writer)
            writer.outdent()
            writer.newline()
            writer.closeBrace()
        }
        writer.outdent()
        writer.newline()
        writer.closeBrace()
        writer.newline()
    }

    private func emit(_ variable: SwiftVariable, into writer: SwiftWriter) {
        emitModifiers(variable.modifiers, into: writer)
        writer.write(variable.isMutable ? "var " : "let ")
        writer.write(variable.name)
        if let type = variable.type {
            writer.write(": ")
            emit(type, into: writer, inline: true)
        }
        if let initializer = variable.initializer {
            writer.write(" = ")
            emit(initializer, into: writer, inline: true)
        }
        writer.newline()
    }

    private func emit(_ parameter: SwiftParameter, into writer: SwiftWriter) {
        if let external = parameter.externalName {
            writer.write(external)
            if external != parameter.localName {
                writer.write(" ")
                writer.write(parameter.localName)
            }
        } else {
            writer.write("_")
            writer.write(" ")
            writer.write(parameter.localName)
        }
        writer.write(": ")
        if parameter.isAutoclosure {
            writer.write("@escaping @autoclosure () -> ")
            emit(parameter.type, into: writer, inline: true)
        } else {
            if parameter.isEscaping { writer.write("@escaping ") }
            emit(parameter.type, into: writer, inline: true)
            if parameter.isVariadic { writer.write("...") }
        }
        if let defaultValue = parameter.defaultValue {
            writer.write(" = ")
            writer.write(defaultValue)
        }
    }

    private func emit(_ statement: SwiftStatement, into writer: SwiftWriter) {
        switch statement {
        case .expression(let expression):
            emit(expression, into: writer, inline: true)
            writer.newline()
        case .variable(let variable):
            emit(variable, into: writer)
        case .return(let expression):
            writer.write("return ")
            emit(expression, into: writer, inline: true)
            writer.newline()
        case .ifStatement(let statement):
            emit(statement, into: writer)
        }
    }

    private func emitStatements(_ statements: [SwiftStatement], into writer: SwiftWriter) {
        for (index, statement) in statements.enumerated() {
            emit(statement, into: writer)
            if index < statements.count - 1 && !writer.output.hasSuffix("\n") {
                writer.newline()
            }
        }
    }

    private func emit(_ statement: SwiftIfStatement, into writer: SwiftWriter) {
        writer.write("if ")
        emit(statement.condition, into: writer, inline: true)
        writer.space()
        writer.openBrace()
        writer.newline()
        writer.indent()
        emitStatements(statement.body, into: writer)
        writer.outdent()
        writer.newline()
        writer.closeBrace()
        if !statement.elseBody.isEmpty {
            writer.write(" else {")
            writer.newline()
            writer.indent()
            emitStatements(statement.elseBody, into: writer)
            writer.outdent()
            writer.newline()
            writer.closeBrace()
        }
        writer.newline()
    }

    private func emit(_ expression: SwiftExpression, into writer: SwiftWriter, inline: Bool) {
        switch expression {
        case .identifier(let value):
            writer.write(value)
        case .raw(let value):
            writer.write(value)
        case .member(let base, let name):
            emit(base, into: writer, inline: true)
            writer.write(".")
            writer.write(name)
        case .assignment(let left, let right):
            emit(left, into: writer, inline: true)
            writer.write(" = ")
            emit(right, into: writer, inline: true)
        case .literal(let literal):
            emit(literal, into: writer)
        case .call(let call):
            emit(call, into: writer)
        case .closure(let closure):
            emit(closure, into: writer)
        }
    }

    private func emit(_ call: SwiftCallExpression, into writer: SwiftWriter) {
        emit(call.callee, into: writer, inline: true)
        writer.openParen()
        for (index, argument) in call.arguments.enumerated() {
            if index > 0 { writer.write(", ") }
            if let label = argument.label {
                writer.write(label)
                writer.write(": ")
            }
            emit(argument.expression, into: writer, inline: true)
        }
        writer.closeParen()
    }

    private func emit(_ closure: SwiftClosureExpression, into writer: SwiftWriter) {
        writer.openBrace()
        if !closure.parameters.isEmpty {
            writer.write(" \(closure.parameters.joined(separator: ", ")) in")
        }
        if !closure.body.isEmpty {
            writer.newline()
            writer.indent()
            emitStatements(closure.body, into: writer)
            writer.outdent()
            writer.closeBrace()
        } else {
            writer.write(" }")
        }
    }

    private func emit(_ literal: SwiftLiteral, into writer: SwiftWriter) {
        switch literal {
        case .string(let value):
            writer.write("\"\(escape(value))\"")
        case .integer(let value):
            writer.write(String(value))
        case .floatingPoint(let value):
            writer.write(String(value))
        case .boolean(let value):
            writer.write(value ? "true" : "false")
        case .nil:
            writer.write("nil")
        }
    }

    private func emit(_ type: SwiftType, into writer: SwiftWriter, inline: Bool) {
        switch type {
        case .identifier(let value): writer.write(value)
        case .optional(let value):
            if case .function(_) = value {
                writer.write("(")
            }
            emit(value, into: writer, inline: true)
            if case .function(_) = value {
                writer.write(")")
            }
            writer.write("?")
        case .implicitlyUnwrappedOptional(let value):
            emit(value, into: writer, inline: true)
            writer.write("!")
        case .array(let value):
            writer.write("[")
            emit(value, into: writer, inline: true)
            writer.write("]")
        case .dictionary(let key, let value):
            writer.write("[")
            emit(key, into: writer, inline: true)
            writer.write(": ")
            emit(value, into: writer, inline: true)
            writer.write("]")
        case .tuple(let elements):
            writer.write("(")
            for (i, e) in elements.enumerated() {
                if i > 0 {
                    writer.write(", ")
                }
                if let label = e.label {
                    writer.write(label)
                    writer.write(": ")
                }
                emit(e.type, into: writer, inline: true)
            }
            if elements.count == 1 {
                writer.write(",")
            }
            writer.write(")")
        case .function(let function):
            writer.write("(")
            for (i, p) in function.parameters.enumerated() {
                if i > 0 { writer.write(", ") }
                emit(p, into: writer, inline: true)
            }
            writer.write(")")
            if function.isAsync { writer.write(" async") }
            if function.isThrows { writer.write(" throws") }
            writer.write(" -> ")
            emit(function.returnType, into: writer, inline: true)
        case .composition(let types):
            for (i, value) in types.enumerated() {
                if i > 0 { writer.write(" & ") }
                emit(value, into: writer, inline: true)
            }
        case .attributed(let attributed):
            for specifier in attributed.specifiers {
                writer.write(specifierName(specifier))
                writer.write(" ")
            }
            emit(attributed.baseType, into: writer, inline: true)
        case .generic(let generic):
            writer.write(generic.name)
            writer.write("<")
            for (i, arg) in generic.arguments.enumerated() {
                if i > 0 { writer.write(", ") }
                emit(arg, into: writer, inline: true)
            }
            writer.write(">")
        case .metatype(let value):
            emit(value, into: writer, inline: true)
            writer.write(".Type")
        case .unknown(let value):
            writer.write(value)
        }
    }

    private func emitInheritedTypes(_ types: [SwiftType], into writer: SwiftWriter) {
        guard !types.isEmpty else { return }
        writer.write(": ")
        for (i, type) in types.enumerated() {
            if i > 0 { writer.write(", ") }
            emit(type, into: writer, inline: true)
        }
    }

    private func emitModifiers(_ modifiers: [SwiftModifier], into writer: SwiftWriter) {
        for modifier in modifiers {
            writer.write(modifier.rawValue)
            writer.space()
        }
    }

    private func keyword(for kind: SwiftTypeKind) -> String {
        switch kind {
        case .class: 
            return "class"
        case .struct: 
            return "struct"
        case .enum: 
            return "enum"
        case .actor: 
            return "actor"
        case .protocol: 
            return "protocol"
        }
    }

    private func specifierName(_ specifier: SwiftTypeSpecifier) -> String {
        switch specifier {
        case .inout: 
            return "inout"
        case .consuming: 
            return "consuming"
        case .borrowing: 
            return "borrowing"
        case .isolated: 
            return "isolated"
        case .unchecked: 
            return "@unchecked"
        }
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
    }
}
