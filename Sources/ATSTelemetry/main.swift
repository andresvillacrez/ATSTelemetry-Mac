import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private let reader = TelemetryReader()
    private let windowed: Bool = ProcessInfo.processInfo.arguments.contains("--windowed")
        || UserDefaults.standard.bool(forKey: "ATS.windowed")
    private var clickThrough = false
    private var showDiagnostics = false
    private var lightTheme = false
    private var highContrast = false
    private var uiScale: Double = UserDefaults.standard.double(forKey: "ATS.uiScale") == 0 ? 1.0 : UserDefaults.standard.double(forKey: "ATS.uiScale")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        lightTheme = UserDefaults.standard.bool(forKey: "ATS.lightTheme")
        highContrast = UserDefaults.standard.bool(forKey: "ATS.highContrast")
        showDiagnostics = UserDefaults.standard.bool(forKey: "ATS.showDiagnostics")
        clickThrough = UserDefaults.standard.bool(forKey: "ATS.clickThrough")
        if highContrast {
            NSApp.appearance = lightTheme ? NSAppearance(named: .accessibilityHighContrastAqua) : NSAppearance(named: .accessibilityHighContrastDarkAqua)
        } else {
            NSApp.appearance = lightTheme ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)
        }

        createStatusItem()
        createWindow()
        updateWindowTitle()
        setupHotkeys()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func targetScreen() -> NSScreen {
        if let name = UserDefaults.standard.string(forKey: "ATS.screenName"),
           let screen = NSScreen.screens.first(where: { $0.localizedName == name }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    private func createWindow() {
        guard window == nil else { return }

        let screen = targetScreen()
        let hosting = NSHostingView(rootView: DashboardView(reader: reader))

        if windowed {
            let frame = NSRect(x: 0, y: 0, width: 1280, height: 720)
            let window = NSWindow(
                contentRect: frame,
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.title = "ATS Telemetry"
            window.contentView = hosting
            window.backgroundColor = .black
            window.appearance = NSAppearance(named: .darkAqua)
            window.isOpaque = true
            window.hasShadow = true
            window.minSize = NSSize(width: 960, height: 540)
            window.isMovable = true
            window.isMovableByWindowBackground = true
            window.acceptsMouseMovedEvents = true
            if let f = UserDefaults.standard.string(forKey: "ATS.windowFrame") {
                let rect = NSRectFromString(f)
                // Validate the frame is on a visible screen
                let onScreen = NSScreen.screens.contains { $0.frame.intersects(rect) }
                if onScreen {
                    window.setFrame(rect, display: true)
                } else {
                    window.center()
                }
            } else {
                window.center()
            }
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            window.ignoresMouseEvents = false
            window.orderFrontRegardless()
            NotificationCenter.default.addObserver(self, selector: #selector(saveWindowFrame), name: NSWindow.didMoveNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(saveWindowFrame), name: NSWindow.didResizeNotification, object: window)
            self.window = window
            return
        }

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
        window.ignoresMouseEvents = false

        // En modo fullscreen (overlay), habilitar mouse solo cuando el cursor
        // esta en la franja superior (donde estan los botones de ajustes/creditos).
        setupMouseTracking()

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
        menu.appearance = NSAppearance(named: .darkAqua)

        let title = NSMenuItem(title: "ATS Telemetry", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        let screenName = UserDefaults.standard.string(forKey: "ATS.screenName") ?? (NSScreen.main?.localizedName ?? "")
        let screenItem = NSMenuItem(title: "Pantalla", action: nil, keyEquivalent: "")
        let screenMenu = NSMenu()
        screenMenu.appearance = NSAppearance(named: .darkAqua)
        for sc in NSScreen.screens {
            let si = NSMenuItem(title: sc.localizedName, action: #selector(selectScreen(_:)), keyEquivalent: "")
            si.target = self
            si.representedObject = sc
            si.state = (sc.localizedName == screenName) ? .on : .off
            screenMenu.addItem(si)
        }
        screenItem.submenu = screenMenu
        menu.addItem(screenItem)

        menu.addItem(.separator())

        // Clima: modo automatico fijo (sin selector manual, como en Windows v3.2.0)
        reader.weatherOverride = nil
        menu.addItem(.separator())

        let clickItem = NSMenuItem(title: "Clic a través", action: #selector(toggleClickThrough), keyEquivalent: "")
        clickItem.target = self
        clickItem.state = clickThrough ? .on : .off
        menu.addItem(clickItem)

        let diagItem = NSMenuItem(title: "Diagnóstico", action: #selector(toggleDiagnostics), keyEquivalent: "")
        diagItem.target = self
        diagItem.state = showDiagnostics ? .on : .off
        menu.addItem(diagItem)

        let themeItem = NSMenuItem(title: "Tema claro", action: #selector(toggleTheme), keyEquivalent: "")
        themeItem.target = self
        themeItem.state = lightTheme ? .on : .off
        menu.addItem(themeItem)

        let hcItem = NSMenuItem(title: "Alto contraste", action: #selector(toggleHighContrast), keyEquivalent: "")
        hcItem.target = self
        hcItem.state = highContrast ? .on : .off
        menu.addItem(hcItem)

        let scaleItem = NSMenuItem(title: "Escala UI", action: nil, keyEquivalent: "")
        let scaleMenu = NSMenu()
        scaleMenu.appearance = NSAppearance(named: .darkAqua)
        for (title, val) in [("100 %", 1.0), ("125 %", 1.25), ("150 %", 1.5)] {
            let opt = NSMenuItem(title: title, action: #selector(selectScale(_:)), keyEquivalent: "")
            opt.target = self
            opt.representedObject = val
            opt.state = uiScale == val ? .on : .off
            scaleMenu.addItem(opt)
        }
        scaleItem.submenu = scaleMenu
        menu.addItem(scaleItem)

        let langItem = NSMenuItem(title: "Idioma", action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        langMenu.appearance = NSAppearance(named: .darkAqua)
        for (title, code) in [("Español", "es"), ("English", "en")] {
            let opt = NSMenuItem(title: title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            opt.target = self
            opt.representedObject = code
            opt.state = L10n.language == code ? .on : .off
            langMenu.addItem(opt)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)

        menu.addItem(.separator())

        let windowItem = NSMenuItem(title: "Ventana", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu()
        windowMenu.appearance = NSAppearance(named: .darkAqua)

        let zoomItem = NSMenuItem(title: "Maximizar", action: #selector(zoomWindow), keyEquivalent: "")
        zoomItem.target = self
        windowMenu.addItem(zoomItem)

        let miniItem = NSMenuItem(title: "Minimizar", action: #selector(miniaturizeWindow), keyEquivalent: "m")
        miniItem.target = self
        windowMenu.addItem(miniItem)

        windowMenu.addItem(.separator())

        let nextScreenItem = NSMenuItem(title: "Pantalla siguiente", action: #selector(moveToNextScreen), keyEquivalent: "")
        nextScreenItem.target = self
        windowMenu.addItem(nextScreenItem)

        for screen in NSScreen.screens {
            let name = screen.localizedName
            let si = NSMenuItem(title: name, action: #selector(moveToScreen(_:)), keyEquivalent: "")
            si.target = self
            si.representedObject = screen
            si.state = (window?.screen == screen) ? .on : .off
            windowMenu.addItem(si)
        }

        windowMenu.addItem(.separator())

        let alwaysItem = NSMenuItem(title: "Siempre visible", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        alwaysItem.target = self
        alwaysItem.state = (window?.level == .floating) ? .on : .off
        windowMenu.addItem(alwaysItem)

        let moveItem = NSMenuItem(title: "Mover con ratón", action: #selector(toggleMovable), keyEquivalent: "")
        moveItem.target = self
        moveItem.state = (window?.isMovableByWindowBackground ?? false) ? .on : .off
        windowMenu.addItem(moveItem)

        windowItem.submenu = windowMenu
        menu.addItem(windowItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Ajustes…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let creditsItem = NSMenuItem(title: "Créditos", action: #selector(openCredits), keyEquivalent: "")
        creditsItem.target = self
        menu.addItem(creditsItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Salir", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    @objc private func toggleClickThrough() {
        clickThrough.toggle()
        window?.ignoresMouseEvents = clickThrough
        createStatusItem()
    }

    @objc private func toggleDiagnostics() {
        showDiagnostics.toggle()
        UserDefaults.standard.set(showDiagnostics, forKey: "ATS.showDiagnostics")
        createStatusItem()
    }

    @objc private func toggleTheme() {
        lightTheme.toggle()
        applyAppearance()
        UserDefaults.standard.set(lightTheme, forKey: "ATS.lightTheme")
        updateWindowTitle()
        NotificationCenter.default.post(name: Notification.Name("ATS.themeChanged"), object: nil)
        createStatusItem()
    }
    @objc private func toggleHighContrast() {
        highContrast.toggle()
        applyAppearance()
        UserDefaults.standard.set(highContrast, forKey: "ATS.highContrast")
        updateWindowTitle()
        NotificationCenter.default.post(name: Notification.Name("ATS.themeChanged"), object: nil)
        createStatusItem()
    }
    private func applyAppearance() {
        if highContrast {
            NSApp.appearance = lightTheme ? NSAppearance(named: .accessibilityHighContrastAqua) : NSAppearance(named: .accessibilityHighContrastDarkAqua)
        } else {
            NSApp.appearance = lightTheme ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)
        }
    }

    private func updateWindowTitle() {
        let suffix = highContrast ? " (Alto contraste)" : (lightTheme ? " (Claro)" : "")
        window?.title = "ATS Telemetry\(suffix)"
    }

    @objc private func selectScale(_ sender: NSMenuItem) {
        if let val = sender.representedObject as? Double {
            uiScale = val
            UserDefaults.standard.set(val, forKey: "ATS.uiScale")
            createStatusItem()
        }
    }

    private var settingsWindow: NSWindow?

    @objc func openSettings() {
        if let w = settingsWindow {
            window?.level = .normal
            w.level = .modalPanel
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Ajustes"
        w.isReleasedWhenClosed = false

        let v = NSView(frame: w.contentView!.bounds)
        v.autoresizingMask = [.width, .height]
        w.contentView = v

        var y: CGFloat = 280
        func label(_ text: String, at yy: CGFloat) {
            let l = NSTextField(labelWithString: text)
            l.frame = NSRect(x: 20, y: yy, width: 320, height: 18)
            l.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            v.addSubview(l)
        }
        func checkbox(_ title: String, key: String, at yy: CGFloat, action: Selector) {
            let cb = NSButton(checkboxWithTitle: title, target: self, action: action)
            cb.frame = NSRect(x: 20, y: yy, width: 320, height: 20)
            cb.state = UserDefaults.standard.bool(forKey: key) ? .on : .off
            v.addSubview(cb)
        }

        label("Ajustes", at: y); y -= 28
        checkbox("Clic a través (overlay)", key: "ATS.clickThrough", at: y, action: #selector(toggleClickThroughFromSettings(_:))); y -= 26
        checkbox("Diagnóstico (FPS)", key: "ATS.showDiagnostics", at: y, action: #selector(toggleDiagnosticsFromSettings(_:))); y -= 26
        checkbox("Tema claro", key: "ATS.lightTheme", at: y, action: #selector(toggleThemeFromSettings(_:))); y -= 26
        checkbox("Alto contraste", key: "ATS.highContrast", at: y, action: #selector(toggleHighContrastFromSettings(_:))); y -= 26
        checkbox("Reducir movimiento", key: "ATS.reduceMotion", at: y, action: #selector(toggleReduceMotion(_:))); y -= 30

        label("Idioma", at: y); y -= 22
        let lang = NSPopUpButton(frame: NSRect(x: 20, y: y, width: 160, height: 24), pullsDown: false)
        lang.addItems(withTitles: ["Español", "English"])
        lang.selectItem(at: L10n.language == "en" ? 1 : 0)
        lang.target = self
        lang.action = #selector(changeLanguageFromSettings(_:))
        v.addSubview(lang); y -= 32

        label("Escala UI", at: y); y -= 22
        let scale = NSPopUpButton(frame: NSRect(x: 20, y: y, width: 160, height: 24), pullsDown: false)
        scale.addItems(withTitles: ["100 %", "125 %", "150 %"])
        let cur = UserDefaults.standard.double(forKey: "ATS.uiScale")
        let idx = cur >= 1.5 ? 2 : (cur >= 1.25 ? 1 : 0)
        scale.selectItem(at: idx)
        scale.target = self
        scale.action = #selector(changeScaleFromSettings(_:))
        v.addSubview(scale)

        label("Unidades", at: y); y -= 22
        let units = NSPopUpButton(frame: NSRect(x: 20, y: y, width: 160, height: 24), pullsDown: false)
        units.addItems(withTitles: ["Métrico", "Imperial"])
        let curUnits = UserDefaults.standard.integer(forKey: "ATS.units")
        units.selectItem(at: min(max(curUnits, 0), 1))
        units.target = self
        units.action = #selector(changeUnitsFromSettings(_:))
        v.addSubview(units)

        label("Unidad consumo", at: y); y -= 22
        let fuelUnit = NSPopUpButton(frame: NSRect(x: 20, y: y, width: 160, height: 24), pullsDown: false)
        fuelUnit.addItems(withTitles: ["L/100 km", "MPG", "gal/100mi"])
        let curUnit = UserDefaults.standard.integer(forKey: "ATS.fuelUnit")
        fuelUnit.selectItem(at: min(max(curUnit, 0), 2))
        fuelUnit.target = self
        fuelUnit.action = #selector(changeFuelUnitFromSettings(_:))
        v.addSubview(fuelUnit)

        window?.level = .normal
        w.level = .modalPanel
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { [weak self] _ in
            self?.window?.level = .statusBar
        }
        w.center()
        settingsWindow = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleClickThroughFromSettings(_ sender: NSButton) {
        clickThrough = (sender.state == .on)
        UserDefaults.standard.set(clickThrough, forKey: "ATS.clickThrough")
        window?.ignoresMouseEvents = clickThrough
    }
    @objc private func toggleDiagnosticsFromSettings(_ sender: NSButton) {
        showDiagnostics = (sender.state == .on)
        UserDefaults.standard.set(showDiagnostics, forKey: "ATS.showDiagnostics")
    }
    @objc private func toggleThemeFromSettings(_ sender: NSButton) {
        lightTheme = (sender.state == .on)
        UserDefaults.standard.set(lightTheme, forKey: "ATS.lightTheme")
        if highContrast {
            NSApp.appearance = lightTheme ? NSAppearance(named: .accessibilityHighContrastAqua) : NSAppearance(named: .accessibilityHighContrastDarkAqua)
        } else {
            NSApp.appearance = lightTheme ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)
        }
    }
    @objc private func toggleHighContrastFromSettings(_ sender: NSButton) {
        highContrast = (sender.state == .on)
        UserDefaults.standard.set(highContrast, forKey: "ATS.highContrast")
        if highContrast {
            NSApp.appearance = lightTheme ? NSAppearance(named: .accessibilityHighContrastAqua) : NSAppearance(named: .accessibilityHighContrastDarkAqua)
        } else {
            NSApp.appearance = lightTheme ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)
        }
    }
    @objc private func toggleReduceMotion(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "ATS.reduceMotion")
    }
    @objc private func changeLanguageFromSettings(_ sender: NSPopUpButton) {
        L10n.language = (sender.indexOfSelectedItem == 1) ? "en" : "es"
    }
    @objc private func changeScaleFromSettings(_ sender: NSPopUpButton) {
        let vals: [Double] = [1.0, 1.25, 1.5]
        let v = vals[sender.indexOfSelectedItem]
        UserDefaults.standard.set(v, forKey: "ATS.uiScale")
    }

    @objc private func changeUnitsFromSettings(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem, forKey: "ATS.units")
    }

    @objc private func changeFuelUnitFromSettings(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem, forKey: "ATS.fuelUnit")
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        if let code = sender.representedObject as? String {
            L10n.language = code
            createStatusItem()
        }
    }

    @objc func openCredits() {
        let alert = NSAlert()
        alert.messageText = "Créditos"
        alert.informativeText = "ATS Telemetry para macOS\nFH6 v2.7\n\n" +
            "Creador: HS-Gaming / Andres Villacrez\n" +
            "Derechos: código propio bajo licencia MIT.\n" +
            "Tecnologías: SwiftUI, AppKit, SCS SDK Plugin (RenCloud).\n" +
            "Interfaz inspirada en el estándar FH6 (Volvo).\n\n" +
            "Agradecimientos: comunidad SCS Software, truckermudgeon (scs-sdk-plugin).\n\n" +
            "Telemetría pasiva, solo lectura de /SCSTelemetry."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func setupHotkeys() {
        // Local monitor (app active)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleHotkey(event, global: false) ? nil : event
        }
        // Global monitor (app inactive) - requires Accessibility permission
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            _ = self.handleHotkey(event, global: true)
        }

        // CGEventTap (mas fiable para atajos globales) - requiere permiso de Accesibilidad
        setupCGEventTap()
    }

    private func setupCGEventTap() {
        let mask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                let ctrl = flags.contains(.maskControl)
                let shift = flags.contains(.maskShift)
                // Ctrl+Shift+O
                if ctrl && shift && keyCode == 31 { // 'o' keycode
                    DispatchQueue.main.async { appDelegate.toggleClickThrough() }
                    return nil
                }
                // Ctrl+Shift+S
                if ctrl && shift && keyCode == 1 { // 's'
                    DispatchQueue.main.async { appDelegate.openSettings() }
                    return nil
                }
                // Ctrl+Shift+C
                if ctrl && shift && keyCode == 8 { // 'c'
                    DispatchQueue.main.async { appDelegate.openCredits() }
                    return nil
                }
                // F11
                if keyCode == 103 {
                    DispatchQueue.main.async { appDelegate.toggleWindowed() }
                    return nil
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    @discardableResult
    private func handleHotkey(_ event: NSEvent, global: Bool) -> Bool {
        let mods = event.modifierFlags.intersection([.control, .shift, .command, .option])
        if mods == [.control, .shift], event.charactersIgnoringModifiers?.lowercased() == "o" {
            toggleClickThrough(); return true
        }
        if mods == [.control, .shift], event.charactersIgnoringModifiers?.lowercased() == "s" {
            openSettings(); return true
        }
        if mods == [.control, .shift], event.charactersIgnoringModifiers?.lowercased() == "c" {
            openCredits(); return true
        }
        if event.keyCode == 103 { // F11
            toggleWindowed(); return true
        }
        return false
    }

    @objc private func toggleWindowed() {
        // Recreate window in the other mode
        UserDefaults.standard.set(!windowed, forKey: "ATS.windowed")
        // Simplest: terminate and relaunch
        NSApp.terminate(nil)
    }

    @objc private func saveWindowFrame() {
        guard let w = window else { return }
        UserDefaults.standard.set(NSStringFromRect(w.frame), forKey: "ATS.windowFrame")
    }

    @objc private func zoomWindow() {
        window?.zoom(nil)
    }
    @objc private func miniaturizeWindow() {
        window?.miniaturize(nil)
    }
    @objc private func moveToNextScreen() {
        guard let w = window else { return }
        let screens = NSScreen.screens
        guard screens.count > 1 else { return }
        let current = w.screen ?? screens[0]
        let idx = (screens.firstIndex(of: current) ?? 0) + 1
        let next = screens[idx % screens.count]
        w.setFrameOrigin(NSPoint(x: next.frame.midX - w.frame.width/2,
                                 y: next.frame.midY - w.frame.height/2))
        createStatusItem()
    }
    @objc private func selectScreen(_ sender: NSMenuItem) {
        guard let screen = sender.representedObject as? NSScreen else { return }
        UserDefaults.standard.set(screen.localizedName, forKey: "ATS.screenName")
        if let w = window {
            if windowed {
                w.setFrameOrigin(NSPoint(x: screen.frame.midX - w.frame.width/2,
                                         y: screen.frame.midY - w.frame.height/2))
            } else {
                position(window: w, on: screen)
            }
        }
        createStatusItem()
    }

    @objc private func moveToScreen(_ sender: NSMenuItem) {
        guard let w = window, let screen = sender.representedObject as? NSScreen else { return }
        UserDefaults.standard.set(screen.localizedName, forKey: "ATS.screenName")
        if windowed {
            w.setFrameOrigin(NSPoint(x: screen.frame.midX - w.frame.width/2,
                                     y: screen.frame.midY - w.frame.height/2))
        } else {
            position(window: w, on: screen)
        }
        createStatusItem()
    }
    @objc private func toggleAlwaysOnTop() {
        guard let w = window else { return }
        if w.level == .floating {
            w.level = .normal
        } else {
            w.level = .floating
        }
        createStatusItem()
    }
    @objc private func toggleMovable() {
        guard let w = window else { return }
        w.isMovableByWindowBackground.toggle()
        createStatusItem()
    }

    private var mouseMonitor: Any?

    private func setupMouseTracking() {
        guard !windowed else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self, let w = self.window, !self.windowed else { return }
            let gameConnected = UserDefaults.standard.bool(forKey: "ATS.gameConnected")
            if !gameConnected {
                // Sin juego: permitir interaccion completa (onboarding, ajustes, cerrar)
                w.ignoresMouseEvents = false
                return
            }
            let mouseLocation = NSEvent.mouseLocation
            let inTopBar = mouseLocation.y >= (w.screen?.frame.maxY ?? 0) - 80
            if inTopBar {
                w.ignoresMouseEvents = false
            } else {
                w.ignoresMouseEvents = self.clickThrough ? true : false
            }
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
