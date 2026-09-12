import Foundation

enum DeviceDiscovery {
    static let overrideKey = "SerialDevicePath"

    /// Prefers native USB CDC (`usbmodem`) over USB-UART bridges (`usbserial`,
    /// WCH, Silicon Labs, CP210x) so an ESP32-S3 wins when both are present.
    static func devicePath(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> String? {
        if let override = defaults.string(forKey: overrideKey),
           override.hasPrefix("/dev/cu.") {
            return override
        }

        let names = (try? fileManager.contentsOfDirectory(atPath: "/dev")) ?? []
        return preferredDevicePath(fromDeviceNames: names)
    }

    static func preferredDevicePath(fromDeviceNames names: [String]) -> String? {
        names
            .filter(isSerialCandidate)
            .sorted(by: preferredCandidateOrder)
            .map { "/dev/\($0)" }
            .first
    }

    static func isSerialCandidate(_ name: String) -> Bool {
        name.hasPrefix("cu.usbmodem")
            || name.hasPrefix("cu.usbserial")
            || name.hasPrefix("cu.wchusbserial")
            || name.hasPrefix("cu.SLAB_USBtoUART")
            || name.hasPrefix("cu.CP210")
    }

    private static func preferredCandidateOrder(_ lhs: String, _ rhs: String) -> Bool {
        let lhsRank = candidateRank(lhs)
        let rhsRank = candidateRank(rhs)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return lhs < rhs
    }

    private static func candidateRank(_ name: String) -> Int {
        if name.hasPrefix("cu.usbmodem") { return 0 }
        if name.hasPrefix("cu.usbserial") { return 1 }
        if name.hasPrefix("cu.wchusbserial") { return 2 }
        if name.hasPrefix("cu.SLAB_USBtoUART") { return 3 }
        if name.hasPrefix("cu.CP210") { return 4 }
        return 100
    }
}
