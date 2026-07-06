import Foundation

public protocol ParserProtocol {
    func parse(source: String) throws -> [ProtocolDescriptor]
}
