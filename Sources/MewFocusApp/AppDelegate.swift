import AppKit
import MewFocusDesign
import MewFocusPresentation
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var animationTimer: Timer?
    private var currentMenuBarFrameIndex = 0
    private let menuBarIconSize = NSSize(width: 22, height: 22)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: 28)
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.image = menuBarCatImage(named: MewFocusAsset.menuBarCat1)
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
        self.statusItem = statusItem
        startMenuBarCatAnimation()

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 530, height: 660)
        popover.contentViewController = NSHostingController(rootView: FocusPopoverView())
    }

    func applicationWillTerminate(_ notification: Notification) {
        animationTimer?.invalidate()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
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
