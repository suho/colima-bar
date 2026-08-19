// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ColimaBar",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "ColimaBar", targets: ["ColimaBar"])
  ],
  targets: [
    .executableTarget(
      name: "ColimaBar",
      path: "Sources/ColimaBar"
    ),
    .testTarget(
      name: "ColimaBarTests",
      dependencies: ["ColimaBar"],
      path: "Tests/ColimaBarTests"
    ),
  ]
)
