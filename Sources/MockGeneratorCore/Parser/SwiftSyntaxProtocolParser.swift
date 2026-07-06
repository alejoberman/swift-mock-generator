import Foundation
import SwiftSyntax
import SwiftParser

public final class SwiftSyntaxProtocolParser: ParserProtocol {
    private let protocolVisitor: ProtocolVisitor
    
    public init(protocolVisitor: ProtocolVisitor) {
        self.protocolVisitor = protocolVisitor
    }
    
    public func parse(source: String) throws -> [ProtocolDescriptor] {
        let tree = Parser.parse(source: source)
        let visitor = protocolVisitor
        visitor.reset()
        visitor.walk(tree)
        
        return visitor.protocols
    }
}
