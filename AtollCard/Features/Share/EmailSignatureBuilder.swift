import Foundation

enum EmailSignatureBuilder {
    static func html(for card: Card, fields: [CardField]) -> String {
        let accent = esc(card.accentColor)
        let titleCompany = [card.title, card.company]
            .compactMap { $0 }.filter { !$0.isEmpty }.map(esc).joined(separator: " · ")
        var rows = ""
        for f in fields {
            let label = esc(f.label)
            let value = esc(f.value)
            let content: String
            switch f.type {
            case .phone: content = "<a href=\"tel:\(value)\" style=\"color:\(accent);text-decoration:none\">\(value)</a>"
            case .email: content = "<a href=\"mailto:\(value)\" style=\"color:\(accent);text-decoration:none\">\(value)</a>"
            case .url:   content = "<a href=\"\(value)\" style=\"color:\(accent);text-decoration:none\">\(value)</a>"
            case .social, .address, .custom: content = value
            }
            rows += "<div style=\"font-size:13px;color:#555555;margin-top:2px\">\(label): \(content)</div>"
        }
        let profile = "https://card.atoll-os.com/\(esc(card.slug))"
        let tcLine = titleCompany.isEmpty ? "" : "<div style=\"font-size:13px;color:#888888\">\(titleCompany)</div>"
        return """
        <div style="font-family:-apple-system,Segoe UI,Arial,sans-serif">
        <div style="font-size:16px;font-weight:700;color:\(accent)">\(esc(card.displayName))</div>
        \(tcLine)
        \(rows)
        <div style="font-size:13px;margin-top:4px"><a href="\(profile)" style="color:\(accent);text-decoration:none">card.atoll-os.com/\(esc(card.slug))</a></div>
        </div>
        """
    }

    static func plainText(for card: Card, fields: [CardField]) -> String {
        var lines = [card.displayName]
        let tc = [card.title, card.company].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        if !tc.isEmpty { lines.append(tc) }
        for f in fields { lines.append("\(f.label): \(f.value)") }
        lines.append("https://card.atoll-os.com/\(card.slug)")
        return lines.joined(separator: "\n")
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
