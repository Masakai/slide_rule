// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SlideRuleKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SlideRuleKit", targets: ["SlideRuleKit"]),
    ],
    targets: [
        .target(name: "SlideRuleKit"),
        .testTarget(name: "SlideRuleKitTests", dependencies: ["SlideRuleKit"]),
    ]
)
