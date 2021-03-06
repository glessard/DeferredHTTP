// swift-tools-version:5.0

import PackageDescription

let package = Package(
  name: "DeferredHTTP",
  products: [
    .library(name: "DeferredHTTP", targets: ["DeferredHTTP"]),
  ],
  dependencies: [
    .package(url: "https://github.com/glessard/deferred", from: "6.6.0"),
    .package(url: "https://github.com/glessard/CurrentQoS", from: "1.1.0"),
  ],
  targets: [
    .target(name: "DeferredHTTP", dependencies: ["deferred", "CurrentQoS"]),
    .testTarget(name: "DeferredHTTPTests", dependencies: ["DeferredHTTP", "deferred"]),
  ],
  swiftLanguageVersions: [.v4, .v4_2, .v5]
)
