import XCTest
@testable import MockGeneratorCore


final class ParserTests: XCTestCase {

    var typeParser: TypeParser!
    var methodParser: MethodParser!
    var propertyParser: PropertyParser!
    var protocolVisitor: ProtocolVisitor!

    override func setUpWithError() throws {
        typeParser = TypeParser()
        methodParser = MethodParser(typeParser: typeParser, parameterParser: ParameterParser(typeParser: typeParser))
        propertyParser = PropertyParser(typeParser: typeParser)
        protocolVisitor = ProtocolVisitor(methodParser: methodParser, propertyParser: propertyParser)
    }
    
    func testProtocolParsing() {
        //Given
        let source = """
        protocol UserRepository {
            func load()
        }
        """
        
        //When
        let parser = SwiftSyntaxProtocolParser(protocolVisitor: protocolVisitor)
        let result = try? parser.parse(source: source)

        //Then
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.name, "UserRepository")
    }
    
    func testProtocolParsingFunctionWithParameters() {
        //Given
        let source = """
        protocol UserRepository {
            func load(id: UUID) async throws -> User
        }
        """
        
        //When
        let parser = SwiftSyntaxProtocolParser(protocolVisitor: protocolVisitor)
        let result = try? parser.parse(source: source)

        //Then
        if case .method(let method) = result?.first?.members.first {
            XCTAssertEqual(method.name, "load")
            XCTAssertEqual(method.parameters.count, 1)
            XCTAssertEqual(method.parameters.first?.externalName, "id")
            XCTAssertEqual(method.parameters.first?.localName, "id")
            XCTAssertNil(method.parameters.first?.defaultValue, "Unexpected default value")
            XCTAssertTrue(method.isAsync, "Unexpected non async modifier")
            XCTAssertTrue(method.isThrows, "Unexpected non throws modifier")
            XCTAssertEqual(method.returnType, .identifier(IdentifierType(name: "User")), "Unexpected type")
        } else {
            XCTFail("Unexpected member")
        }
        XCTAssertEqual(result?.first?.name, "UserRepository")
    }
    
    func testProtocolParsingPreservesGenericArgumentsInClosureParameters() {
        let source = """
        protocol AppStoreRepository {
            func versionAvailableOnStore(
                completion: @escaping (Result<StoreVersionEntity, OAOSError>) -> Void
            )
        }
        """

        let parser = SwiftSyntaxProtocolParser(protocolVisitor: protocolVisitor)
        let result = try? parser.parse(source: source)

        guard case .method(let method) = result?.first?.members.first,
              let parameter = method.parameters.first else {
            XCTFail("Expected versionAvailableOnStore method with a completion parameter")
            return
        }

        XCTAssertEqual(
            SwiftTypeRenderer().render(parameter.type),
            "(Result<StoreVersionEntity, OAOSError>) -> Void"
        )
    }

    func testProtocolParsingProperty() {
        //Given
        let source = """
        protocol UserRepository {
            var user: User {get}
        }
        """
        
        //When
        let parser = SwiftSyntaxProtocolParser(protocolVisitor: protocolVisitor)
        let result = try? parser.parse(source: source)

        //Then
        if case .property(let property) = result?.first?.members.first {
            XCTAssertEqual(property.name, "user")
            XCTAssertEqual(property.type, .identifier(IdentifierType(name: "User")), "Unexpected type")
            XCTAssertNotNil(property.getter, "Unexpected nil getter")
            XCTAssertNil(property.setter, "Unexpected not nil setter")
        } else {
            XCTFail("Unexpected member")
        }
        XCTAssertEqual(result?.first?.name, "UserRepository")
    }
}

//TODO: continue implementing all tests
