// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftMockGenerator",
    platforms: [.macOS(.v11), .iOS(.v15)],
    products: [
        .executable(name: "mockgen", targets: ["MockGeneratorCLI"]),
        .library(name: "MockRuntime", targets: ["MockRuntime"]),
        .plugin(name: "MockGeneratorCommandPlugin", targets: ["MockGeneratorCommandPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .executableTarget(name: "MockGeneratorCLI", dependencies: ["MockGeneratorCore"]),
        .plugin(
            name: "MockGeneratorCommandPlugin",
            capability: .command(
                intent: .custom(verb: "generate-mocks", description: "Generate protocol mocks from a Swift source file or directory"),
                permissions: [.writeToPackageDirectory(reason: "Generated mock source files are written into the package so they can be compiled by its test target.")]
            ),
            dependencies: ["MockGeneratorCLI"]
        ),
        .target(name: "MockGeneratorCodeDOM"),
        .target(name: "MockGeneratorEmitter", dependencies: [
            "MockGeneratorCodeDOM",
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxBuilder", package: "swift-syntax")
        ]),
        .target(name: "MockGeneratorCore", dependencies: [
            "MockGeneratorCodeDOM", "MockGeneratorEmitter",
            .product(name: "SwiftParser", package: "swift-syntax"),
            .product(name: "SwiftSyntax", package: "swift-syntax")
        ]),
        .target(name: "MockRuntime"),
        .testTarget(name: "MocksGeneratorTests", dependencies: [
            "MockGeneratorCore", "MockGeneratorCodeDOM", "MockRuntime"
        ], path: "Tests/MockGeneratorTests"),
        .testTarget(name: "MockRuntimeTests", dependencies: ["MockRuntime"])
    ]
)
