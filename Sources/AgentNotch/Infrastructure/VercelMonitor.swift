import AppKit
import CryptoKit
import Security
import UserNotifications

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
final class VercelMonitor: ObservableObject {
    @Published private(set) var deployments: [Deployment] = []
    @Published private(set) var error: String?
    @Published private(set) var connected = false
    private var task: Task<Void, Never>?
    private var tracker = DeploymentTracker()
    private var simulationTracker = DeploymentTracker()
    private let service = "dev.onilabs.agentnotch.vercel"
    private let worker: URL?
    private let slug: String
    private let session = URLSession(configuration: .ephemeral, delegate: NoRedirects(), delegateQueue: nil)
    /// Whether this finished deployment may post a notification. Injected by the app layer: the monitor reads no preferences and knows nothing about the notch.
    private let shouldNotify: (Deployment) -> Bool

    init(shouldNotify: @escaping (Deployment) -> Bool = { _ in false }) {
        self.shouldNotify = shouldNotify
        if let raw = Bundle.main.object(forInfoDictionaryKey: "VercelWorkerURL") as? String,
           let url = URL(string: raw), url.scheme == "https", url.host != nil { worker = url }
        else { worker = nil }
        slug = (Bundle.main.object(forInfoDictionaryKey: "VercelIntegrationSlug") as? String) ?? "agent-notch"
    }

    var configured: Bool { worker != nil }
    var hasCredentials: Bool { load() != nil }
    var active: Bool { connected && deployments.contains { $0.status == .pending || $0.status == .building } }

    func simulate(_ status: Deployment.Status) {
        if status == .building { simulationTracker = DeploymentTracker() }
        let item = Deployment(id: "simulation", project: "Example deploy (simulation)", repository: "example/repo", commit: "abc1234", author: "Example", status: status)
        connected = true
        deployments = [item]
        for finished in simulationTracker.update([item]) { Task { await notify(finished) } }
    }

    func start() {
        guard let credentials = load() else { return }
        task?.cancel()
        task = Task { await poll(credentials) }
    }

    func connect() {
        guard configured else { error = "Vercel integration is not configured."; return }
        guard !hasCredentials else { start(); return }
        task?.cancel()
        task = Task {
            do {
                let state = try randomHex(), verifier = try randomHex()
                let challenge = SHA256.hash(data: Data(verifier.utf8)).map { String(format: "%02x", $0) }.joined()
                let credentials = Credentials(state: state, verifier: verifier)
                _ = try await request("start", credentials: credentials, method: "POST", headers: ["X-Pairing-Challenge": challenge])
                try save(credentials)
                var components = URLComponents(string: "https://vercel.com/integrations/\(slug)/new")!
                components.queryItems = [URLQueryItem(name: "state", value: state)]
                guard let url = components.url else { throw MonitorError.invalidResponse }
                NSWorkspace.shared.open(url)
                await poll(credentials)
            } catch { self.error = error.localizedDescription }
        }
    }

    func disconnect() {
        task?.cancel()
        guard let credentials = load() else { return }
        task = Task {
            do {
                _ = try await request("disconnect", credentials: credentials, method: "POST")
                deleteCredentials()
                connected = false; deployments = []; tracker = DeploymentTracker(); error = nil
            } catch { self.error = error.localizedDescription }
        }
    }

    private func poll(_ credentials: Credentials) async {
        // The tracker starts empty on every run: a deployment that finished while the app was closed must not be announced.
        while !Task.isCancelled {
            do {
                let status = try JSONDecoder().decode(ConnectionStatus.self, from: try await request("status", credentials: credentials))
                connected = status.status == "connected"
                if connected {
                    var items: [Deployment] = []
                    var cursor: Int64?
                    repeat {
                        let data = try await request("deployments", credentials: credentials, until: cursor)
                        let page = try JSONDecoder().decode(DeploymentPage.self, from: data)
                        items.append(contentsOf: page.deployments.map(\.deployment))
                        cursor = try page.nextPage(after: cursor)
                    } while cursor != nil
                    var seen = Set<String>()
                    items = items.filter { seen.insert($0.id).inserted }
                    deployments = items
                    let completed = tracker.update(items)
                    for deployment in completed { await notify(deployment) }
                }
                error = nil
            } catch MonitorError.expired {
                deleteCredentials(); connected = false; self.error = MonitorError.expired.localizedDescription
                return
            } catch { connected = false; self.error = error.localizedDescription }
            try? await Task.sleep(for: .seconds(30))
        }
    }

