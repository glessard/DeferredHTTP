// swift-tools-version:5.0

import PackageDescription

let package = Package(
  name: "DeferredHTTP",
  products: [
    .library(name: "DeferredHTTP", targets: ["DeferredHTTP"]),
  ],
  dependencies: [
    .package(url: "https://github.com/glessard/deferred", .revision("ebf6a56ab5c3ab0f5e5df5645db64c0d0a0a50c2")),
    .package(url: "https://github.com/glessard/CurrentQoS.git", from: "1.1.0"),
  ],
  targets: [
    .target(name: "DeferredHTTP", dependencies: ["deferred", "CurrentQoS"]),
    .testTarget(name: "DeferredHTTPTests", dependencies: ["DeferredHTTP", "deferred"]),
  ],
  swiftLanguageVersions: [.v4, .v4_2, .v5]
)
