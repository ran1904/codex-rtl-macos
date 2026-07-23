import AppKit
import Foundation
import CodexRTLCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var primaryMenuItem: NSMenuItem!
    private var disableMenuItem: NSMenuItem!
    private var checkMenuItem: NSMenuItem!
    private var errorMenuItem: NSMenuItem!
    private var controller: RTLController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenu()

        do {
            let controller = try RTLController()
            self.controller = controller
            controller.onStateChange = { [weak self] state in
                self?.render(state)
            }
            render(.connecting)
            controller.start()
        } catch {
            render(.failure(error.localizedDescription))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // The explicit quit action removes the injected layer before termination.
        // A system-forced quit cannot safely await renderer cleanup.
    }

    private func configureMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.toolTip = "Codex RTL Helper"

        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        primaryMenuItem = NSMenuItem(
            title: "Enable RTL",
            action: #selector(primaryAction),
            keyEquivalent: ""
        )
        primaryMenuItem.target = self
        menu.addItem(primaryMenuItem)

        disableMenuItem = NSMenuItem(
            title: "Disable RTL",
            action: #selector(disableRTL),
            keyEquivalent: ""
        )
        disableMenuItem.target = self
        menu.addItem(disableMenuItem)

        checkMenuItem = NSMenuItem(
            title: "Check Connection",
            action: #selector(checkConnection),
            keyEquivalent: "r"
        )
        checkMenuItem.target = self
        menu.addItem(checkMenuItem)

        errorMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        errorMenuItem.isEnabled = false
        errorMenuItem.isHidden = true
        menu.addItem(errorMenuItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Codex RTL Helper",
            action: #selector(quitHelper),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func render(_ state: RTLState) {
        statusMenuItem.title = state.statusTitle
        errorMenuItem.isHidden = true

        switch state {
        case .codexClosed:
            primaryMenuItem.title = "Open Codex with RTL"
            primaryMenuItem.isEnabled = true
            disableMenuItem.isEnabled = false
        case .needsRestart:
            primaryMenuItem.title = "Restart with RTL…"
            primaryMenuItem.isEnabled = true
            disableMenuItem.isEnabled = false
        case .connecting:
            primaryMenuItem.title = "Connecting…"
            primaryMenuItem.isEnabled = false
            disableMenuItem.isEnabled = false
        case .connectedInactive:
            primaryMenuItem.title = "Enable RTL"
            primaryMenuItem.isEnabled = true
            disableMenuItem.isEnabled = false
        case .active:
            primaryMenuItem.title = "RTL is Active"
            primaryMenuItem.isEnabled = false
            disableMenuItem.isEnabled = true
        case let .failure(message):
            primaryMenuItem.title = "Try Again"
            primaryMenuItem.isEnabled = true
            disableMenuItem.isEnabled = false
            errorMenuItem.title = message
            errorMenuItem.isHidden = false
        }

        let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: state.statusTitle)
        image?.isTemplate = false
        statusItem.button?.image = image
        statusItem.button?.contentTintColor = state.tintColor
        statusItem.button?.toolTip = "Codex RTL Helper: \(state.statusTitle)"
    }

    @objc private func primaryAction() {
        guard let controller else { return }
        switch controller.state {
        case .needsRestart:
            guard confirmRestart() else { return }
            Task { await controller.restartCodexWithRTL() }
        case .codexClosed:
            Task { await controller.launchCodexWithRTL() }
        default:
            Task { await controller.enableRTL() }
        }
    }

    @objc private func disableRTL() {
        guard let controller else { return }
        Task { await controller.disableRTL() }
    }

    @objc private func checkConnection() {
        guard let controller else { return }
        Task { await controller.refresh() }
    }

    @objc private func quitHelper() {
        guard let controller else {
            NSApp.terminate(nil)
            return
        }
        Task {
            await controller.stop()
            NSApp.terminate(nil)
        }
    }

    private func confirmRestart() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restart Codex with RTL?"
        alert.informativeText = "Save any unsent draft first. Codex will quit and reopen, while your existing conversations remain in your account."
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
