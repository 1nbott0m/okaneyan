// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoneyWise",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "MoneyCore", targets: ["MoneyCore"]), .executable(name: "moneywise-demo", targets: ["MoneyWiseDemo"]), .executable(name: "moneywise-checks", targets: ["MoneyCoreChecks"])],
    targets: [
        .target(name: "MoneyCore"),
        .executableTarget(name: "MoneyWiseDemo", dependencies: ["MoneyCore"]),
        .executableTarget(name: "MoneyCoreChecks", dependencies: ["MoneyCore"], path: "Tests/MoneyCoreTests")
    ]
)
