import XCTest
@testable import CaffeinateSwitchApp

final class DeviceDiscoveryTests: XCTestCase {
    func testPrefersUsbModemOverUsbSerial() {
        let path = DeviceDiscovery.preferredDevicePath(fromDeviceNames: [
            "cu.usbserial-0001",
            "cu.usbmodem1101",
            "cu.Bluetooth-Incoming-Port",
        ])
        XCTAssertEqual(path, "/dev/cu.usbmodem1101")
    }

    func testSelectsUsbSerialWhenNoModemPresent() {
        let path = DeviceDiscovery.preferredDevicePath(fromDeviceNames: [
            "cu.Bluetooth-Incoming-Port",
            "cu.usbserial-0001",
        ])
        XCTAssertEqual(path, "/dev/cu.usbserial-0001")
    }

    func testAcceptsCommonUartBridgeNames() {
        XCTAssertEqual(
            DeviceDiscovery.preferredDevicePath(fromDeviceNames: ["cu.wchusbserial1410"]),
            "/dev/cu.wchusbserial1410"
        )
        XCTAssertEqual(
            DeviceDiscovery.preferredDevicePath(fromDeviceNames: ["cu.SLAB_USBtoUART"]),
            "/dev/cu.SLAB_USBtoUART"
        )
        XCTAssertEqual(
            DeviceDiscovery.preferredDevicePath(fromDeviceNames: ["cu.CP2104_1"]),
            "/dev/cu.CP2104_1"
        )
    }

    func testReturnsNilWhenNoCandidates() {
        XCTAssertNil(
            DeviceDiscovery.preferredDevicePath(fromDeviceNames: [
                "cu.Bluetooth-Incoming-Port",
                "tty.usbserial-0001",
            ])
        )
    }
}
