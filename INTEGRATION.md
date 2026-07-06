# Integrating SwiftMockGenerator into an iOS project

SwiftMockGenerator has two separate pieces:

- **`mockgen`** is a build-time executable. It parses protocol declarations and writes generated Swift source files.
- **`MockRuntime`** is the library imported by generated mocks. Add it to the test target, not the production app target unless your app itself intentionally uses mocks.

The generator scans a Swift file or directory and emits `Mock<Protocol>.swift` files. Put the output under a directory included in the unit-test target. Avoid generating into the production target.

## Swift Package Manager

### Add the package

In Xcode, choose **File → Add Package Dependencies…** and add the repository URL for SwiftMockGenerator. Or add it to `Package.swift` (replace the URL with your actual repository URL):

```swift
.package(url: "https://github.com/alejoberman/SwiftMockGenerator.git", from: "0.1.0")
```

Add `MockRuntime` to the unit-test target's dependencies. For a Swift package, the target dependency is:

```swift
.testTarget(
    name: "MyAppTests",
    dependencies: [
        "MyApp",
        .product(name: "MockRuntime", package: "SwiftMockGenerator")
    ]
)
```

The package also exports the `MockGeneratorCommandPlugin`. After adding the package, run the command plugin from the package root:

```bash
swift package --allow-writing-to-package-directory generate-mocks Sources/MyApp Tests/GeneratedMocks
```

The first path may be a Swift file or a directory. The output directory should be part of the test target. If your SwiftPM version does not expose dependency command plugins in your workflow, use the portable script below.

## CocoaPods

`MockRuntime.podspec` packages only the runtime sources.


```ruby
target 'MyAppTests' do
  pod 'MockRuntime', '~> 0.1'
end
```

CocoaPods installs the runtime, not the generator executable. Keep a checkout of SwiftMockGenerator in your repository or CI workspace and use its script to generate mocks.

## Xcode Run Script Build Phase / CI

Add a **Run Script Build Phase** to the unit-test target (or run the same command in CI). Set `GENERATOR_ROOT` to the checkout location. Example:

```bash
"$GENERATOR_ROOT/Scripts/generate_mocks.sh" \
  --generator-root "$GENERATOR_ROOT" \
  --sources "$SRCROOT/MyApp" \
  --output "$SRCROOT/GeneratedMocks"
```

Add `GeneratedMocks` to the test target's **Compile Sources** if Xcode does not automatically include the files. Do not add it to the app target. For deterministic clean regeneration, pass `--clean`; this removes top-level `Mock*.swift` files in the output directory before generating.

### CI example

```bash
export SWIFT_MOCK_GENERATOR_PATH="$PWD/Tools/SwiftMockGenerator"
"$SWIFT_MOCK_GENERATOR_PATH/Scripts/generate_mocks.sh" \
  --generator-root "$SWIFT_MOCK_GENERATOR_PATH" \
  --sources "$PWD/MyApp" \
  --output "$PWD/MyAppTests/GeneratedMocks" \
  --clean
xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Important notes

- The generator requires Swift 6 tooling and SwiftSyntax 600.x as declared in `Package.swift`.
- The podspec currently declares iOS 15 and macOS 11, matching the package manifest.
- Commit generated mocks or generate them in a pre-test build step; choose one policy consistently.
- Do not point the source scan at the entire repository if it includes generated code, dependencies, or test fixtures. The CLI skips common dependency/build directories, but a narrow source path is preferable.

## Generate only mocks referenced by the test target

The generator can scan the test target and generate mocks only for protocol mocks referenced there:

```bash
.build/release/mockgen Sources/MyApp Tests/GeneratedMocks \
  --scope used \
  --tests Tests/MyAppTests
```

`--tests` must point to the test target's Swift source directory. The scanner recursively detects direct references to generated mock types, such as `MockUserRepositoryProtocol` in a property type or initializer. Matching is syntax-based; aliases and indirect references are not resolved. The default `--scope all` continues to generate mocks for every discovered protocol.

If generated files from an earlier generate-all run remain in the output directory, remove them or invoke `Scripts/generate_mocks.sh --clean` before generating the used-only set.
