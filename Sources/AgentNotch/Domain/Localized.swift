import Foundation

/// A user-visible string, looked up in the app bundle's `<language>.lproj/Localizable.strings`.
/// The key is the English text, so a missing translation (or a run outside the .app bundle) shows English.
/// Translations that reorder arguments use positional specifiers (`%1$@`, `%2$d`).
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, bundle: .main, comment: "")
    return args.isEmpty ? format : String(format: format, arguments: args)
}
