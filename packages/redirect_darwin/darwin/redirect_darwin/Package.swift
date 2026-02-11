// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to
// build this package.

import PackageDescription

let package = Package(
    name: "redirect_darwin",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "redirect-darwin", targets: ["redirect_darwin"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "redirect_darwin",
            dependencies: [],
            resources: [
                // If your plugin requires a privacy manifest
                // (e.g. if it uses any required reason APIs), update the
                // PrivacyInfo.xcprivacy file to describe your plugin's privacy
                // impact, and then uncomment this line.
                // For more information, see:
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "redirect_darwin_tests",
            dependencies: ["redirect_darwin"]
        ),
    ]
)
