import Foundation
import Network

/// Loopback-only HTTP server receiving agent hook events and approval requests.
final class HookServer: @unchecked Sendable {
    static let defaultPort: UInt16 = 47823

    private let port: UInt16
    private let debug: Bool
    private let store: SessionStore
    private let queue = DispatchQueue(label: "dev.onilabs.agentnotch.server")
    private var listener: NWListener?

    init(store: SessionStore, port: UInt16? = nil, debug: Bool = false) {
        self.store = store
        self.debug = debug
        let env = ProcessInfo.processInfo.environment["AGENT_NOTCH_PORT"].flatMap(UInt16.init)
        self.port = port ?? env ?? Self.defaultPort
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [port] state in
            if case .failed(let error) = state {
                FileHandle.standardError.write(Data("HookServer failed on port \(port): \(error)\n".utf8))
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: Connections

    private func accept(_ connection: NWConnection) {
        guard Self.isLoopback(connection.endpoint) else {
            connection.cancel()
            return
        }
        let wrapper = HTTPConnection(connection: connection) { [weak self] request, conn in
            self?.route(request, on: conn)
        }
        wrapper.start(queue: queue)
    }

    private static func isLoopback(_ endpoint: NWEndpoint) -> Bool {
        guard case .hostPort(let host, _) = endpoint else { return false }
        switch host {
        case .ipv4(let address): return address.isLoopback
        case .ipv6(let address): return address.isLoopback
        default: return false
        }
    }

    // MARK: Routing

    private func route(_ request: HTTPRequest, on conn: HTTPConnection) {
        let parts = request.path.split(separator: "?").first.map(String.init) ?? request.path
        let segments = parts.split(separator: "/").map(String.init)

        switch (request.method, segments.first ?? "") {
        case ("GET", "health"):
            conn.send(status: 200, body: "ok", contentType: "text/plain")

        case ("POST", "event") where segments.count == 2:
            guard let agent = AgentKind(rawValue: segments[1]),
                  var event = HookPayloadDecoder.decode(agent: agent, data: request.body) else {
                conn.send(status: 204, body: "")
                return
            }
            event.terminal = Self.terminal(from: request)
            conn.send(status: 204, body: "")
            Task { @MainActor [store] in store.ingest(event: event) }

        case ("POST", "approve") where segments.count == 2:
            handleApproval(agentName: segments[1], body: request.body, terminal: Self.terminal(from: request), on: conn)

        case (_, "debug") where debug:
            handleDebug(request, segments: segments, on: conn)

        default:
            conn.send(status: 404, body: "{\"error\":\"not found\"}")
        }
    }

    private static func terminal(from request: HTTPRequest) -> TerminalRef? {
        guard let bundle = request.headers["x-an-bundle"], !bundle.isEmpty else { return nil }
        return TerminalRef(bundleId: bundle, tty: request.headers["x-an-tty"].flatMap { $0.isEmpty ? nil : $0 })
    }

    private func handleApproval(agentName: String, body: Data, terminal: TerminalRef?, on conn: HTTPConnection) {
        guard let agent = AgentKind(rawValue: agentName),
              let event = HookPayloadDecoder.decode(agent: agent, data: body) else {
            conn.send(status: 200, body: "{\"decision\":\"terminal\"}")
            return
        }
        let approval = ApprovalRequest(
            agent: agent,
            sessionId: event.sessionId,
            project: displayProjectName(from: event.cwd),
            toolName: event.toolName ?? "Tool",
            summary: event.toolSummary ?? "")
        conn.watchDisconnect { [store] in
            Task { @MainActor in store.resolve(id: approval.id, decision: .terminal) }
        }
        Task { @MainActor [store] in
            // Make sure the session shows up with its cwd before it flips to waiting.
            store.ingest(event: HookEvent(
                agent: agent, name: "SessionStart", sessionId: event.sessionId, cwd: event.cwd,
                toolName: nil, toolSummary: nil, prompt: nil, message: nil, lastAssistantMessage: nil,
                terminal: terminal))
            let decision = await store.requestApproval(approval)
            conn.send(status: 200, body: "{\"decision\":\"\(decision.rawValue)\"}")
        }
    }

    // MARK: Debug (only when AGENT_NOTCH_DEBUG=1)

    private func handleDebug(_ request: HTTPRequest, segments: [String], on conn: HTTPConnection) {
        if request.method == "POST", segments.count == 3, segments[1] == "resolve-all",
           let decision = Decision(rawValue: segments[2]) {
            Task { @MainActor [store] in
                let count = store.approvals.count
                store.resolveAll(decision: decision)
                conn.send(status: 200, body: "{\"resolved\":\(count)}")
            }
        } else if request.method == "GET", segments.count == 2, segments[1] == "state" {
            Task { @MainActor [store] in
                let sessions = store.sessions.values.sorted { $0.id < $1.id }.map { s -> [String: Any] in
                    ["id": s.id, "agent": s.agent.rawValue, "project": s.projectName,
                     "status": s.status.label, "message": s.lastMessage ?? ""]
                }
                let object: [String: Any] = ["sessions": sessions, "pendingApprovals": store.approvals.count]
                let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data("{}".utf8)
                conn.send(status: 200, body: String(decoding: data, as: UTF8.self))
            }
        } else {
            conn.send(status: 404, body: "{\"error\":\"not found\"}")
        }
    }
}
