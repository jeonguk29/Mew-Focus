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
            "MACOSX_DEPLOYMENT_TARGET": "14.0",
            "ENABLE_DEBUG_DYLIB": "NO"
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
        ),
        .target(
            name: "MewFocusDataTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.mashup.MewFocus.DataTests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/MewFocusDataTests/**"],
            dependencies: [
                .target(name: "MewFocusData"),
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

                        OLD_APPEX="${DEST_PATH}/Contents/PlugIns/MewFocusWidget.appex"

                        # Kill existing instances so the new build is loaded
                        killall "MewFocusApp" 2>/dev/null || true
                        pkill -f "MewFocusWidget" 2>/dev/null || true

                        # Unregister the old widget extension so cached previews are dropped
                        if [ -d "${OLD_APPEX}" ]; then
                          pluginkit -r "${OLD_APPEX}" 2>/dev/null || true
                        fi

                        rm -rf "${DEST_PATH}"
                        ditto "${APP_PATH}" "${DEST_PATH}"
                        touch "${DEST_PATH}"

                        # Wipe chronod descriptor/snapshot cache, then restart it
                        defaults delete com.apple.chronod 2>/dev/null || true
                        killall chronod 2>/dev/null || true

                        # Re-register the new widget extension
                        pluginkit -a "${DEST_PATH}/Contents/PlugIns/MewFocusWidget.appex" 2>/dev/null || true

                        open -gj "${DEST_PATH}" || true
                        echo "Reinstalled ${DEST_PATH}; chronod and widget caches purged."
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
        ),
        .scheme(
            name: "MewFocusData",
            shared: true,
            buildAction: .buildAction(targets: ["MewFocusData"]),
            testAction: .targets(["MewFocusDataTests"])
        )
    ]
)
