import AppKit
import SwiftUI

/// 用 `ButtMark` 渲染 App 图标，和设置页头部、锁屏页用的是同一个标记。
///
///   Sitizen --render-appicon Resources/icon.iconset
enum AppIconRenderer {

    private static let canvas: CGFloat = 1024

    @MainActor
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--render-appicon") else { return false }
        let path = index + 1 < args.count ? args[index + 1] : "Resources/icon.iconset"
        let iconset = URL(fileURLWithPath: path, isDirectory: true)

        try? FileManager.default.removeItem(at: iconset)
        do {
            try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        } catch {
            print("无法创建 \(iconset.path)：\(error.localizedDescription)")
            return true
        }

        let renderer = ImageRenderer(content: Artwork())
        renderer.scale = 1
        renderer.isOpaque = false

        guard let master = renderer.nsImage else {
            print("图标渲染失败")
            return true
        }

        let variants: [(name: String, pixels: Int)] = [
            ("icon_16x16", 16),
            ("icon_16x16@2x", 32),
            ("icon_32x32", 32),
            ("icon_32x32@2x", 64),
            ("icon_128x128", 128),
            ("icon_128x128@2x", 256),
            ("icon_256x256", 256),
            ("icon_256x256@2x", 512),
            ("icon_512x512", 512),
            ("icon_512x512@2x", 1024)
        ]

        for variant in variants {
            guard let data = png(from: master, pixels: variant.pixels) else {
                print("渲染失败：\(variant.name)")
                continue
            }
            try? data.write(to: iconset.appendingPathComponent("\(variant.name).png"))
        }

        print("已生成 \(variants.count) 张图标 → \(iconset.path)")
        return true
    }

    /// 深色圆角底 + 翘臀标记。
    private struct Artwork: View {
        var body: some View {
            let inset = canvas * 0.09
            let side = canvas - inset * 2
            let radius = side * 0.2237

            ZStack {
                Color.clear

                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x2E4036),
                                Color(hex: 0x1B2620)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RadialGradient(
                            colors: [Palette.accent.opacity(0.34), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: side * 0.70
                        )
                    )
                    .overlay(
                        ButtMark()
                            .frame(width: side * 0.82, height: side * 0.82)
                            .offset(y: -side * 0.01)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 26, y: 16)
                    .padding(inset)
            }
            .frame(width: canvas, height: canvas)
        }
    }

    // MARK: - DMG 安装窗口背景

    /// 生成 DMG 打开时的背景图。
    ///
    ///   Sitizen --render-dmg-background <输出路径> [缩放倍数]
    ///
    /// **必须按 1x 输出**：Finder 把背景图按 1:1 像素铺在窗口内容区，
    /// 从不缩放。之前按 2x 输出（1280×800）塞进 640×400 的窗口，
    /// 导致图标和箭头完全对不上、缩放窗口也一团糟。
    /// 视网膜屏的清晰度靠同时提供 1x / 2x 两份，再用 tiffutil 合并成多分辨率 TIFF。
    @MainActor
    static func runDMGBackgroundIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--render-dmg-background") else { return false }
        let path = index + 1 < args.count ? args[index + 1] : "dist/dmg-background.png"
        let scale = index + 2 < args.count ? (Double(args[index + 2]) ?? 1) : 1
        let url = URL(fileURLWithPath: path)

        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let renderer = ImageRenderer(content: DMGBackground())
        renderer.scale = CGFloat(scale)
        renderer.isOpaque = true

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            print("DMG 背景渲染失败")
            return true
        }
        try? png.write(to: url)
        print("已生成 DMG 背景（\(Int(scale))x）→ \(url.path)")
        return true
    }

    /// DMG 打开时的窗口画面。
    ///
    /// 逻辑尺寸就是 640×400 像素，和 Finder 窗口的内容区一一对应。
    /// 图标中心放在 (160, 185) 和 (480, 185)，所以箭头也画在 y = 185。
    private struct DMGBackground: View {
        private let width: CGFloat = 640
        private let height: CGFloat = 400
        /// 两个图标的中心 y
        private let iconY: CGFloat = 185

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x26372F), Color(hex: 0x111A15)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [Palette.accent.opacity(0.14), .clear],
                    center: UnitPoint(x: 0.5, y: 0.10),
                    startRadius: 0,
                    endRadius: 300
                )

                Text("SITIZEN")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(6)
                    .foregroundStyle(Palette.accent.opacity(0.55))
                    .offset(y: -height / 2 + 42)

                arrow
                    .offset(y: iconY - height / 2)

                Text("把左边的 Sitizen 拖进右边的文件夹")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .offset(y: 116)
            }
            .frame(width: width, height: height)
        }

        private var arrow: some View {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 9))
                path.addLine(to: CGPoint(x: 104, y: 9))
                path.addLine(to: CGPoint(x: 104, y: 0))
                path.addLine(to: CGPoint(x: 136, y: 14))
                path.addLine(to: CGPoint(x: 104, y: 28))
                path.addLine(to: CGPoint(x: 104, y: 19))
                path.addLine(to: CGPoint(x: 0, y: 19))
                path.closeSubpath()
            }
            .frame(width: 136, height: 28)
            .foregroundStyle(
                LinearGradient(
                    colors: [Palette.accent.opacity(0.18), Palette.accent.opacity(0.60)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    @MainActor
    private static func png(from image: NSImage, pixels: Int) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(x: 0, y: 0, width: CGFloat(pixels), height: CGFloat(pixels)),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }
}
