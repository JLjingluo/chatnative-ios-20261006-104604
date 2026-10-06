// swift-tools-version: 5.9
import PackageDescription

// Portable tests exercise the exact request construction and SSE parser used by iOS.
let package = Package(
    name: "ChatNativeCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "ChatNativeCore", targets: ["ChatNativeCore"])],
    targets: [
        .target(name: "ChatNativeCore", path: "ChatNative/Core", exclude: ["ChatStore.swift", "Keychain.swift", "SpeechController.swift"]),
        .testTarget(name: "ChatNativeCoreTests", dependencies: ["ChatNativeCore"], path: "ChatNativeTests")
    ]
)
