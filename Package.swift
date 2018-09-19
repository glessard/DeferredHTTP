// swift-tools-version:4.2

import PackageDescription

#if !swift(>=4.2)
let versions = [4]
#else
let versions = [SwiftVersion.v4, .v4_2]
#endif

let package = Package(
  name: "deferred",
  products: [
    .library(name: "deferred", type: .static, targets: ["deferred"]),
  ],
  dependencies: [
    .package(url: "https://github.com/glessard/swift-atomics.git", from: "4.1.0"),
  ],
  targets: [
    .target(name: "deferred", dependencies: ["CAtomics"]),
    .testTarget(name: "deferredTests", dependencies: ["deferred"]),
  ],
  swiftLanguageVersions: versions
)
