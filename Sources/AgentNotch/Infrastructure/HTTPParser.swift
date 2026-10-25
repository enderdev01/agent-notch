import Foundation

struct HTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

enum HTTPParseResult {
    case incomplete
    case invalid
    case complete(HTTPRequest)
}

/// Minimal HTTP/1.1 request parser: request line, headers, Content-Length body.
enum HTTPParser {
    static let maxRequestBytes = 1_048_576
    private static let separator = Data("\r\n\r\n".utf8)

    static func parse(_ buffer: Data) -> HTTPParseResult {
        guard let range = buffer.range(of: separator) else {
            return buffer.count > 16_384 ? .invalid : .incomplete
        }
        guard let head = String(data: buffer[buffer.startIndex..<range.lowerBound], encoding: .utf8) else {
            return .invalid
        }
        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return .invalid }

        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[line.startIndex..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        let length = Int(headers["content-length"] ?? "0") ?? -1
        guard length >= 0, length <= maxRequestBytes else { return .invalid }

        let bodyStart = range.upperBound
        guard buffer.endIndex - bodyStart >= length else { return .incomplete }
        let body = buffer[bodyStart..<(bodyStart + length)]
        return .complete(HTTPRequest(
            method: String(requestLine[0]).uppercased(),
            path: String(requestLine[1]),
            headers: headers,
            body: Data(body)))
    }
}
