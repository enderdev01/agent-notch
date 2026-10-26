import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SessionStore()
    private let viewModel = NotchViewModel()
    private var server: HookServer?
    private var panelController: NotchPanelController?
    private var statusMenu: StatusMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.onSessionFinished = { Sounds.finished($0.agent) }
        store.onApprovalRequested = { _ in Sounds.approvalNeeded() }
        store.askRetention = Preferences.yourTurnFor
        NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { [store] _ in
            MainActor.assumeIsolated { store.askRetention = Preferences.yourTurnFor }
        }

        let debug = ProcessInfo.processInfo.environment["AGENT_NOTCH_DEBUG"] == "1"
        let server = HookServer(store: store, debug: debug)
        do {
            try server.start()
        } catch {
            FileHandle.standardError.write(Data("Agent Notch: cannot start server: \(error)\n".utf8))
        }
        self.server = server

        statusMenu = StatusMenu(store: store)
        panelController = NotchPanelController(store: store, viewModel: viewModel)
        panelController?.show()
        // After launch finishes, so the notch is already on screen behind the dialog.
        DispatchQueue.main.async { ConnectAgents.promptIfNeeded() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.resolveAll(decision: .terminal)
        server?.stop()
    }
}
