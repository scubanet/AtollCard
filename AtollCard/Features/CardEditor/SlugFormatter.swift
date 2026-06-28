import Foundation

/// Normalizes free-form text into a URL slug.
enum SlugFormatter {
    /// "Jane Doe" -> "jane-doe": lowercase, trim, spaces->hyphens, strip
    /// everything outside `[a-z0-9-]`, collapse repeated hyphens, trim hyphens.
    static func normalize(_ input: String) -> String {
        let lowered = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        let filtered = String(lowered.filter { allowed.contains($0) })
        // collapse repeated hyphens
        var result = ""
        var lastWasHyphen = false
        for ch in filtered {
            if ch == "-" {
                if !lastWasHyphen { result.append(ch) }
                lastWasHyphen = true
            } else {
                result.append(ch)
                lastWasHyphen = false
            }
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
