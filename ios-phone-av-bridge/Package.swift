// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "PhoneAVBridgeIOS",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
  ],
  products: [
    .library(
      name: "PhoneAVBridgeIOS",
      targets: ["PhoneAVBridgeIOS"]
    ),
  ],
  targets: [
    .target(
      name: "PhoneAVBridgeIOS"
    ),
    .testTarget(
      name: "PhoneAVBridgeIOSTests",
      dependencies: ["PhoneAVBridgeIOS"]
    ),
    .testTarget(
      name: "PhoneAVBridgeIOSIntegrationTests",
      dependencies: ["PhoneAVBridgeIOS"]
    ),
  ]
)
