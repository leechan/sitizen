import AppKit
import SwiftUI

/// 生成产品宣传图。
///
///   Sitizen --render-marketing <输出目录>
///
/// 每张都是 1600×1000 的成品卡片：左边文案、右边真实界面截图，
/// 截图直接复用 App 里的 LockView / WarningView / SettingsContent，不是另画一份。
enum MarketingRenderer {

    private static let cardSize = CGSize(width: 1600, height: 1000)

    @MainActor
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--render-marketing") else { return false }
        let directory = index + 1 < args.count ? args[index + 1] : "./marketing"
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let settings = SettingsStore.shared
        let state = AppState(settings: settings)

        // 01 主视觉
        state.previewStand(at: 272)   // 4:32
        write(
            MarketingCard(
                eyebrow: "站起来",
                title: "你坐出来的问题\n只能靠站起来解决",
                subtitle: "开工即开始计时，45 分钟到点直接锁脸。",
                bullets: ["全屏锁屏，不站满不解锁", "休息倒计时实时可见", "到点自动进入下一轮"]
            ) {
                WindowShot(
                    image: snapshot(
                        LockView(state: state, settings: settings, isPrimary: true),
                        size: CGSize(width: 1200, height: 800)
                    ),
                    width: 880,
                    height: 587
                )
            },
            to: url.appendingPathComponent("01-hero.png")
        )

        // 02 预警
        state.previewWarning(at: 7)
        write(
            MarketingCard(
                eyebrow: "最后十秒",
                title: "全屏透明预警\n但绝不挡你操作",
                subtitle: "数字浮在桌面之上，鼠标点击完全穿透。",
                bullets: ["倒计时只用看，不用点", "深浅壁纸都清晰可读", "数字滚动过渡，不跳位"]
            ) {
                WindowShot(
                    image: snapshot(
                        ZStack {
                            DesktopMock()
                            WarningView(state: state, settings: settings)
                        },
                        size: CGSize(width: 1200, height: 800)
                    ),
                    width: 880,
                    height: 587
                )
            },
            to: url.appendingPathComponent("02-warning.png")
        )

        // 03 锁屏
        state.previewStand(at: 300)
        write(
            MarketingCard(
                eyebrow: "休息时间",
                title: "到点锁脸\n站满了才放行",
                subtitle: "全屏覆盖、拦截快捷键，休息就是休息。",
                bullets: ["支持多显示器同时覆盖", "认输解锁要两步确认", "休眠 / 锁屏自动暂停"]
            ) {
                WindowShot(
                    image: snapshot(
                        LockView(state: state, settings: settings, isPrimary: true),
                        size: CGSize(width: 1200, height: 800)
                    ),
                    width: 880,
                    height: 587
                )
            },
            to: url.appendingPathComponent("03-lock.png")
        )

        // 04 设置
        write(
            MarketingCard(
                eyebrow: "节奏",
                title: "45 分钟久坐\n5 分钟起立",
                subtitle: "两个数字都能改，从 1 分钟到 3 小时。",
                bullets: ["预设一键切换，滑杆微调", "提前预警 3–30 秒可调", "音效、开机启动、自动暂停"]
            ) {
                WindowShot(
                    image: snapshot(
                        ZStack {
                            SettingsBackground()
                            SettingsContent(
                                settings: settings,
                                state: state,
                                onPreviewWarning: {},
                                onPreviewLock: {},
                                onQuit: {}
                            )
                        },
                        size: CGSize(width: 460, height: 760)
                    ),
                    width: 470,
                    height: 740,
                    chrome: true
                )
            },
            to: url.appendingPathComponent("04-settings.png")
        )

        // 05 菜单栏
        write(
            MarketingCard(
                eyebrow: "菜单栏",
                title: "倒计时就在\n眼睛够得着的地方",
                subtitle: "不用切窗口，抬头就能看见还剩多久。",
                bullets: ["久坐 / 休息用颜色区分", "下拉即可暂停、重置、试看", "没有 Dock 图标，安静待命"]
            ) {
                MenuBarShot()
            },
            to: url.appendingPathComponent("05-menubar.png")
        )

