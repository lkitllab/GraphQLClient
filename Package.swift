// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraphQLClient",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "GraphQLClient",
            targets: ["GraphQLClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apollographql/apollo-ios", from: "0.53.0"),
    ],
    targets: [
        .target(
            name: "GraphQLClient",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios")
            ]),
        .testTarget(
            name: "GraphQLClientTests",
            dependencies: ["GraphQLClient"]),
    ]
)
