import Foundation

protocol OutputSettingsStoring { func load() -> OutputSettings; func save(_ settings: OutputSettings) }

final class OutputSettingsStore: OutputSettingsStoring {
    private let key = "VideoScreenshot.OutputSettings"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> OutputSettings {
        guard let data = defaults.data(forKey: key), var decoded = try? JSONDecoder().decode(OutputSettings.self, from: data) else { return .defaultValue }
        decoded.resolveSecurityScopedBookmarks()
        return decoded
    }
    func save(_ settings: OutputSettings) { if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: key) } }
}
