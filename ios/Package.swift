// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "tauri-plugin-remote-push",
  platforms: [
    .macOS(.v10_13),
    .iOS(.v13),
  ],
  products: [
    .library(
      name: "tauri-plugin-remote-push",
      type: .static,
      targets: ["tauri-plugin-remote-push"])
  ],
  dependencies: [
    .package(name: "Tauri", path: "../.tauri/tauri-api"),
    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.11.0"),
  ],
  targets: [
    .target(
      name: "tauri-plugin-remote-push",
      dependencies: [
        .byName(name: "Tauri"),
        .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
        .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
      ],
      path: "Sources")
  ]
)