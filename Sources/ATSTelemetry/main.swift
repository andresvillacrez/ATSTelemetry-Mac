import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var weatherMenu: NSMenu?
    private let reader = TelemetryReader()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        createStatusItem()
        createWindow()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func targetScreen() -> NSScreen {
        NSScreen.screens.first { $0.localizedName == "PM1562" }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func createWindow() {
        guard window == nil else { return }

        let screen = targetScreen()
        let hosting = NSHostingView(rootView: DashboardView(reader: reader))

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.title = "ATS Telemetry"
        window.contentView = hosting
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        window.ignoresMouseEvents = true
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.isExcludedFromWindowsMenu = true

        position(window: window, on: screen)
        window.orderFrontRegardless()

        self.window = window
    }

    private func position(window: NSWindow, on screen: NSScreen) {
        window.setFrame(screen.frame, display: true)
    }

    @objc private func screenParametersChanged() {
        guard let window else { return }
        position(window: window, on: targetScreen())
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "gauge",
            accessibilityDescription: "ATS Telemetry"
        )
        item.button?.image?.isTemplate = true

        let menu = NSMenu()

        let title = NSMenuItem(title: "ATS Telemetry", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        let screen = NSMenuItem(title: "Pantalla: PM1562", action: nil, keyEquivalent: "")
        screen.isEnabled = false
        menu.addItem(screen)

        menu.addItem(.separator())

        let weatherItem = NSMenuItem(title: "Clima", action: nil, keyEquivalent: "")
        let weatherMenu = NSMenu()

        let weatherOptions: [(String, Int)] = [
            ("Automático (lluvia por limpiabrisas)", 0),
            ("Despejado", 1),
            ("Nublado", 2),
            ("Lluvia", 3),
            ("Tormenta", 4)
        ]

        for (title, tag) in weatherOptions {
            let option = NSMenuItem(
                title: title,
                action: #selector(selectWeather(_:)),
                keyEquivalent: ""
            )
            option.tag = tag
            option.target = self
            option.state = tag == 0 ? .on : .off
            weatherMenu.addItem(option)
        }

        weatherItem.submenu = weatherMenu
        menu.addItem(weatherItem)
        self.weatherMenu = weatherMenu

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Salir", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    @objc private func selectWeather(_ sender: NSMenuItem) {
        let weather: WeatherCondition?
        switch sender.tag {
        case 1: weather = .clear
        case 2: weather = .cloudy
        case 3: weather = .rain
        case 4: weather = .storm
        default: weather = nil
        }

        reader.weatherOverride = weather

        for item in weatherMenu?.items ?? [] {
            item.state = item.tag == sender.tag ? .on : .off
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
