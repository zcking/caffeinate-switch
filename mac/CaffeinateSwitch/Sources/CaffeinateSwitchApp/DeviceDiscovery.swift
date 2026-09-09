import Foundation

enum DeviceDiscovery {
    static let overrideKey = "SerialDevicePath"

    static func devicePath(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> String? {
        if let override = defaults.string(forKey: overrideKey),
           override.hasPrefix("/dev/cu.") {
            return override
        }

        let names = (try? fileManager.contentsOfDirectory(atPath: "/dev")) ?? []
        return names
            .filter { $0.hasPrefix("cu.usbmodem") }
            .sorted()
            .map { "/dev/\($0)" }
            .first
    }
}
