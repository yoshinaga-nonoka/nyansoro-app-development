// swift-tools-version:5.9
// ゲームのルール本体。画面（SwiftUI）に依存しないので Linux / macOS でもテストできる。
// iOS アプリでは、このフォルダのソースをアプリに直接取り込んでいる（Nyansoro.xcodeproj の同期フォルダ）。
import PackageDescription

let package = Package(
    name: "NyansoroCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "NyansoroCore", targets: ["NyansoroCore"]),
    ],
    targets: [
        .target(name: "NyansoroCore"),
        .executableTarget(name: "nyansoro-sim", dependencies: ["NyansoroCore"]),
        .testTarget(name: "NyansoroCoreTests", dependencies: ["NyansoroCore"]),
    ]
)
