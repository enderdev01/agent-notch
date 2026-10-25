import Foundation
import Network

/// One inbound TCP connection speaking a single HTTP/1.1 request/response (Connection: close).
final class HTTPConnection: @unchecked Sendable {
    private let connection: NWConnection
    private var buffer = Data()
    private let onRequest: @Sendable (HTTPRequest, HTTPConnection) -> Void

    init(connection: NWConnection, onRequest: @escaping @Sendable (HTTPRequest, HTTPConnection) -> Void) {
        self.connection = connection
        self.onRequest = onRequest
    }

    func start(queue: DispatchQueue) {
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.connection.cancel() }
        }
        connection.start(queue: queue)
        receive()
    }

    func send(status: Int, body: String, contentType: String = "application/json") {
        let reason = [200: "OK", 204: "No Content", 400: "Bad Request", 404: "Not Found"][status] ?? "Error"
        let payload = Data(body.utf8)
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: \(contentType)\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + payload, completion: .contentProcessed { [connection] _ in
            connection.cancel()
        })
    }

    /// Invokes `onClose` when the peer goes away (used to abandon held approval requests).
    func watchDisconnect(_ onClose: @escaping @Sendable () -> Void) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] _, _, isComplete, error in
            if isComplete || error != nil {
                onClose()
                return
            }
            self?.watchDisconnect(onClose)
        }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [self] data, _, isComplete, error in
            if let data { buffer.append(data) }
            if error != nil {
                connection.cancel()
                return
            }
            switch HTTPParser.parse(buffer) {
            case .complete(let request):
                onRequest(request, self)
            case .invalid:
                send(status: 400, body: "{\"error\":\"bad request\"}")
            case .incomplete:
                if isComplete {
                    connection.cancel()
                } else {
                    receive()
                }
            }
        }
    }
}
