import AppKit
import Foundation

/// 监听屏幕休眠 / 唤醒 / 锁屏 / 解锁，用于自动暂停计时。
final class SystemActivityWatcher {
    var onAway: (() -> Void)?
    var onReturn: (() -> Void)?

    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.onAway?()
            }
        )
        workspaceObservers.append(
            workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.onReturn?()
            }
        )
        workspaceObservers.append(
            workspace.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.onAway?()
            }
        )
        workspaceObservers.append(
            workspace.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.onReturn?()
            }
        )

        // 屏幕锁定 / 解锁走 DistributedNotificationCenter（系统未公开但稳定的通知名）。
        let distributed = DistributedNotificationCenter.default()
        distributedObservers.append(
            distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
                self?.onAway?()
            }
        )
        distributedObservers.append(
            distributed.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
                self?.onReturn?()
            }
        )
    }

    deinit {
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { workspace.removeObserver($0) }
        let distributed = DistributedNotificationCenter.default()
        distributedObservers.forEach { distributed.removeObserver($0) }
    }
}
