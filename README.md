# SwiftMockGenerator

SwiftMockGenerator generates Swift protocol mocks at build time. The generated files depend on `MockRuntime`; the parser, emitter, and command-line generator do not need to be linked into the application.

## Quick start

```bash
swift build -c release --product mockgen
.build/release/mockgen Sources/MyApp Tests/GeneratedMocks
```

The first argument can be a Swift source file or a directory. When a directory is supplied, Swift files are scanned recursively. Generated files should be placed in a directory compiled by the **test target**, not the production app target.

See [`INTEGRATION.md`](INTEGRATION.md) for Swift Package Manager, CocoaPods, Xcode build-phase, and CI setup. Callback-based stubbing examples are in [`CALLBACK_STUBBING.md`](CALLBACK_STUBBING.md).

## Products

- `mockgen`: build-time executable
- `MockRuntime`: runtime library imported by generated mocks
- `MockGeneratorCommandPlugin`: SwiftPM command plugin for invoking `mockgen` from a package

The package currently uses Swift tools 6.0 and SwiftSyntax 600.x.


### Stubbing non-optional properties

Generated mocks expose a companion `propertyNameStub` handle for each non optional property. Use it to configure a property when it's non-optional that has not been configured yet.

```swift
mock.propertyNameStub = false
given(mock.propertyName).willReturn(true)
XCTAssertTrue(mock.propertyName)
```

## Generate only mocks referenced by a test target

By default, `mockgen` generates a mock for every protocol discovered in the production sources. To generate only mocks referenced by the test target, provide its source directory and select the `used` scope:

```bash
.build/release/mockgen Sources/MyApp GeneratedMocks \\
  --scope used \\
  --tests Tests/MyAppTests
  --module MyApp
```

The usage scanner recognizes direct generated mock type references, including both declarations (`var repository: MockUserRepositoryProtocol`) and construction (`MockUserRepositoryProtocol()`). It scans Swift files recursively and ignores common build/dependency directories. This is syntax-based matching: type aliases and indirect references that do not mention the generated mock type are not resolved. Use `--scope all` (the default) to preserve generate-all behavior.

When switching from generate-all to used-only, remove stale generated mock files or use `Scripts/generate_mocks.sh --clean` so unused files from earlier runs are not left in the output directory.

## Build generator and generate mocks

To build the generator and generate mocks with the compiled artifact

```bash
generate_mocks.sh \\
--sources Sources/MyApp \\
--output GeneratedMoks \\
--repository https://github.com/alejoberman/swift-mock-generator.git \\
--ref main \\
--scope used \\
--tests Tests/MyAppTests \\
--module MyApp
```
