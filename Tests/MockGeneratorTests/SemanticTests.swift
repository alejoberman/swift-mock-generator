import XCTest
@testable import MockGeneratorCore

final class SemanticTests: XCTestCase {

    override func setUpWithError() throws {}
    
    func testCreateMethod() throws {
        //Given
        let parameter = ParameterDescriptor(externalName: nil,
                                            localName: "id",
                                            type: .identifier(IdentifierType(name: "String")),
                                            isVariadic: false,
                                            defaultValue: nil)
        
        //When
        let method = MethodDescriptor(name: "load", parameters: [parameter],
                                      returnType: nil,
                                      isAsync: false,
                                      isThrows: false,
                                      isRethrows: false)

        // Then
        XCTAssertEqual(method.name, "load")
        XCTAssertEqual(method.parameters.count, 1)
        XCTAssertNil(method.parameters.first?.externalName)
        XCTAssertEqual(method.parameters.first?.localName, "id")
        XCTAssertNil(method.parameters.first?.defaultValue, "Unexpected default value")
    }
}

//TODO: continue implementing all tests