        // 06 毒舌
        write(
            MarketingCard(
                eyebrow: "性格",
                title: "三档毒舌\n总有一句治得了你",
                subtitle: "文案在预警、锁屏、认输时随机出现，不重样。",
                bullets: ["温和：好好说话", "调皮：阴阳怪气", "恶毒：字字诛心"]
            ) {
                ToneShot()
            },
            to: url.appendingPathComponent("06-tone.png")
        )

        print("宣传图已输出到 \(url.path)")
        return true
    }

    // MARK: - 卡片模板

    private struct MarketingCard<Shot: View>: View {
        var eyebrow: String
        var title: String
        var subtitle: String
        var bullets: [String]
        @ViewBuilder var shot: () -> Shot

        var body: some View {
            ZStack {
                CardBackground()

                HStack(alignment: .center, spacing: 56) {
                    VStack(alignment: .leading, spacing: 0) {
                        TrackedLabel(text: eyebrow, size: 12, color: Palette.accent)

                        Text(title)
                            .font(.system(size: 52, weight: .heavy))
                            .tracking(-0.5)
                            .lineSpacing(6)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 20)

                        Text(subtitle)
                            .font(.system(size: 16, weight: .medium))
                            .lineSpacing(4)
                            .foregroundStyle(.white.opacity(0.60))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 18)

                        VStack(alignment: .leading, spacing: 13) {
                            ForEach(bullets, id: \.self) { bullet in
                                HStack(alignment: .firstTextBaseline, spacing: 11) {
                                    Circle()
                                        .fill(Palette.accent)
                                        .frame(width: 5, height: 5)
                                        .offset(y: -4)
                                    Text(bullet)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.76))
                                }
                            }
                        }
                        .padding(.top, 30)

                        Spacer(minLength: 0)

                        Hairline(color: .white.opacity(0.10))
                            .padding(.bottom, 14)

                        HStack {
                            Text("Sitizen")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.42))
                            Spacer()
                            Text("作者：夜漫长")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.32))
                        }
                    }
                    .frame(width: 470, alignment: .leading)

                    shot()
                }
                .padding(.horizontal, 84)
                .padding(.vertical, 76)
            }
            .frame(width: cardSize.width, height: cardSize.height)
        }
    }

    /// 卡片底色：深墨绿 + 左上角绿光 + 斜纹。
    private struct CardBackground: View {
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x16241D), Color(hex: 0x080E0B)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 截图背后的一团绿光：让深色的界面像「浮在光里」，而不是糊在背景上
                RadialGradient(
                    colors: [Palette.accent.opacity(0.30), Palette.accent.opacity(0.08), .clear],
                    center: UnitPoint(x: 0.74, y: 0.48),
                    startRadius: 0,
                    endRadius: 780
                )

                RadialGradient(
                    colors: [Palette.accent.opacity(0.16), .clear],
                    center: UnitPoint(x: 0.04, y: -0.05),
                    startRadius: 0,
                    endRadius: 760
                )

                RadialGradient(
                    colors: [Palette.olive.opacity(0.10), .clear],
                    center: UnitPoint(x: 1.0, y: 1.05),
                    startRadius: 0,
                    endRadius: 720
                )

                HairlineOverlay(spacing: 9, opacity: 0.030)
            }
        }
    }

    // MARK: - 截图容器

    /// 把预渲染好的界面截图按圆角「屏幕」摆出来，加描边和落影。
    ///
    /// 截图先按舒适的**设计尺寸**（例如 1200×800）渲染成位图，
    /// 再缩到卡片里的展示尺寸。这样界面内部的 k 缩放系数保持在 1 附近，
    /// 不会因为卡片变小而整体缩水。
    private struct WindowShot: View {
        var image: NSImage
        var width: CGFloat
        var height: CGFloat
        var chrome: Bool = false

        var body: some View {
            VStack(spacing: 0) {
                if chrome {
                    HStack(spacing: 7) {
                        ForEach([0, 1, 2], id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.16))
                                .frame(width: 10, height: 10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(Color(hex: 0x1C2520))
                }

                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: chrome ? height - 34 : height)
                    .clipped()
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.65), radius: 50, y: 28)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.accent.opacity(0.16))
                    .blur(radius: 60)
                    .padding(-40)
            )
        }
    }

    // MARK: - 局部素材

    /// 假的桌面背景，用来展示透明浮层。
    private struct DesktopMock: View {
        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: 0x2B3A46),
                        Color(hex: 0x3E3A55),
                        Color(hex: 0x5A4A52)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 10) {
                    ForEach(0..<5, id: \.self) { _ in
                        HStack(spacing: 10) {
                            ForEach(0..<7, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color.black.opacity(0.22))
                                    .frame(width: 62, height: 62)
                                    .overlay(
                                        Circle()
                                            .fill(Color.white.opacity(0.55))
                                            .frame(width: 20, height: 20)
                                    )
                            }
                        }
                    }
                }
                .opacity(0.85)
            }
        }
    }

    /// 菜单栏 + 展开的下拉菜单。
    private struct MenuBarShot: View {
        private let items: [(String, Bool)] = [
            ("坐着呢 · 还剩 44:12", true),
            ("开始 / 暂停", false),
            ("现在就去站一会儿", false),
            ("重新开始本轮", false),
            ("试看：预警效果", false),
            ("设置…", false)
        ]

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x22332A), Color(hex: 0x0C130F)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 0) {
                    menuBar
                    HStack {
                        Spacer()
                        menuPanel
                            .padding(.trailing, 34)
                    }
                    Spacer()
                }
            }
            .frame(width: 880, height: 430)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.55), radius: 44, y: 26)
        }

        private var menuBar: some View {
            HStack(spacing: 18) {
                Spacer()

                HStack(spacing: 8) {
                    Image(nsImage: MenuBarIcon.makePreview(width: 26, color: .white))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 26, height: 18)
                    Text("44:12")
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                )

                Text("􀊫").font(.system(size: 15)).foregroundStyle(.white.opacity(0.8))
                Text("􀙇").font(.system(size: 15)).foregroundStyle(.white.opacity(0.8))
                Text("􀆪").font(.system(size: 15)).foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .frame(height: 44)
            .background(Color.black.opacity(0.45))
        }

        private var menuPanel: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    let (label, header) = item
                    HStack {
                        Text(label)
                            .font(.system(size: 13, weight: header ? .semibold : .regular))
                            .foregroundStyle(header ? Color.white.opacity(0.5) : Color.white.opacity(0.9))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 28)

                    if index == 0 || index == 3 {
                        Hairline(color: .white.opacity(0.12))
                            .padding(.vertical, 5)
                    }
                }
            }
            .padding(6)
            .frame(width: 250)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: 0x2A2A2E).opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
        }
    }

    /// 三档文案对照。
    private struct ToneShot: View {
        private let tiers: [(String, SassLevel)] = [
            ("温和", .mild),
            ("调皮", .cheeky),
            ("恶毒", .savage)
        ]

        var body: some View {
            HStack(alignment: .top, spacing: 16) {
                ForEach(tiers, id: \.0) { name, level in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Palette.accent)

                        Hairline(color: Palette.accent.opacity(0.30))
                            .padding(.vertical, 14)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(Copy.lock(level).prefix(4)), id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .lineSpacing(3)
                                    .foregroundStyle(.white.opacity(0.80))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.white.opacity(0.055))
                                    )
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(26)
            .frame(width: 900, height: 440, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: 0x16211B))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.55), radius: 44, y: 26)
        }
    }

    // MARK: - 输出

    /// 按设计尺寸把界面渲染成位图，供卡片缩放展示。
    @MainActor
    private static func snapshot<V: View>(_ view: V, size: CGSize) -> NSImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        renderer.isOpaque = true
        return renderer.nsImage ?? NSImage(size: size)
    }

    @MainActor
    private static func write<V: View>(_ view: V, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.isOpaque = true

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            print("渲染失败：\(url.lastPathComponent)")
            return
        }
        try? png.write(to: url)
        print("  ✓ \(url.lastPathComponent)")
    }
}
