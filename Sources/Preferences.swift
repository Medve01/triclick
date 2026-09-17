import Foundation

enum Preferences {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "enabled"
        static let threeFingerClick = "threeFingerClick"
        static let threeFingerTap = "threeFingerTap"
        static let fnClick = "fnClick"
        static let launchAtLogin = "launchAtLogin"
        static let onboardingDone = "onboardingDone"
        static let ignoredApps = "ignoredApps"
        static let maxTapDistance = "maxTapDistance"
        static let maxTapTimeMs = "maxTapTimeMs"
    }

    static var enabled: Bool {
        get { defaults.object(forKey: Key.enabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    static var threeFingerClick: Bool {
        get { defaults.object(forKey: Key.threeFingerClick) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.threeFingerClick) }
    }

    static var threeFingerTap: Bool {
        get { defaults.object(forKey: Key.threeFingerTap) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.threeFingerTap) }
    }

    static var fnClick: Bool {
        get { defaults.object(forKey: Key.fnClick) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.fnClick) }
    }

    static var launchAtLogin: Bool {
        get { defaults.object(forKey: Key.launchAtLogin) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    static var onboardingDone: Bool {
        get { defaults.bool(forKey: Key.onboardingDone) }
        set { defaults.set(newValue, forKey: Key.onboardingDone) }
    }

    static var ignoredApps: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.ignoredApps) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Key.ignoredApps) }
    }

    /// Normalized trackpad units (0–1). Default ~5% of the pad.
    static var maxTapDistance: Float {
        get {
            let value = defaults.object(forKey: Key.maxTapDistance) as? Float
            return value ?? 0.05
        }
        set { defaults.set(newValue, forKey: Key.maxTapDistance) }
    }

    static var maxTapTimeMs: Int {
        get {
            let value = defaults.object(forKey: Key.maxTapTimeMs) as? Int
            return value ?? 300
        }
        set { defaults.set(newValue, forKey: Key.maxTapTimeMs) }
    }
}
