// swift-tools-version:6.0
import PackageDescription

// Mihon → iOS port. Multi-module SPM package.
//
// THE LOAD-BEARING RULE (see AGENTS.md): the platform-agnostic core imports NO
// Apple framework. It compiles and tests on Windows/Linux with `swift test`, so
// ~half the project is developable in a fast local loop with no Mac and no CI
// round-trip. Apple-framework code (JavaScriptCore, SwiftUI, GRDB) lives in thin
// outer modules behind protocols defined in the core, and is guarded with
// `#if canImport(...)` so the whole package still builds on non-Apple platforms.
//
// Module tiers:
//   PLATFORM-AGNOSTIC (build + test on Windows):  MihonCore, MihonBackup
//   APPLE / CI-ONLY (build on macOS runner):       MihonSources, MihonData, MihonUI
let package = Package(
    name: "Mihon",
    platforms: [
        .iOS(.v17), // ADR-3 floor: @Observable, modern scroll APIs. Ignored on Windows/Linux.
    ],
    products: [
        .library(name: "MihonCore", targets: ["MihonCore"]),
        .library(name: "MihonBackup", targets: ["MihonBackup"]),
        .library(name: "MihonSources", targets: ["MihonSources"]),
        .library(name: "MihonData", targets: ["MihonData"]),
        .library(name: "MihonUI", targets: ["MihonUI"]),
    ],
    dependencies: [
        // Cross-platform (Linux + Windows + Apple) — provides Insecure.MD5 for
        // source-ID parity. Apple-maintained; the one core dependency.
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        // ---- PLATFORM-AGNOSTIC TIER (no Apple framework) ----
        .target(
            name: "MihonCore",
            dependencies: [.product(name: "Crypto", package: "swift-crypto")]
        ),
        .target(
            name: "MihonBackup",
            dependencies: ["MihonCore"]
        ),

        // ---- APPLE / CI-ONLY TIER (guarded with #if canImport) ----
        .target(
            name: "MihonSources", // JavaScriptCore source runtime (ADR-1)
            dependencies: ["MihonCore"]
        ),
        .target(
            name: "MihonData", // GRDB-backed repositories (ADR-2)
            dependencies: ["MihonCore"]
        ),
        .target(
            name: "MihonUI", // SwiftUI screens
            dependencies: ["MihonCore"]
        ),

        // ---- TESTS (run on Windows/Linux) ----
        .testTarget(name: "MihonCoreTests", dependencies: ["MihonCore"]),
        .testTarget(name: "MihonBackupTests", dependencies: ["MihonBackup"]),
    ]
)
