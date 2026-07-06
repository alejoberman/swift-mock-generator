import Foundation
import SwiftParser
import SwiftSyntax

/// Finds generated mock type names referenced by Swift test source files.
/// Direct references such as `MockUserRepository()` and `var repository: MockUserRepository`.
public final class TestUsageDiscovery {
    public init() {}

    public func discoverMockTypeNames(in source: String) -> Set<String> {
        let visitor = MockTypeReferenceVisitor()
        visitor.walk(Parser.parse(source: source))
        return visitor.mockTypeNames
    }

    public func discoverMockTypeNames(in directory: URL) throws -> Set<String> {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw TestUsageDiscoveryError.notADirectory(directory.path)
        }

        let ignoredDirectoryNames: Set<String> = [".build", ".git", "DerivedData", "Pods", "Carthage"]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw TestUsageDiscoveryError.cannotEnumerate(directory.path)
        }

        var result = Set<String>()
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                if ignoredDirectoryNames.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard url.pathExtension == "swift" else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)
            result.formUnion(discoverMockTypeNames(in: source))
        }
        return result
    }
}

private final class MockTypeReferenceVisitor: SyntaxVisitor {
    private(set) var mockTypeNames = Set<String>()

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        record(node.baseName.text)
        return .visitChildren
    }

    private func record(_ identifier: String) {
        guard identifier.hasPrefix("Mock"), identifier.count > 4 else { return }
        mockTypeNames.insert(identifier)
    }
}

public enum TestUsageDiscoveryError: Error, CustomStringConvertible {
    case notADirectory(String)
    case cannotEnumerate(String)

    public var description: String {
        switch self {
        case .notADirectory(let path): return "Test source path is not a directory: \(path)"
        case .cannotEnumerate(let path): return "Cannot enumerate test source directory: \(path)"
        }
    }
}
