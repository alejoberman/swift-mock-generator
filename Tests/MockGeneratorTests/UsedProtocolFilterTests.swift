import Foundation
import XCTest
import MockGeneratorCore

final class UsedProtocolFilterTests: XCTestCase {
    func testDiscoversMockTypesUsedAsVariablesAndInitializers() {
        let source = """
        final class RepositoryTests {
            var repository: MockUserRepositoryProtocol!

            func testLoad() {
                let mock = MockFeedRepositoryProtocol()
                _ = mock
            }
        }
        """

        let names = TestUsageDiscovery().discoverMockTypeNames(in: source)

        XCTAssertEqual(names, ["MockUserRepositoryProtocol", "MockFeedRepositoryProtocol"])
    }

    func testFilterKeepsOnlyProtocolsWithReferencedMockTypes() throws {
        let source = """
        protocol UserRepositoryProtocol {}
        protocol FeedRepositoryProtocol {}
        protocol AnalyticsServiceProtocol {}
        """
        let parser = makeParser()
        let protocols = try parser.parse(source: source)
        let references: Set<String> = [
            "MockUserRepositoryProtocol",
            "MockFeedRepositoryProtocol"
        ]

        let selected = UsedProtocolFilter().filter(
            protocols,
            referencedMockTypeNames: references
        )

        XCTAssertEqual(selected.map(\.name), ["UserRepositoryProtocol", "FeedRepositoryProtocol"])
        XCTAssertEqual(selected.count, 2)
    }

    func testDuplicateReferencesDoNotDuplicateSelectedProtocols() throws {
        let protocols = try makeParser().parse(source: "protocol RepositoryProtocol {}")
        let selected = UsedProtocolFilter().filter(
            protocols,
            referencedMockTypeNames: ["MockRepositoryProtocol"]
        )

        XCTAssertEqual(selected.count, 1)
    }

    private func makeParser() -> SwiftSyntaxProtocolParser {
        let typeParser = TypeParser()
        let parameterParser = ParameterParser(typeParser: typeParser)
        let methodParser = MethodParser(typeParser: typeParser, parameterParser: parameterParser)
        let propertyParser = PropertyParser(typeParser: typeParser)
        return SwiftSyntaxProtocolParser(
            protocolVisitor: ProtocolVisitor(methodParser: methodParser, propertyParser: propertyParser)
        )
    }
}
