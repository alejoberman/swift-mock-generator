import Foundation

public struct SwiftFile: Equatable {
    public var imports: [SwiftImport]
    public var declarations: [SwiftDeclaration]

    public init(imports: [SwiftImport] = [], declarations: [SwiftDeclaration] = []) {
        self.imports = imports
        self.declarations = declarations
    }
}
