import Foundation

/// Turns raw agent output into short, readable text for the peek and the rows.
enum ReplyText {
    /// A reply, reduced to one line: markdown removed, and the closing ask when the agent is waiting on
    /// the user, otherwise the opening line (joined with the first list item when it ends in a colon).
    struct Snippet: Equatable {
        let text: String
        let asksUser: Bool
    }

    static func snippet(_ reply: String, limit: Int = 140) -> Snippet {
        let lines = reply.split(whereSeparator: \.isNewline)
            .map { clean(String($0)) }
            .filter { !$0.isEmpty }
        guard let first = lines.first, let last = lines.last else { return Snippet(text: "", asksUser: false) }

        let asks = asksUser(last)
        var text = asks ? last : first
        if !asks, text.hasSuffix(":"), lines.count > 1 { text += " " + lines[1] }
        return Snippet(text: clip(text, limit), asksUser: asks)
    }

    /// Text for the hover detail: inline markdown rendered (bold, code), links reduced to their label,
    /// bullets and headings tidied, and a long reply shortened in the middle so its ending stays visible.
    static func detail(_ text: String, limit: Int = 700) -> AttributedString {
        var plain = excerpt(text, limit: limit)
        plain = plain.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"(?m)^(\s*)[-*] "#, with: "$1• ", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"(?m)^#{1,6}\s*"#, with: "", options: .regularExpression)
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: plain, options: options)) ?? AttributedString(plain)
    }

    /// Keeps the start and the end of a long text (60% / 40% of `limit`), cutting at word boundaries.
    static func excerpt(_ text: String, limit: Int) -> String {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > limit else { return text }
        let head = String(text.prefix(limit * 6 / 10))
        let tail = String(text.suffix(limit * 4 / 10))
        let headCut = head.lastIndex(where: \.isWhitespace).map { String(head[..<$0]) } ?? head
        let tailCut = tail.firstIndex(where: \.isWhitespace).map { String(tail[tail.index(after: $0)...]) } ?? tail
        return headCut + " … " + tailCut
    }

    /// shortcut: a phrase list plus "?", not language understanding; extend `askPhrases` when it misses.
    static func asksUser(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("?") || askPhrases.contains { lower.contains($0) }
    }

    private static let askPhrases = [
        "your call", "let me know", "need your", "your input", "please confirm", "waiting for you",
        "dime", "confirma", "necesito tu", "tú decides", "tu decisión",
    ]

    /// Human text for the error codes Claude Code reports in `StopFailure`; other text passes through.
    static func error(_ raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "Turn ended with an error"
        }
        return errorTexts[raw] ?? raw
    }

    /// True when `raw` is one of the known error codes (the code is then worth showing next to its text).
    static func isKnownError(_ raw: String?) -> Bool { raw.map { errorTexts[$0] != nil } ?? false }

    private static let errorTexts: [String: String] = [
        "rate_limit": "Rate limit reached",
        "overloaded": "The model is overloaded",
        "authentication_failed": "Not signed in",
        "oauth_org_not_allowed": "This organization is not allowed",
        "account_on_hold": "Account on hold",
        "billing_error": "Billing problem",
        "invalid_request": "Invalid request",
        "model_not_found": "Model not found",
        "server_error": "Server error",
        "max_output_tokens": "Hit the output limit",
        "cloud_credential_error": "Cloud credentials problem",
        "unknown": "Unknown error",
    ]

    // MARK: Private

    /// One markdown line without its bullet, heading, quote or emphasis marks.
    private static func clean(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("```") { return "" }
        while let mark = text.first, "#>-*•".contains(mark) { text.removeFirst(); text = text.trimmingCharacters(in: .whitespaces) }
        if let dot = text.firstIndex(of: "."), text[..<dot].allSatisfy(\.isNumber), !text[..<dot].isEmpty {
            text = String(text[text.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
        }
        for noise in ["**", "__", "`"] { text = text.replacingOccurrences(of: noise, with: "") }
        return text
    }

    private static func clip(_ text: String, _ limit: Int) -> String {
        text.count > limit ? String(text.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…" : text
    }
}
