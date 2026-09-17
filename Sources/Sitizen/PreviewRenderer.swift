import AppKit
import SwiftUI

/// 开发用：把各个界面离屏渲染成 PNG，方便在没有屏幕录制权限的环境里检查视觉效果。
///
///   Sitizen --render-previews <输出目录>
enum PreviewRenderer {

    @MainActor
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--render-previews") else { return false }
        let directory = index + 1 < args.count ? args[index + 1] : "./previews"
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let settings = SettingsStore.shared
        let state = AppState(settings: settings)

        let desktop = CGSize(width: 1440, height: 900)

        write(
            ZStack {
                MockDesktop(light: false)
                WarningView(state: state, settings: settings)
            }
            .frame(width: desktop.width, height: desktop.height),
            size: desktop,
            to: url.appendingPathComponent("01-warning-over-dark-desktop.png")
        )

        write(
            ZStack {
                MockDesktop(light: true)
                WarningView(state: state, settings: settings)
            }
            .frame(width: desktop.width, height: desktop.height),
            size: desktop,
            to: url.appendingPathComponent("02-warning-over-light-desktop.png")
        )

        write(
            LockView(state: state, settings: settings, isPrimary: true)
                .frame(width: desktop.width, height: desktop.height),
            size: desktop,
            to: url.appendingPathComponent("03-lock-primary.png")
        )

        write(
            LockView(state: state, settings: settings, isPrimary: false)
                .frame(width: 1280, height: 800),
            size: CGSize(width: 1280, height: 800),
            to: url.appendingPathComponent("04-lock-secondary.png")
        )

        write(
            ZStack {
                SettingsBackground()
                SettingsContent(settings: settings, state: state, onPreviewWarning: {}, onPreviewLock: {}, onQuit: {})
            }
            .frame(width: 460, height: 900),
            size: CGSize(width: 460, height: 900),
            to: url.appendingPathComponent("05-settings.png")
        )

        write(
            VStack(spacing: 0) {
                MenuBarStrip(light: true)
                MenuBarStrip(light: false)
            }
            .frame(width: 420, height: 132),
            size: CGSize(width: 420, height: 132),
            to: url.appendingPathComponent("06-menubar-icon.png")
        )

        write(
            ZStack {
                SettingsBackground()
                VStack {
                    SettingsHeader()
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .frame(width: 460, height: 170),
            size: CGSize(width: 460, height: 170),
            to: url.appendingPathComponent("07-header.png")
        )

        // 验证件：定长两位后，每个数字的宽度必须完全一致，否则会「跳」
        write(
            ZStack {
                Palette.ink
                HStack(spacing: 36) {
                    ForEach(["10", "09", "05", "01"], id: \.self) { value in
                        RollingNumeral(text: value, size: 116, glowOpacity: 0.3)
                    }
                }
            }
            .frame(width: 780, height: 240),
            size: CGSize(width: 780, height: 240),
            to: url.appendingPathComponent("08-numeral-widths.png")
        )

        // 最紧迫的 3 秒：检查琥珀升温、边缘光框、脉冲环拉满时的样子
        state.previewWarning(at: 3)
        write(
            ZStack {
                MockDesktop(light: false)
                WarningView(state: state, settings: settings)
            }
            .frame(width: desktop.width, height: desktop.height),
            size: desktop,
            to: url.appendingPathComponent("09-warning-escalated.png")
        )
        state.endPreview()

        print("预览已输出到 \(url.path)")
        return true
    }

    /// 菜单栏图标在设计走查里的放大预览：浅色 / 深色菜单栏 × 三种尺寸。
    private struct MenuBarStrip: View {
        var light: Bool

        var body: some View {
            ZStack {
                Color(white: light ? 0.95 : 0.13)
                HStack(spacing: 20) {
                    ForEach([68.0, 42.0, 20.0, 17.0], id: \.self) { width in
                        Image(nsImage: MenuBarIcon.makePreview(
                            width: width,
                            color: light ? .black : .white
                        ))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: width, height: width * 0.711)
                    }
                    Text("45:00")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(light ? Color.black : Color.white)
                }
                .padding(.horizontal, 22)
            }
            .frame(height: 66)
        }
    }

