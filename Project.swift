import ProjectDescription

let project = Project(
    name: "MewFocus",
    organizationName: "Mash-Up",
    options: .options(
        automaticSchemesOptions: .enabled()
    ),
    settings: .settings(
        base: [
            "CODE_SIGN_STYLE": "Automatic",
            "DEVELOPMENT_TEAM": "9S8KMMC3YH",
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
                    "CFBundleURLTypes": [
                        [
                            "CFBundleURLName": "com.mashup.MewFocus",
                            "CFBundleURLSchemes": ["mewfocus"]
                        ]
                    ],
                    "LSUIElement": false,
                    "NSHumanReadableCopyright": "Copyright © 2026 Mash-Up. All rights reserved."
                ]
            ),
            sources: ["Sources/MewFocusApp/**"],
            resources: ["Resources/MewFocusApp/**"],
            entitlements: .file(path: "Entitlements/MewFocusApp.entitlements"),
            dependencies: [
                .target(name: "MewFocusPresentation"),
                .target(name: "MewFocusData"),
                .target(name: "MewFocusDesign"),
                .target(name: "MewFocusWidget")
            ]
        ),
        .target(
            name: "MewFocusWidget",
            destinations: .macOS,
            product: .appExtension,
            bundleId: "com.mashup.MewFocus.Widget",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "Mew Focus",
                    "NSExtension": [
                        "NSExtensionAttributes": [
                            "NSExtensionPointVersion": "3.0"
                        ],
                        "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
                    ]
                ]
            ),
            sources: ["Sources/MewFocusWidget/**"],
            entitlements: .file(path: "Entitlements/MewFocusWidget.entitlements"),
            dependencies: [
                .target(name: "MewFocusDomain"),
                .target(name: "MewFocusDesign"),
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
            resources: ["Resources/MewFocusDesign/**"],
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
            buildAction: .buildAction(
                targets: ["MewFocusApp"],
                postActions: [
                    .executionAction(
                        title: "Install and Launch /Applications App for WidgetKit",
                        scriptText: """
                        set -e

                        if [ "${CODE_SIGNING_ALLOWED:-YES}" = "NO" ]; then
                          echo "Skipping /Applications install because code signing is disabled."
                          exit 0
                        fi

                        APP_PATH="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"
                        DEST_PATH="/Applications/${FULL_PRODUCT_NAME}"

                        if [ ! -d "${APP_PATH}" ]; then
                          echo "Skipping /Applications install because ${APP_PATH} does not exist."
                          exit 0
                        fi

                        rm -rf "${DEST_PATH}"
                        ditto "${APP_PATH}" "${DEST_PATH}"
                        touch "${DEST_PATH}"
                        open -gj "${DEST_PATH}" || true
                        echo "Installed and launched ${DEST_PATH} for WidgetKit discovery."
                        """,
                        target: .target("MewFocusApp")
                    )
                ]
            ),
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
