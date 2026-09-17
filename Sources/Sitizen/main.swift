import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// 开发工具入口：--selftest / --render-previews / --snapshot
let handledByDevTool = MainActor.assumeIsolated { () -> Bool in
    if SelfTest.runIfRequested() { return true }
    if AppIconRenderer.runIfRequested() { return true }
    if AppIconRenderer.runDMGBackgroundIfRequested() { return true }
    if PreviewRenderer.runIfRequested() { return true }
    if MarketingRenderer.runIfRequested() { return true }
    if PreviewRenderer.runSnapshotIfRequested() { return true }
    return false
}
if handledByDevTool {
    exit(0)
}

// 顶层 let 是全局变量，保证 delegate 在整个进程生命周期内存活（NSApplication.delegate 是 weak）。
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
