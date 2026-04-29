import Foundation
import SwiftUI

public enum MewFocusAsset {
    public static let menuBarCat1 = "MenuBarCat1"
    public static let menuBarCat2 = "MenuBarCat2"
    public static let menuBarCat3 = "MenuBarCat3"
    public static let menuBarCat4 = "MenuBarCat4"
    public static let menuBarCat5 = "MenuBarCat5"
    public static let headerCat = "HeaderCat"
    public static let timerCat = "TimerCat"

    public static let menuBarCatFrames = [
        menuBarCat1,
        menuBarCat2,
        menuBarCat3,
        menuBarCat4,
        menuBarCat5
    ]

    public static var bundle: Bundle {
        Bundle(for: BundleToken.self)
    }

    public static func image(_ name: String) -> Image {
        Image(name, bundle: bundle)
    }
}

private final class BundleToken {}
