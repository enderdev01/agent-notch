import AppKit
import ServiceManagement

/// Menu bar item with the few toggles the app needs.
@MainActor
final class StatusMenu: NSObject {
    private let store: SessionStore
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let pauseItem = NSMenuItem(title: L("Pause approvals (always fall back to terminal)"), action: nil, keyEquivalent: "")
    private let soundItem = NSMenuItem(title: L("Play sound when an agent finishes"), action: nil, keyEquivalent: "")
    private let approvalSoundItem = NSMenuItem(title: L("Play sound when approval is needed"), action: nil, keyEquivalent: "")
    private let idleItem = NSMenuItem(title: L("Show mascot when idle"), action: nil, keyEquivalent: "")
    private let volumeItem = NSMenuItem(title: L("Sound volume"), action: nil, keyEquivalent: "")
    private let sleepItem = NSMenuItem(title: L("Mascot falls asleep after"), action: nil, keyEquivalent: "")
    private let yourTurnItem = NSMenuItem(title: L("\"Your turn\" mark lasts"), action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: L("Launch at login"), action: nil, keyEquivalent: "")
    private let languageItem = NSMenuItem(title: L("Language"), action: nil, keyEquivalent: "")

    private static let volumeChoices: [(title: String, value: Double)] = [(L("Quiet"), 0.15), (L("Normal"), 0.3), (L("Loud"), 0.6)]
    private static let sleepChoices: [(title: String, value: Double)] = [(L("30 seconds"), 30), (L("1 minute"), 60), (L("3 minutes"), 180)]
    /// Language names are written in their own language; code "" follows the system.
    private static let languageChoices: [(title: String, code: String)] = [
        (L("Match system language"), ""), ("English", "en"), ("Español", "es"), ("Deutsch", "de"),
    ]
    private static let yourTurnChoices: [(title: String, value: Double)] = [
        (L("Off"), 0), (L("2 minutes"), 120), (L("5 minutes"), 300), (L("15 minutes"), 900), (L("30 minutes"), 1800),
    ]

    init(store: SessionStore) {
        self.store = store
        super.init()
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                                     accessibilityDescription: "Agent Notch")
        let menu = NSMenu()
        pauseItem.target = self; pauseItem.action = #selector(togglePause)
        soundItem.target = self; soundItem.action = #selector(toggleSound)
        approvalSoundItem.target = self; approvalSoundItem.action = #selector(toggleApprovalSound)
        idleItem.target = self; idleItem.action = #selector(toggleIdle)
        loginItem.target = self; loginItem.action = #selector(toggleLogin)
        volumeItem.submenu = choiceMenu(Self.volumeChoices, action: #selector(pickVolume(_:)))
        sleepItem.submenu = choiceMenu(Self.sleepChoices, action: #selector(pickSleep(_:)))
        yourTurnItem.submenu = choiceMenu(Self.yourTurnChoices, action: #selector(pickYourTurn(_:)))
        languageItem.submenu = languageMenu()
        let quit = NSMenuItem(title: L("Quit Agent Notch"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        let connect = NSMenuItem(title: L("Connect agents…"), action: #selector(connectAgents), keyEquivalent: "")
        connect.target = self
        [connect, .separator(), pauseItem, .separator(), soundItem, approvalSoundItem, volumeItem, .separator(), idleItem, sleepItem,
         yourTurnItem, .separator(), languageItem, loginItem, .separator(), quit].forEach(menu.addItem)
        menu.delegate = self
        item.menu = menu
    }

    private func choiceMenu(_ choices: [(title: String, value: Double)], action: Selector) -> NSMenu {
        let menu = NSMenu()
        for choice in choices {
            let entry = NSMenuItem(title: choice.title, action: action, keyEquivalent: "")
            entry.target = self
            entry.representedObject = choice.value
            menu.addItem(entry)
        }
        return menu
    }

    private func languageMenu() -> NSMenu {
        let menu = NSMenu()
        for choice in Self.languageChoices {
            let entry = NSMenuItem(title: choice.title, action: #selector(pickLanguage(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = choice.code
            menu.addItem(entry)
        }
        return menu
    }

    /// Checkmark on the entry whose value matches the current preference.
    private func mark(_ menu: NSMenu?, current: Double) {
        menu?.items.forEach { entry in
            entry.state = (entry.representedObject as? Double).map { abs($0 - current) < 0.001 } == true ? .on : .off
        }
    }

    @objc private func toggleApprovalSound() { Preferences.approvalSoundEnabled.toggle() }
    @objc private func toggleIdle() { Preferences.showIdleMascot.toggle() }

    @objc private func pickVolume(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        Preferences.soundVolume = Float(value)
    }

    @objc private func pickYourTurn(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        Preferences.yourTurnFor = value
    }

    @objc private func pickSleep(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        Preferences.sleepAfter = value
    }

    @objc private func togglePause() {
        store.approvalsPaused.toggle()
        if store.approvalsPaused { store.resolveAll(decision: .terminal) }
    }

    @objc private func toggleSound() { Preferences.soundEnabled.toggle() }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = L("Could not change launch at login")
            alert.informativeText = "\(error.localizedDescription)\n\n" + L("This only works when running the bundled app (make app).")
            alert.runModal()
        }
    }

    @objc private func connectAgents() { ConnectAgents.run() }

    @objc private func pickLanguage(_ sender: NSMenuItem) {
        let code = sender.representedObject as? String ?? ""
        guard code != (Preferences.languageOverride.map { String($0.prefix(2)) } ?? "") else { return }
        // Strings are read once at launch, so applying a language means restarting; say what that costs.
        let alert = NSAlert()
        alert.messageText = L("Restart Agent Notch?")
        alert.informativeText = L("Agent Notch will restart to apply the language. Pending approvals go back to the terminal, and sessions reappear with their next activity.")
        alert.addButton(withTitle: L("Restart"))
        alert.addButton(withTitle: L("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Preferences.languageOverride = code.isEmpty ? nil : code
        // Start the new instance a moment after this one exits, so the hook port is free again.
        let relauncher = Process()
        relauncher.executableURL = URL(fileURLWithPath: "/bin/sh")
        relauncher.arguments = ["-c", "sleep 0.8; /usr/bin/open -n \"$1\"", "sh", Bundle.main.bundlePath]
        try? relauncher.run()
        NSApp.terminate(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

extension StatusMenu: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        pauseItem.state = store.approvalsPaused ? .on : .off
        soundItem.state = Preferences.soundEnabled ? .on : .off
        approvalSoundItem.state = Preferences.approvalSoundEnabled ? .on : .off
        idleItem.state = Preferences.showIdleMascot ? .on : .off
        mark(volumeItem.submenu, current: Double(Preferences.soundVolume))
        mark(sleepItem.submenu, current: Preferences.sleepAfter)
        mark(yourTurnItem.submenu, current: Preferences.yourTurnFor)
        let bundled = Bundle.main.bundleURL.pathExtension == "app"
        loginItem.isEnabled = bundled
        loginItem.state = bundled && SMAppService.mainApp.status == .enabled ? .on : .off
        loginItem.title = bundled ? L("Launch at login") : L("Launch at login (needs the .app bundle)")
        languageItem.isEnabled = bundled
        let current = Preferences.languageOverride.map { String($0.prefix(2)) } ?? ""
        languageItem.submenu?.items.forEach { $0.state = ($0.representedObject as? String) == current ? .on : .off }
    }
}
