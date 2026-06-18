// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftTrigger",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SwiftTrigger",
            path: "Sources/SwiftTrigger",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "SwiftTriggerTests",
            dependencies: ["SwiftTrigger"],
            path: "Tests/SwiftTriggerTests"
        )
    ]
)
