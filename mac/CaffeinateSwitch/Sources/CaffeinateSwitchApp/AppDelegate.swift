import AppKit
import Foundation
import SwitchCore

final class DispatchScheduler: Scheduler {
    private final class Token: Cancellable {
        private let workItem: DispatchWorkItem

        init(workItem: DispatchWorkItem) {
            self.workItem = workItem
        }

        func cancel() {
            workItem.cancel()
        }
    }

    @discardableResult
    func schedule(after delay: Double, _ action: @escaping () -> Void) -> any Cancellable {
        let workItem = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        return Token(workItem: workItem)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let process = CaffeinateProcess()
    private let scheduler = DispatchScheduler()
    private lazy var reconciler = Reconciler(process: process, scheduler: scheduler)

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let deviceItem = NSMenuItem(title: "Device: disconnected", action: nil, keyEquivalent: "")
    private let rockerItem = NSMenuItem(title: "Rocker: unknown", action: nil, keyEquivalent: "")
    private let processItem = NSMenuItem(title: "Process: stopped", action: nil, keyEquivalent: "")

    private var serial: SerialConnection?
    private var reconnectWorkItem: DispatchWorkItem?
    private var reconnectDelay: Double = 1
    private var connectionGeneration = 0
    private var isSerialConnected = false
    private var isTerminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        reconciler.send = { [weak self] message in self?.send(message) }
        process.onStateChange = { [weak self] isRunning in
            self?.processItem.title = isRunning ? "Process: running" : "Process: stopped"
        }
        process.onUnexpectedTermination = { [weak self] in
            self?.reconciler.childExited()
        }
        connectNow(resetBackoff: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleanUp()
    }

    private func configureMenu() {
        statusItem.button?.title = "☕"
        statusItem.button?.toolTip = "Caffeinate Switch"

        deviceItem.isEnabled = false
        rockerItem.isEnabled = false
        processItem.isEnabled = false

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(deviceItem)
        menu.addItem(rockerItem)
        menu.addItem(processItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Reconnect",
            action: #selector(reconnect(_:)),
            keyEquivalent: "r"
        ))
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        ))
        for item in menu.items where item.action != nil {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func reconnect(_ sender: Any?) {
        connectNow(resetBackoff: true)
    }

    @objc private func quit(_ sender: Any?) {
        cleanUp()
        NSApplication.shared.terminate(nil)
    }

    private func connectNow(resetBackoff: Bool) {
        guard !isTerminating else { return }
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        if resetBackoff { reconnectDelay = 1 }

        if serial != nil {
            serial?.close()
            serial = nil
            markSerialDisconnected()
        }

        guard let path = DeviceDiscovery.devicePath() else {
            deviceItem.title = "Device: disconnected"
            scheduleReconnect()
            return
        }

        connectionGeneration += 1
        let generation = connectionGeneration
        do {
            serial = try SerialConnection(
                path: path,
                onLine: { [weak self] line in self?.receive(line, generation: generation) },
                onDisconnect: { [weak self] in self?.serialDisconnected(generation: generation) }
            )
            isSerialConnected = true
            reconnectDelay = 1
            deviceItem.title = "Device: \(path)"
            reconciler.serialConnected()
        } catch {
            deviceItem.title = "Device: disconnected"
            scheduleReconnect()
        }
    }

    private func receive(_ line: String, generation: Int) {
        guard generation == connectionGeneration, isSerialConnected else { return }
        guard let message = reconciler.receive(line: line) else { return }

        if case .state(_, let state) = message {
            rockerItem.title = "Rocker: \(state == .on ? "on" : "off")"
        }
    }

    private func send(_ message: ProtocolMessage) {
        do {
            try serial?.write(message.encoded)
        } catch {
            deviceItem.title = "Device: disconnected"
        }
    }

    private func serialDisconnected(generation: Int) {
        guard generation == connectionGeneration, !isTerminating else { return }
        serial = nil
        markSerialDisconnected()
        scheduleReconnect()
    }

    private func markSerialDisconnected() {
        guard isSerialConnected else { return }
        isSerialConnected = false
        deviceItem.title = "Device: disconnected"
        rockerItem.title = "Rocker: unknown"
        reconciler.serialDisconnected()
    }

    private func scheduleReconnect() {
        guard reconnectWorkItem == nil, !isTerminating else { return }
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 5)
        let workItem = DispatchWorkItem { [weak self] in
            self?.reconnectWorkItem = nil
            self?.connectNow(resetBackoff: false)
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cleanUp() {
        guard !isTerminating else { return }
        isTerminating = true
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        serial?.close()
        serial = nil
        process.stop()
    }
}
