import Foundation

final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "Padlock.settings.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> (settings: AppSettings, notice: String?) {
        guard let data = defaults.data(forKey: key) else { return (.defaults, nil) }
        guard let settings = try? JSONDecoder().decode(AppSettings.self, from: data),
              settings.validationError == nil else {
            return (.defaults, "Saved settings were invalid. Safe defaults have been restored.")
        }
        return (settings, nil)
    }

    func save(_ settings: AppSettings) throws {
        if let error = settings.validationError {
            throw NSError(domain: "Padlock.Settings", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: error])
        }
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: key)
    }
}