    private func notify(_ deployment: Deployment) async {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        guard shouldNotify(deployment) else { return }
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Vercel · \(deployment.project)"
        content.body = [deployment.status.label, deployment.repository, deployment.commit, deployment.author].compactMap { $0 }.joined(separator: " · ")
        // A build finishing is ambient news, not the user's turn: deliver it passively, with no sound or banner that demands attention.
        content.interruptionLevel = .passive
        try? await center.add(UNNotificationRequest(identifier: "vercel-\(deployment.id)", content: content, trigger: nil))
    }

    private func request(_ path: String, credentials: Credentials, method: String = "GET", headers: [String: String] = [:], until: Int64? = nil) async throws -> Data {
        guard let worker, var components = URLComponents(url: worker.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { throw MonitorError.invalidResponse }
        components.queryItems = [URLQueryItem(name: "state", value: credentials.state)]
        if let until { components.queryItems?.append(URLQueryItem(name: "until", value: String(until))) }
        guard let url = components.url else { throw MonitorError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(credentials.verifier)", forHTTPHeaderField: "Authorization")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MonitorError.requestFailed }
        if http.statusCode == 401 || http.statusCode == 410 { throw MonitorError.expired }
        guard (200..<300).contains(http.statusCode) else { throw MonitorError.requestFailed }
        return data
    }

    private struct Credentials: Codable { let state: String; let verifier: String }
    private struct ConnectionStatus: Decodable { let status: String }
    private enum MonitorError: LocalizedError {
        case invalidResponse, requestFailed, keychain, random, expired
        var errorDescription: String? {
            switch self { case .invalidResponse: return "Invalid Vercel response."; case .requestFailed: return "Could not connect to Vercel."; case .keychain: return "Could not access Keychain."; case .random: return "Could not create secure credentials."; case .expired: return "Vercel connection expired. Please reconnect." }
        }
    }
    private func randomHex() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw MonitorError.random }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
    private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "connection"] }
    private func save(_ credentials: Credentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data; item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw MonitorError.keychain }
        } else if status != errSecSuccess { throw MonitorError.keychain }
    }
    private func load() -> Credentials? {
        var item = query; item[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(item as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: data)
    }
    private func deleteCredentials() { SecItemDelete(query as CFDictionary) }
}

struct DeploymentPage: Decodable {
    enum PaginationError: Error { case repeatedCursor }
    struct Page: Decodable { let next: Int64? }
    struct Item: Decodable {
        let uid: String
        let name: String
        let state: String
        let meta: [String: String]?
        private enum CodingKeys: String, CodingKey { case uid, name, state, meta }
        private struct MetaKey: CodingKey {
            let stringValue: String
            let intValue: Int? = nil
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { return nil }
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            uid = try values.decode(String.self, forKey: .uid)
            name = try values.decode(String.self, forKey: .name)
            state = try values.decode(String.self, forKey: .state)
            if let metadata = try? values.nestedContainer(keyedBy: MetaKey.self, forKey: .meta) {
                meta = Dictionary(uniqueKeysWithValues: metadata.allKeys.compactMap { key in
                    (try? metadata.decode(String.self, forKey: key)).map { (key.stringValue, $0) }
                })
            } else { meta = nil }
        }
        var deployment: Deployment {
            let status: Deployment.Status
            switch state { case "QUEUED", "INITIALIZING": status = .pending; case "BUILDING": status = .building; case "READY": status = .ready; case "ERROR": status = .failed; case "CANCELED": status = .canceled; default: status = .unknown }
            return Deployment(id: uid, project: name, repository: meta?["githubRepo"] ?? meta?["gitlabProjectName"] ?? meta?["bitbucketRepoName"], commit: meta?["githubCommitSha"] ?? meta?["gitlabCommitSha"] ?? meta?["bitbucketCommitSha"], author: meta?["githubCommitAuthorName"] ?? meta?["gitlabCommitAuthorName"] ?? meta?["bitbucketCommitAuthorName"], status: status)
        }
    }
    let deployments: [Item]
    let pagination: Page?

    func nextPage(after cursor: Int64?) throws -> Int64? {
        let next = pagination?.next
        if let next, next == cursor { throw PaginationError.repeatedCursor }
        return next
    }
}
