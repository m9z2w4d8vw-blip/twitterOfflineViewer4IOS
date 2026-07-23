import Foundation

// Matches the same rule the extension's viewer uses: anchored to the
// start of a word so "hi" matches "hi" or "hiiiiiii" but not the "hi"
// hiding in the middle of "think" or "anything".
func messageMatches(_ text: String?, query: String) -> Bool {
    guard let text, !text.isEmpty else { return false }
    guard let regex = try? NSRegularExpression(
        pattern: "\\b\(NSRegularExpression.escapedPattern(for: query))",
        options: .caseInsensitive
    ) else { return false }
    let range = NSRange(text.startIndex..., in: text)
    return regex.firstMatch(in: text, range: range) != nil
}