    @MainActor
    private static func write<V: View>(_ view: V, size: CGSize, to url: URL, transparent: Bool = false) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.isOpaque = !transparent

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            print("渲染失败：\(url.lastPathComponent)")
            return
        }
        try? png.write(to: url)
    }
}

/// 开发用：把真正的 AppKit 窗口抓下来（不走屏幕录制），验证窗口 / 控件是否正常。
///
///   Sitizen --snapshot <输出目录>
extension PreviewRenderer {

    @MainActor
    static func runSnapshotIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--snapshot") else { return false }
        let directory = index + 1 < args.count ? args[index + 1] : "./snapshots"
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let settings = SettingsStore.shared
        let state = AppState(settings: settings)

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return true }
        state.standUpNow()
        let overlay = OverlayWindow(screen: screen, level: .screenSaver, interactive: false)
        overlay.setContent(
            LockView(state: state, settings: settings, isPrimary: true)
                .frame(width: screen.frame.width, height: screen.frame.height)
        )
        overlay.orderFrontRegardless()
        spin(1.0)
        capture(overlay, named: "lock-window.png", to: url)
        overlay.orderOut(nil)

        print("快照已输出到 \(url.path)")
        return true
    }

    @MainActor
    private static func spin(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    @MainActor
    private static func capture(_ window: NSWindow, named name: String, to directory: URL) {
        guard let view = window.contentView else {
            print("快照失败：\(name)")
            return
        }
        view.layoutSubtreeIfNeeded()

        let scale = window.backingScaleFactor
        let width = Int(view.bounds.width * scale)
        let height = Int(view.bounds.height * scale)

        guard width > 0, height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
              ),
              let layer = view.layer
        else {
            print("快照失败：\(name)")
            return
        }

        context.scaleBy(x: scale, y: scale)
        layer.render(in: context)

        guard let image = context.makeImage() else {
            print("快照失败：\(name)")
            return
        }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            print("快照失败：\(name)")
            return
        }
        try? png.write(to: directory.appendingPathComponent(name))
    }
}

/// 一个假的桌面背景，用来检查浮层在实际环境里是否可读。
private struct MockDesktop: View {
    var light: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: light
                    ? [
                        Color(white: 0.98),
                        Color(red: 0.93, green: 0.94, blue: 0.97),
                        Color(white: 0.88)
                    ]
                    : [
                        Color(red: 0.20, green: 0.34, blue: 0.52),
                        Color(red: 0.46, green: 0.38, blue: 0.62),
                        Color(red: 0.82, green: 0.55, blue: 0.52)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            windowSkeleton(x: 90, y: 110, w: 720, h: 460, tint: light ? .black : .white)
            windowSkeleton(x: 760, y: 300, w: 600, h: 420, tint: light ? .black : .black)

            VStack(spacing: 8) {
                ForEach(0..<9, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<11, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(light ? 0.10 : 0.28))
                                .frame(width: 74, height: 74)
                                .overlay(
                                    Circle()
                                        .fill(light ? Color.black.opacity(0.20) : Color.white.opacity(0.75))
                                        .frame(width: 24, height: 24)
                                )
                        }
                    }
                    .opacity(row > 5 ? 0.55 : 1)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 30)
        }
        .ignoresSafeArea()
    }

    private func windowSkeleton(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(tint.opacity(0.16))
            .frame(width: w, height: h)
            .overlay(alignment: .topLeading) {
                HStack(spacing: 7) {
                    Circle().fill(Color.red.opacity(0.8)).frame(width: 11, height: 11)
                    Circle().fill(Color.yellow.opacity(0.8)).frame(width: 11, height: 11)
                    Circle().fill(Color.green.opacity(0.8)).frame(width: 11, height: 11)
                }
                .padding(12)
            }
            .offset(x: x - 720, y: y - 450)
    }
}
