import AppKit
import Foundation

/// 菜单栏图标：把 App 图标中间那个标记抽出来做成单色剪影。
///
/// 几何和 `ButtMark` 完全一致（同样大小的两瓣 + 同样形状的缝），
/// 用 template image —— 浅色菜单栏里是纯黑，深色菜单栏自动转白。
enum MenuBarIcon {

    /// 剪影的高宽比：0.58 / 0.816
    private static let aspect: CGFloat = 0.7108

    static func make(width: CGFloat = 17) -> NSImage {
        let size = NSSize(width: width, height: width * aspect)
        let image = NSImage(size: size, flipped: false) { _ in
            draw(in: size, color: .black)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// 设计走查用：按指定颜色放大渲染。
    static func makePreview(width: CGFloat, color: NSColor) -> NSImage {
        let size = NSSize(width: width, height: width * aspect)
        return NSImage(size: size, flipped: false) { _ in
            draw(in: size, color: color)
            return true
        }
    }

    private static func draw(in size: NSSize, color: NSColor) {
        guard let context = NSGraphicsContext.current else { return }
        let w = size.width
        let center = NSPoint(x: w / 2, y: size.height / 2)

        // 与 ButtMark 同比例：lobe 0.58s / spread 0.118s，其中 s = w / 0.816
        let radius = w * 0.3554
        let spread = w * 0.1446

        let dy = max(0, radius * radius - spread * spread).squareRoot()
        let angle = atan2(dy, spread) * 180 / .pi

        let body = NSBezierPath()
        body.appendArc(
            withCenter: NSPoint(x: center.x - spread, y: center.y),
            radius: radius,
            startAngle: angle,
            endAngle: 360 - angle
        )
        body.appendArc(
            withCenter: NSPoint(x: center.x + spread, y: center.y),
            radius: radius,
            startAngle: 180 + angle,
            endAngle: 180 - angle + 360
        )
        body.close()

        color.setFill()
        body.fill()

        // 缝：上尖下宽、两侧内凹，和 ButtMark 的 CleftShape 是同一个形状。
        // 注意 AppKit 是 y 轴向上，所以缝要往 center.y 的「下方」偏移。
        let halfWidth = w * 0.0644
        let halfHeight = w * 0.1593
        let cleftCenterY = center.y - w * 0.2328
        let tip = NSPoint(x: center.x, y: cleftCenterY + halfHeight)
        let rightBase = NSPoint(x: center.x + halfWidth, y: cleftCenterY - halfHeight)
        let leftBase = NSPoint(x: center.x - halfWidth, y: cleftCenterY - halfHeight)

        /// 用三次贝塞尔等价还原 CleftShape 里的二次曲线
        func quadControls(from start: NSPoint, to end: NSPoint, control: NSPoint) -> (NSPoint, NSPoint) {
            let c1 = NSPoint(
                x: start.x + (control.x - start.x) * 2 / 3,
                y: start.y + (control.y - start.y) * 2 / 3
            )
            let c2 = NSPoint(
                x: end.x + (control.x - end.x) * 2 / 3,
                y: end.y + (control.y - end.y) * 2 / 3
            )
            return (c1, c2)
        }

        let rightControl = NSPoint(x: center.x + halfWidth * 0.40, y: cleftCenterY)
        let leftControl = NSPoint(x: center.x - halfWidth * 0.40, y: cleftCenterY)
        let right = quadControls(from: tip, to: rightBase, control: rightControl)
        let left = quadControls(from: leftBase, to: tip, control: leftControl)

        let cleft = NSBezierPath()
        cleft.move(to: tip)
        cleft.curve(to: rightBase, controlPoint1: right.0, controlPoint2: right.1)
        cleft.line(to: leftBase)
        cleft.curve(to: tip, controlPoint1: left.0, controlPoint2: left.1)
        cleft.close()

        context.saveGraphicsState()
        context.compositingOperation = .destinationOut
        cleft.fill()
        context.restoreGraphicsState()
    }
}
