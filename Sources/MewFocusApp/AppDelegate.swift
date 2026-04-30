import AppKit
import MewFocusData
import MewFocusDesign
import MewFocusDomain
import MewFocusPresentation
import SwiftUI
import WidgetKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let snapshotRepository = AppGroupFocusSessionSnapshotRepository()
    private let statisticsRepository: any FocusStatisticsRepository = AppDelegate.makeStatisticsRepository()
    private var animationTimer: Timer?
    private var currentMenuBarFrameIndex = 0
    private let menuBarIconSize = NSSize(width: 22, height: 22)
    private let popoverBaseSize = NSSize(width: 530, height: 842)
    private let popoverScale: CGFloat = 0.62

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ensureSingleInstance() else { return }

        NSApp.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: 28)
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.image = menuBarCatImage(named: MewFocusAsset.menuBarCat1)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        self.statusItem = statusItem
        startMenuBarCatAnimation()

        popover.behavior = .transient
        let scaledPopoverSize = NSSize(
            width: popoverBaseSize.width * popoverScale,
            height: popoverBaseSize.height * popoverScale
        )
        popover.contentSize = scaledPopoverSize
        popover.contentViewController = NSHostingController(
            rootView: FocusPopoverView(
                snapshotRepository: snapshotRepository,
                statisticsRepository: statisticsRepository,
                reloadWidgetTimelines: {
                    WidgetCenter.shared.reloadTimelines(ofKind: "MewFocusCatWidget")
                }
            )
            .frame(width: popoverBaseSize.width, height: popoverBaseSize.height, alignment: .topLeading)
            .scaleEffect(popoverScale, anchor: .topLeading)
            .frame(width: scaledPopoverSize.width, height: scaledPopoverSize.height, alignment: .topLeading)
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        animationTimer?.invalidate()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "mewfocus" }) else { return }

        NSApp.activate(ignoringOtherApps: true)
        showPopover()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func ensureSingleInstance() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
        )
        let otherRunningApps = runningApps.filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }

        guard otherRunningApps.isEmpty else {
            otherRunningApps.first?.activate()
            NSApp.terminate(nil)
            return false
        }

        return true
    }

    private static func makeStatisticsRepository() -> any FocusStatisticsRepository {
        (try? SwiftDataFocusStatisticsRepository()) ?? InMemoryFocusStatisticsRepository()
    }

    private func startMenuBarCatAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: 0.45,
            repeats: true
        ) { [weak self] _ in
            self?.advanceMenuBarCatFrame()
        }
    }

    private func advanceMenuBarCatFrame() {
        let frames = MewFocusAsset.menuBarCatFrames
        currentMenuBarFrameIndex = (currentMenuBarFrameIndex + 1) % frames.count
        statusItem?.button?.image = menuBarCatImage(named: frames[currentMenuBarFrameIndex])
    }

    private func menuBarCatImage(named name: String) -> NSImage? {
        guard let image = MewFocusAsset.bundle.image(forResource: name) else { return nil }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            image.size = menuBarIconSize
            image.isTemplate = false
            return image
        }

        let croppedImage = croppedNonTransparentImage(from: cgImage) ?? cgImage
        let menuBarImage = NSImage(cgImage: croppedImage, size: menuBarIconSize)
        menuBarImage.isTemplate = false
        return menuBarImage
    }

    private func croppedNonTransparentImage(from image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var hasVisiblePixel = false

        for y in 0..<height {
            for x in 0..<width {
                let alphaIndex = (y * bytesPerRow) + (x * bytesPerPixel) + 3
                guard pixels[alphaIndex] > 8 else { continue }

                hasVisiblePixel = true
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard hasVisiblePixel else { return nil }

        let padding = 8
        let cropX = max(minX - padding, 0)
        let cropY = max(minY - padding, 0)
        let cropMaxX = min(maxX + padding, width - 1)
        let cropMaxY = min(maxY + padding, height - 1)

        return image.cropping(
            to: CGRect(
                x: cropX,
                y: cropY,
                width: cropMaxX - cropX + 1,
                height: cropMaxY - cropY + 1
            )
        )
    }
}
