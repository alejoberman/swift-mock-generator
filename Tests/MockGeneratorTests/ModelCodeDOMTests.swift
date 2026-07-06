import XCTest
@testable import MockGeneratorCore
@testable import MockGeneratorCodeDOM

final class ModelCodeDOMTests: XCTestCase {

    func testCreateMethod() {
        //Given, When
        let method = SwiftMethod(name: "load", parameters: [], returnType: .identifier("User"))

        // Then
        XCTAssertEqual(method.name, "load")
        XCTAssertEqual(method.returnType, .identifier("User"))
    }
    
    func testCreateFile() {
        //Given
        let aExtension = SwiftExtension(extendedType: .identifier("String"),
                                        conformances: [.identifier("Codable")],
                                        members: [.property(SwiftProperty(name: "myProperty", type: SwiftType.identifier("Int")))])
        
        //When
        let file = SwiftFile(imports: [SwiftImport(module: "Foundation"),
                                       SwiftImport(module: "MyFramework")],
                             declarations: [.extension(aExtension)])
        
        //Then
        XCTAssertTrue(file.imports.contains { $0.module == "Foundation" }, "Unexpected import")
        XCTAssertTrue(file.imports.contains { $0.module == "MyFramework" }, "Unexpected import")
        XCTAssertTrue(file.declarations.contains { .extension(aExtension) == $0 }, "Unexpected declaration")
    }
}

//TODO: continue implementing all tests
