import ProjectDescription

let project = Project(
    name: "MewFocus",
    organizationName: "Mash-Up",
    options: .options(
        automaticSchemesOptions: .enabled()
    ),
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.9",
            "MACOSX_DEPLOYMENT_TARGET": "14.0"
        ]
    ),
    targets: [
        .target(
            name: "MewFocusApp",
            destinations: .macOS,
            product: .app,
            bundleId: "com.mashup.MewFocus",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "Mew Focus",
                    "LSUIElement": true,
                    "NSHumanReadableCopyright": "Copyright © 2026 Mash-Up. All rights reserved."
                ]
            ),
            sources: ["Sources/MewFocusApp/**"],
            resources: ["Resources/MewFocusApp/**"],
            dependencies: [
                .target(name: "MewFocusPresentation"),
                .target(name: "MewFocusData")
            ]
        ),
        .target(
            name: "MewFocusPresentation",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.mashup.MewFocus.Presentation",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/MewFocusPresentation/**"],
            dependencies: [
                .target(name: "MewFocusDomain"),
                .target(name: "MewFocusDesign")
            ]
        ),
        .target(
            name: "MewFocusDomain",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.mashup.MewFocus.Domain",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/MewFocusDomain/**"],
            dependencies: []
        ),
        .target(
            name: "MewFocusData",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.mashup.MewFocus.Data",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/MewFocusData/**"],
            dependencies: [
                .target(name: "MewFocusDomain")
            ]
        ),
        .target(
            name: "MewFocusDesign",
            destinations: .macOS,
            product: .framework,
            bundleId: "com.mashup.MewFocus.Design",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/MewFocusDesign/**"],
            dependencies: []
        ),
        .target(
            name: "MewFocusDomainTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.mashup.MewFocus.DomainTests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/MewFocusDomainTests/**"],
            dependencies: [
                .target(name: "MewFocusDomain")
            ]
        )
    ],
    schemes: [
        .scheme(
            name: "MewFocusApp",
            shared: true,
            buildAction: .buildAction(targets: ["MewFocusApp"]),
            testAction: .targets(["MewFocusDomainTests"]),
            runAction: .runAction(executable: "MewFocusApp")
        ),
        .scheme(
            name: "MewFocusDomain",
            shared: true,
            buildAction: .buildAction(targets: ["MewFocusDomain"]),
            testAction: .targets(["MewFocusDomainTests"])
        )
    ]
)
