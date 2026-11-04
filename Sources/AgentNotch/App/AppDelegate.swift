import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SessionStore()
    private let viewModel = NotchViewModel()
    /// Notifications belong to the app layer: quiet unless the user asked for them and the notch is already open.
    private lazy var vercel = VercelMonitor(shouldNotify: { [weak self] _ in
        guard let self else { return false }
        return Preferences.vercelNotificationsEnabled && !viewModel.hovering && store.approvals.isEmpty
    })
    private var server: HookServer?
    private var panelController: NotchPanelController?
    private var statusMenu: StatusMenu?
    private let debug = ProcessInfo.processInfo.environment["AGENT_NOTCH_DEBUG"] == "1"

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.onSessionFinished = { Sounds.finished($0.agent) }
        store.onApprovalRequested = { _ in Sounds.approvalNeeded() }
        store.onQuestionAsked = { _ in Sounds.approvalNeeded() }
        store.askRetention = Preferences.yourTurnFor
        NotificationCenter.default.addObserver(forName: Preferences.changed, object: nil, queue: .main) { [store] _ in
            MainActor.assumeIsolated { store.askRetention = Preferences.yourTurnFor }
        }

        let server = HookServer(store: store, vercel: vercel, debug: debug)
        do {
            try server.start()
        } catch {
            FileHandle.standardError.write(Data("Agent Notch: cannot start server: \(error)\n".utf8))
        }
        self.server = server

        statusMenu = StatusMenu(store: store, vercel: vercel)
        panelController = NotchPanelController(store: store, viewModel: viewModel, vercel: vercel)
        panelController?.show()
        // After launch finishes, so the notch is already on screen behind the dialog.
        DispatchQueue.main.async { ConnectAgents.promptIfNeeded() }
    }

    /// Polling starts once the app is actually active, so a Keychain prompt has a focused window the user can type into.
    func applicationDidBecomeActive(_ notification: Notification) {
        guard !debug else { return }
        vercel.adoptExistingIfNeeded()
        vercel.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.resolveAll(decision: .terminal)
        server?.stop()
    }
}
