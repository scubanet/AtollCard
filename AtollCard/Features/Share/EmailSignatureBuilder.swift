import Foundation

enum EmailSignatureBuilder {
    static func html(for card: Card, fields: [CardField]) -> String {
        let accent = esc(card.accentColor)
        let titleCompany = [card.title, card.company]
            .compactMap { $0 }.filter { !$0.isEmpty }.map(esc).joined(separator: " · ")
        var rows = ""
        for f in fields {
            let label = esc(f.label)
            let display = esc(f.value)
            let content: String
            switch f.type {
            case .phone:
                let tel = f.value.filter { !$0.isWhitespace }
                content = "<a href=\"tel:\(esc(tel))\" style=\"color:\(accent);text-decoration:none\">\(display)</a>"
            case .email:
                content = "<a href=\"mailto:\(esc(f.value))\" style=\"color:\(accent);text-decoration:none\">\(display)</a>"
            case .url:
                if let href = safeHref(f.value) {
                    content = "<a href=\"\(esc(href))\" style=\"color:\(accent);text-decoration:none\">\(display)</a>"
                } else {
                    content = display
                }
            case .social, .address, .custom:
                content = display
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

    private static func safeHref(_ value: String) -> String? {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = t.lowercased()
        return (l.hasPrefix("http://") || l.hasPrefix("https://")) ? t : nil
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
