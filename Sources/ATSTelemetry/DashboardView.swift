import AppKit
import Foundation
import SwiftUI
import Combine

// MARK: - Palette
enum ATSColor {
    static let green = Color(red: 0.22, green: 0.96, blue: 0.58)
    static let cyan = Color(red: 0.25, green: 0.82, blue: 1.00)
    static let yellow = Color(red: 1.00, green: 0.84, blue: 0.22)
    static let orange = Color(red: 1.00, green: 0.52, blue: 0.10)
    static let red = Color(red: 1.00, green: 0.16, blue: 0.22)
    static let blue = Color(red: 0.42, green: 0.68, blue: 1.00)
    static let dim = Color.white.opacity(0.35)
}

// MARK: - Truck image loader (FH6)
enum TruckImageLoader {
    private static var cache: [String: NSImage] = [:]

    static func name(for snap: Snap) -> String? {
        guard snap.active else { return nil }
        var candidates: [String] = []
        if let id = snap.truckId?.lowercased(), !id.isEmpty {
            var base = id
            if base.hasPrefix("vehicle.") { base.removeFirst("vehicle.".count) }
            base = base.replacingOccurrences(of: ".", with: "_")
            candidates.append(base)
            for suffix in ["_gtm", "_mod", "_custom"] {
                if base.hasSuffix(suffix) {
                    candidates.append(String(base.dropLast(suffix.count)))
                }
            }
        }
        if let brand = snap.truckBrand?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
           let name = snap.truckName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
           !brand.isEmpty, !name.isEmpty {
            let b = brand.replacingOccurrences(of: " ", with: "_")
            let n = name.replacingOccurrences(of: " ", with: "_")
            candidates.append("\(b)_\(n)")
        }
        for c in candidates {
            if load(c) != nil { return c }
        }
        return candidates.first
    }

    static func image(named name: String?) -> NSImage? {
        guard let name, !name.isEmpty else { return nil }
        if let cached = cache[name] { return cached }
        if let img = load(name) {
            cache[name] = img
            return img
        }
        return nil
    }

    private static func load(_ name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "TruckImages"),
           let img = NSImage(contentsOf: url) { return img }
        if let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
           let img = NSImage(contentsOf: url) { return img }
        return nil
    }
}

// MARK: - Company logo loader (FH6)
enum CompanyLogoLoader {
    private static var cache: [String: NSImage] = [:]
    static func image(named name: String?) -> NSImage? {
        guard let name, !name.isEmpty else { return nil }
        if let c = cache[name] { return c }
        let base = name.replacingOccurrences(of: ".png", with: "")
        if let url = Bundle.main.url(forResource: base, withExtension: "png", subdirectory: "CompanyLogos"),
           let img = NSImage(contentsOf: url) { cache[name] = img; return img }
        if let url = Bundle.main.url(forResource: base, withExtension: "png"),
           let img = NSImage(contentsOf: url) { cache[name] = img; return img }
        return nil
    }
}

private func companyLogoImage(named name: String?) -> NSImage? {
    CompanyLogoLoader.image(named: name)
}

// MARK: - Brand logo loader (FH6)
enum BrandLogoLoader {
    private static var cache: [String: NSImage] = [:]
    static func image(brand: String?) -> NSImage? {
        guard let brand, !brand.isEmpty else { return nil }
        let key = brand.lowercased().replacingOccurrences(of: " ", with: "")
        if let c = cache[key] { return c }
        // try a few candidate filenames
        let candidates = [brand.lowercased(), brand.lowercased().replacingOccurrences(of: " ", with: ""),
                          key, brand.lowercased().replacingOccurrences(of: " ", with: "_")]
        for c in candidates {
            if let url = Bundle.main.url(forResource: c, withExtension: "png", subdirectory: "BrandLogos"),
               let img = NSImage(contentsOf: url) { cache[key] = img; return img }
            if let url = Bundle.main.url(forResource: c, withExtension: "png"),
               let img = NSImage(contentsOf: url) { cache[key] = img; return img }
        }
        return nil
    }
}



enum AdvisoryType {
    case info, success, warning, danger
    var color: Color {
        switch self {
        case .success: return ATSColor.green
        case .warning: return ATSColor.yellow
        case .danger: return ATSColor.red
        case .info: return ATSColor.orange
        }
    }
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

// MARK: - Game messages (avisos) store (FH6)
final class GameMessageStore: ObservableObject {
    static let holdSeconds = 2.5
    static let fadeSeconds = 0.5
    static let totalSeconds = 3.0
    static let queueLimit = 8
    static let demoMessages = ["ENTREGA COMPLETADA", "NUEVO TRABAJO ASIGNADO", "PEAJE PAGADO", "FERRY ABORDADO", "MULTA PAGADA"]

    @Published var currentMessage: String? = nil
    @Published var currentType: AdvisoryType = .info
    @Published var opacity: Double = 0

    private var queue: [(String, AdvisoryType)] = []
    private var messageStarted: Date? = nil
    private var baselineReady = false
    private var prevBankBalance: Int64? = nil
    private var prevDelivered: Int64? = nil
    private var prevCancelled: Int64? = nil
    private var prevFine: Int64? = nil
    private var prevToll: Int64? = nil
    private var prevFerry: Int64? = nil
    private var prevTrain: Int64? = nil
    private var prevJobIncome: UInt64? = nil

    // demo
    private var demoMode = false
    private var demoNext: Date? = nil
    private var demoIndex = 0

    func update(snap: Snap, now: Date) {
        if snap.demo {
            if !demoMode { demoMode = true; demoNext = now }
            if let next = demoNext, now >= next {
                push(Self.demoMessages[demoIndex % Self.demoMessages.count])
                demoIndex += 1
                demoNext = now.addingTimeInterval(3.8)
            }
        } else {
            demoMode = false
            if snap.active {
                if baselineReady {
                    detect(snap)
                } else {
                    storeBaseline(snap)
                    baselineReady = true
                }
            } else {
                baselineReady = false
            }
        }

        // expire current
        if let started = messageStarted, currentMessage != nil {
            if now.timeIntervalSince(started) >= Self.totalSeconds {
                currentMessage = nil
                messageStarted = nil
            }
        }
        // dequeue next
        if currentMessage == nil && !queue.isEmpty {
            let (msg, typ) = queue.removeFirst()
            currentMessage = msg
            currentType = typ
            messageStarted = now
        }
        // opacity
        if let started = messageStarted, currentMessage != nil {
            let elapsed = now.timeIntervalSince(started)
            if elapsed <= Self.holdSeconds {
                opacity = 1
            } else {
                opacity = max(0, 1 - (elapsed - Self.holdSeconds) / Self.fadeSeconds)
            }
        } else {
            opacity = 0
        }
    }

    private func push(_ text: String, type: AdvisoryType = .info) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty, queue.count < Self.queueLimit else { return }
        queue.append((text, type))
    }

    private func storeBaseline(_ snap: Snap) {
        prevBankBalance = snap.bankBalance
        prevDelivered = snap.jobDeliveredRevenue
        prevCancelled = snap.jobCancelledPenalty
        prevFine = snap.fineAmount
        prevToll = snap.tollgatePay
        prevFerry = snap.ferryPay
        prevTrain = snap.trainPay
        prevJobIncome = snap.jobIncome
    }

    private func detect(_ snap: Snap) {
        var specific = false
        if let delivered = changedPositive(prevDelivered, snap.jobDeliveredRevenue) {
            push("ENTREGA COMPLETADA +\(money(delivered))", type: .success)
            specific = true
        }
        if let cancelled = changedPositive(prevCancelled, snap.jobCancelledPenalty) {
            push("TRABAJO CANCELADO -\(money(cancelled))", type: .danger)
            specific = true
        }
        if let fine = changedPositive(prevFine, snap.fineAmount) {
            push("MULTA -\(money(fine))", type: .danger)
            specific = true
        }
        if let toll = changedPositive(prevToll, snap.tollgatePay) {
            push("PEAJE -\(money(toll))", type: .warning)
            specific = true
        }
        if let ferry = changedPositive(prevFerry, snap.ferryPay) {
            push("FERRY -\(money(ferry))", type: .info)
            specific = true
        }
        if let train = changedPositive(prevTrain, snap.trainPay) {
            push("TREN -\(money(train))", type: .info)
            specific = true
        }
        if !specific,
           let prevIncome = prevJobIncome,
           let curIncome = snap.jobIncome,
           curIncome != prevIncome, curIncome > 0 {
            push("NUEVO TRABAJO +\(money(Int64(curIncome)))", type: .success)
        }
        if !specific,
           let prevBal = prevBankBalance,
           let curBal = snap.bankBalance,
           curBal > prevBal {
            push("INGRESO +\(money(curBal - prevBal))", type: .success)
        }
        storeBaseline(snap)
    }

    private func changedPositive(_ prev: Int64?, _ cur: Int64?) -> Int64? {
        guard let before = prev, let after = cur else { return nil }
        return (after > 0 && after != before) ? after : nil
    }

    private func money(_ v: Int64) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "es_ES")
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        let mag = abs(v)
        let s = f.string(from: NSNumber(value: mag)) ?? "\(mag)"
        return v < 0 ? "-$\(s)" : "$\(s)"
    }
}


// MARK: - Font scaling helper (accesibilidad)
func FS(_ size: CGFloat) -> CGFloat {
    let scale = UserDefaults.standard.double(forKey: "ATS.uiScale")
    return size * (scale == 0 ? 1.0 : scale)
}

// MARK: - Localization (es/en) (FH6)
enum L10n {
    static var language: String {
        get { UserDefaults.standard.string(forKey: "ATS.language") ?? "es" }
        set { UserDefaults.standard.set(newValue, forKey: "ATS.language") }
    }
    private static let table: [String: [String: String]] = [
        "es": [
            "status.demo": "DEMO",
            "status.waiting": "ESPERANDO ATS",
            "status.paused": "PAUSA",
            "status.online": "EN LÍNEA",
            "header.ats": "ATS",
            "header.telemetry": "TELEMETRÍA",
            "panel.finance": "EMPRESA",
            "panel.cargo": "CARGA",
            "panel.damage": "DAÑOS",
            "panel.gps": "GPS",
            "panel.fuel": "COMBUSTIBLE",
            "panel.advisory": "AVISOS",
            "panel.weather": "CLIMA",
            "no.signal": "SIN SEÑAL",
            "no.data": "SIN DATOS",
            "no.trip": "SIN VIAJE",
            "gps.noroute": "SIN RUTA",
            "no.origin": "SIN ORIGEN",
            "no.destination": "SIN DESTINO",
            "cargo.notrailer": "SIN REMOLQUE",
            "cargo.ontrailer": "EN REMOLQUE",
            "no.cargo": "SIN CARGA",
            "no.job": "SIN TRABAJO",
            "no.company": "SIN EMPRESA",
            "no.routeactive": "SIN RUTA ACTIVA",
            "no.truck": "SIN CAMIÓN",
            "no.image": "SIN IMAGEN",
            "advisory.footer": "NOTIFICACIÓN DEL JUEGO",
            "no.advisory": "SIN AVISOS",
            "gauge.water": "TEMPERATURA",
            "fuel.autonomy": "AUTONOMÍA",
            "finance.drivers": "CONDUCTORES",
            "damage.critical": "CRÍTICO",
            "cruise.label": "CRUCERO",
            "damage.damage": "DAÑO",
            "weather.clear": "DESPEJADO",
            "gps.destination": "DESTINO",
            "finance.total": "DINERO TOTAL",
            "weather.day": "DÍA",
            "finance.expenses": "EGRESOS RUTA",
            "status.live": "EN VIVO",
            "checkengine.engine": "ENGINE",
            "status.ets2": "ETS2",
            "gps.remaining": "FALTAN",
            "msg.ferry": "FERRY ABORDADO",
            "weather.gametime": "HORA DEL JUEGO",
            "gps.eta": "HORA PREVISTA",
            "finance.income": "INGRESOS",
            "cargo.integrity": "INTEGRIDAD",
            "damage.minor": "LEVE",
            "gps.arrival": "LLEGADA",
            "weather.rain": "LLUVIA",
            "gear.label": "MARCHA",
            "finance.margin": "MARGEN OPERATIVO",
            "msg.finepaid": "MULTA PAGADA",
            "gps.odometer": "ODÓMETRO",
            "gps.origin": "ORIGEN",
            "cargo.weight": "PESO",
            "gps.position": "POSICIÓN",
            "gauge.air": "PRESIÓN",
            "gps.travelled": "RECORRIDO",
            "fuel.reserve": "RESERVA",
            "damage.review": "REVISAR",
            "gps.bearing": "RUMBO",
            "cargo.special": "TRABAJO ESPECIAL",
            "cargo.standard": "TRABAJO ESTÁNDAR",
            "damage.trailer": "TRÁILER",
            "cargo.empty": "VACÍA",
            "damage.truck": "CAMIÓN",
            "cargo.loaded": "CARGADA",
            "cargo.trailer": "EN REMOLQUE",
            "gps.onroute": "EN RUTA",
            "msg.newjob": "NUEVO TRABAJO ASIGNADO",
        ],
        "en": [
            "status.demo": "DEMO",
            "status.waiting": "WAITING FOR ATS",
            "status.paused": "PAUSED",
            "status.online": "ONLINE",
            "header.ats": "ATS",
            "header.telemetry": "TELEMETRY",
            "panel.finance": "COMPANY",
            "panel.cargo": "CARGO",
            "panel.damage": "DAMAGE",
            "panel.gps": "GPS",
            "panel.fuel": "FUEL",
            "panel.advisory": "ALERTS",
            "panel.weather": "WEATHER",
            "no.signal": "NO SIGNAL",
            "no.data": "NO DATA",
            "no.trip": "NO TRIP",
            "gps.noroute": "NO ROUTE",
            "no.origin": "NO ORIGIN",
            "no.destination": "NO DESTINATION",
            "cargo.notrailer": "NO TRAILER",
            "cargo.ontrailer": "ON TRAILER",
            "no.cargo": "NO CARGO",
            "no.job": "NO JOB",
            "no.company": "NO COMPANY",
            "no.routeactive": "NO ACTIVE ROUTE",
            "no.truck": "NO TRUCK",
            "no.image": "NO IMAGE",
            "advisory.footer": "GAME NOTIFICATION",
            "no.advisory": "NO ALERTS",
            "gauge.water": "TEMPERATURE",
            "fuel.autonomy": "AUTONOMY",
            "finance.drivers": "DRIVERS",
            "damage.critical": "CRITICAL",
            "cruise.label": "CRUISE",
            "damage.damage": "DAMAGE",
            "weather.clear": "CLEAR",
            "gps.destination": "DESTINATION",
            "finance.total": "TOTAL MONEY",
            "weather.day": "DAY",
            "finance.expenses": "ROUTE EXPENSES",
            "status.live": "LIVE",
            "checkengine.engine": "ENGINE",
            "status.ets2": "ETS2",
            "gps.remaining": "REMAINING",
            "msg.ferry": "FERRY BOARDED",
            "weather.gametime": "GAME TIME",
            "gps.eta": "EST. ARRIVAL",
            "finance.income": "INCOME",
            "cargo.integrity": "INTEGRITY",
            "damage.minor": "MINOR",
            "gps.arrival": "ARRIVAL",
            "weather.rain": "RAIN",
            "gear.label": "GEAR",
            "finance.margin": "OPERATING MARGIN",
            "msg.finepaid": "FINE PAID",
            "gps.odometer": "ODOMETER",
            "gps.origin": "ORIGIN",
            "cargo.weight": "WEIGHT",
            "gps.position": "POSITION",
            "gauge.air": "PRESSURE",
            "gps.travelled": "TRAVELLED",
            "fuel.reserve": "RESERVE",
            "damage.review": "REVIEW",
            "gps.bearing": "BEARING",
            "cargo.special": "SPECIAL JOB",
            "cargo.standard": "STANDARD JOB",
            "damage.trailer": "TRAILER",
            "cargo.empty": "EMPTY",
            "damage.truck": "TRUCK",
            "cargo.loaded": "LOADED",
            "cargo.trailer": "ON TRAILER",
            "gps.onroute": "ON ROUTE",
            "msg.newjob": "NEW JOB ASSIGNED",
        ]
    ]
    static func t(_ key: String) -> String {
        table[language]?[key] ?? table["es"]?[key] ?? key
    }
}

// MARK: - Theme tokens (v3)
enum Theme {
    // Superficies
    static let backgroundTop = Color(red: 0.039, green: 0.047, blue: 0.059)
    static let backgroundBottom = Color(red: 0.027, green: 0.035, blue: 0.043)
    static let surface = Color.white.opacity(0.022)
    static let surfaceRaised = Color.white.opacity(0.035)
    static let stroke = Color.white.opacity(0.07)
    static let strokeStrong = Color.white.opacity(0.12)
    // Texto
    static let textPrimary = Color(red: 0.957, green: 0.969, blue: 0.976)
    static let textSecondary = Color(red: 0.659, green: 0.698, blue: 0.729)
    static let textTertiary = Color(red: 0.435, green: 0.478, blue: 0.510)
    static let textDisabled = Color(red: 0.290, green: 0.322, blue: 0.349)
    // Semánticos
    static let accent = ATSColor.cyan
    static let success = ATSColor.green
    static let warning = ATSColor.yellow
    static let notice = ATSColor.orange
    static let danger = ATSColor.red
    static let info = ATSColor.blue
    // Radios
    static let radiusChip: CGFloat = 12
    static let radiusCard: CGFloat = 16
    static let radiusPanel: CGFloat = 24
    // Espaciado (retícula 8)
    static let space1: CGFloat = 8
    static let space2: CGFloat = 16
    static let space3: CGFloat = 24
    static let space4: CGFloat = 32
}

// MARK: - Type scale (v3)
enum TypeScale {
    static let display: CGFloat = 184
    static let hero: CGFloat = 34
    static let title: CGFloat = 24
    static let body: CGFloat = 16
    static let label: CGFloat = 12
    static let caption: CGFloat = 11
    static let micro: CGFloat = 10
}



// MARK: - Layout mode (v3)
enum LayoutMode {
    case full, compact, minimal
    static func forSize(_ w: CGFloat, _ h: CGFloat, uiScale: Double = 1.0) -> LayoutMode {
        let effectiveW = w / CGFloat(uiScale == 0 ? 1.0 : uiScale)
        let effectiveH = h / CGFloat(uiScale == 0 ? 1.0 : uiScale)
        if effectiveW >= 1600 && effectiveH >= 900 { return .full }
        if effectiveW >= 1024 && effectiveH >= 576 { return .compact }
        return .minimal
    }
    var canvasWidth: CGFloat {
        switch self { case .full: return 1920; case .compact: return 1280; case .minimal: return 960 }
    }
    var canvasHeight: CGFloat {
        switch self { case .full: return 1080; case .compact: return 720; case .minimal: return 540 }
    }
    var showVerticalGauges: Bool { self == .full }
    var showDetailRows: Bool { self == .full }
    var showBottomCards: Bool { self != .minimal }
    var showSidePanels: Bool { self != .minimal }
}


// MARK: - AnimatedValue (v3 spring smoothing)
final class AnimatedValue {
    private var value: Double = 0
    private var velocity: Double = 0
    func update(target: Double, dt: Double) {
        let stiffness = 120.0
        let damping = 20.0
        let force = (target - value) * stiffness - velocity * damping
        velocity += force * dt
        value += velocity * dt
        if abs(target - value) < 0.001 && abs(velocity) < 0.001 {
            value = target
            velocity = 0
        }
    }
    func snap(_ target: Double) { value = target; velocity = 0 }
    var current: Double { value }
}

// MARK: - Onboarding (v3)
struct OnboardingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
            VStack(spacing: 20) {
                Text("ATS TELEMETRÍA")
                    .font(.system(size: FS(TypeScale.title), weight: .bold, design: .default))
                    .foregroundColor(Theme.textPrimary)
                Text("Primer arranque sin juego")
                    .font(.system(size: FS(TypeScale.body), weight: .medium, design: .default))
                    .foregroundColor(Theme.textSecondary)

                VStack(alignment: .leading, spacing: 10) {
                    OnboardingStep(number: "1",
                        text: "Instala el plugin de telemetría (scs-telemetry.dylib) en ATS/ETS2.")
                    OnboardingStep(number: "2",
                        text: "Abre ATS o ETS2 y espera la conexión.")
                }

                HStack(spacing: 12) {
                    Button(action: { NSApp.terminate(nil) }) {
                        Text("SALIR")
                            .font(.system(size: FS(TypeScale.label), weight: .bold, design: .default))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: Theme.radiusChip).fill(Theme.surfaceRaised))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusChip).stroke(Theme.strokeStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button(action: { NSApp.windows.first?.miniaturize(nil) }) {
                        Text("MINIMIZAR")
                            .font(.system(size: FS(TypeScale.label), weight: .bold, design: .default))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: Theme.radiusChip).fill(Theme.surfaceRaised))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusChip).stroke(Theme.strokeStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: Theme.radiusPanel).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusPanel).stroke(Theme.stroke, lineWidth: 1))
        }
    }
}

struct OnboardingStep: View {
    let number: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: FS(TypeScale.label), weight: .bold, design: .default))
                .foregroundColor(Theme.accent)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.surfaceRaised))
            Text(text)
                .font(.system(size: FS(TypeScale.caption), weight: .regular, design: .default))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Empty state (v3)
struct EmptyStateView: View {
    let message: String
    let hint: String?
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "photo")
                .font(.system(size: FS(20), weight: .medium))
                .foregroundColor(Theme.textDisabled)
            Text(message)
                .font(.system(size: FS(TypeScale.body), weight: .bold, design: .default))
                .foregroundColor(Theme.textDisabled)
            if let hint {
                Text(hint)
                    .font(.system(size: FS(TypeScale.caption), weight: .regular, design: .default))
                    .foregroundColor(Theme.textDisabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Root view
struct DashboardView: View {
    let reader: TelemetryReader
    @StateObject private var messages = GameMessageStore()
    @State private var diagFPS: Double = 0
    @State private var diagFrameMs: Double = 0
    @State private var lastDiagFrame: Date = Date()

    var body: some View {
        GeometryReader { geo in
            let uiScale = UserDefaults.standard.double(forKey: "ATS.uiScale") == 0 ? 1.0 : UserDefaults.standard.double(forKey: "ATS.uiScale")
            let layout = LayoutMode.forSize(geo.size.width, geo.size.height, uiScale: uiScale)
            let scale = min(geo.size.width / layout.canvasWidth, geo.size.height / layout.canvasHeight) * uiScale

            ZStack {
                Color.black

                ZStack {
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                        let snap = reader.snapshot()
                        let _ = DispatchQueue.main.async {
                            let now = context.date
                            let dt = now.timeIntervalSince(lastDiagFrame)
                            if dt > 0 { diagFPS = 1.0 / dt }
                            diagFrameMs = dt * 1000
                            lastDiagFrame = now
                            messages.update(snap: snap, now: context.date)
                            UserDefaults.standard.set(snap.active || snap.demo, forKey: "ATS.gameConnected")
                        }
                        DashboardContent(snap: snap, messages: messages, layout: layout)
                    }
                }
                .frame(width: layout.canvasWidth, height: layout.canvasHeight)
                .scaleEffect(scale)

                if UserDefaults.standard.bool(forKey: "ATS.showDiagnostics") {
                    VStack {
                        HStack {
                            Spacer()
                            Text("DIAG · \(Int(diagFPS)) FPS · \(String(format: "%.1f", diagFrameMs)) ms · \(Date().formatted(date: .omitted, time: .standard))")
                                .font(.system(size: FS(10), weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(6)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(6)
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)

            if !reader.snapshot().active && !reader.snapshot().demo {
                OnboardingView()
                    .frame(width: 1920, height: 1080)
                    .scaleEffect(scale)
            }
        }
        .ignoresSafeArea()
    }
}

struct DashboardContent: View {
    let snap: Snap
    @ObservedObject var messages: GameMessageStore
    var layout: LayoutMode = .full

    var body: some View {
        ZStack {
            // Cabecera (y = 15..70, linea inferior en y = 92)
            HeaderView(snap: snap, layout: layout)
                .frame(width: 1920, height: 60)
                .position(x: 960, y: 40)

            // Fila de testigos (centrada, y = 108..166)
            IndicatorRowView(snap: snap)
                .frame(width: 1920, height: 58)
                .position(x: 960, y: 137)

            // Cluster central (centro 960,548, radio 302)
            SpeedometerView(snap: snap)
                .frame(width: 600, height: 600)
            .frame(width: 604, height: 604)
            .position(x: 960, y: 548)

            // Minipanel de distancia (dentro del panel de GPS, parte inferior)
            TripBadgeView(snap: snap)
                .frame(width: 220, height: 80)
                .position(x: 1656, y: 880)

            // Caja de marcha (FH6: 70x64 en y=592)
            GearBoxView(snap: snap)
                .position(x: 960, y: 624)

            // Barra de RPM (FH6: 330x14 en y=710)
            RpmBarView(snap: snap)
                .position(x: 960, y: 717)

            if layout.showVerticalGauges {
                // Agua vertical (x=486, y=300, 88x440)
                VerticalGaugeView(snap: snap, kind: .water)
                    .frame(width: 70, height: 352)
                    .position(x: 530, y: 520)

                // Aire vertical (x=1346, y=300, 88x440)
                VerticalGaugeView(snap: snap, kind: .air)
                    .frame(width: 70, height: 352)
                    .position(x: 1390, y: 520)
            }

            if layout.showSidePanels {
            // Empresa (x=64, y=116, 400x380)
            FinancialPanelView(snap: snap)
                .frame(width: 400, height: 380)
                .drawingGroup()
                .position(x: 264, y: 306)

            // Carga (x=64, y=512, 400x424)
            CargoPanelView(snap: snap)
                .frame(width: 400, height: 424)
                .drawingGroup()
                .position(x: 264, y: 724)

            // Danos (x=1456, y=116, 400x380)
            DamagePanelView(snap: snap)
                .frame(width: 400, height: 380)
                .drawingGroup()
                .position(x: 1656, y: 306)

            // GPS (x=1456, y=512, 400x424)
            GPSPanelView(snap: snap)
                .frame(width: 400, height: 424)
                .drawingGroup()
                .position(x: 1656, y: 724)
            }

            if layout.showBottomCards {
            // Combustible (x=486, y=794, 240x142)
            CompactFuelPanelView(snap: snap)
                .frame(width: 240, height: 142)
                .drawingGroup()
                .position(x: 606, y: 865)

            // Avisos (x=742, y=794, 438x142)
            AdvisoryCardView(snap: snap, messages: messages)
                .frame(width: 438, height: 142)
                .drawingGroup()
                .position(x: 961, y: 865)

            // Clima (x=1196, y=794, 237x142)
            WeatherPanelView(snap: snap)
                .frame(width: 237, height: 142)
                .drawingGroup()
                .position(x: 1314, y: 865)
            }

            // Pie (linea en y=984, texto en y=1008)
            FooterView(snap: snap)
                .frame(width: 1920, height: 76)
                .position(x: 960, y: 1042)
        }
        .frame(width: 1920, height: 1080)
    }
}

// MARK: - Vertical gauge (FH6)
enum VerticalGaugeKind { case water, air }

struct VerticalGaugeView: View {
    let snap: Snap
    let kind: VerticalGaugeKind
    @State private var ignitionStart: Date? = nil
    @State private var prevEngine: Bool = false
    @State private var smoothedFraction: Double = 0
    @State private var animatedGauge = AnimatedValue()
    @State private var lastFrame: Date = Date()
    private func smoothStep(_ t: Double) -> Double {
        let c = min(1, max(0, t)); return c*c*(3-2*c)
    }

    private var realFraction: Double {
        switch kind {
        case .water:
            guard let v = snap.waterTemp else { return 0 }
            let c = Double(v)
            let f = isImperial ? (c * 9.0 / 5.0 + 32.0) : c
            return min(1, max(0, (f - (isImperial ? 104.0 : 40.0)) / (isImperial ? 144.0 : 80.0)))
        case .air:
            guard let v = snap.airPressure else { return 0 }
            return min(1, max(0, Double(v) / 120))
        }
    }

    private var fraction: Double {
        guard snap.active, snap.engine, let start = ignitionStart else { return smoothedFraction }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed >= 2.1 { return smoothedFraction }
        if elapsed < 0.9 { return smoothStep(elapsed/0.9) }
        if elapsed < 1.05 { return 1.0 }
        return 1.0 + (smoothedFraction - 1.0) * smoothStep((elapsed-1.05)/1.05)
    }

    private var value: Double? {
        switch kind {
        case .water:
            guard let v = snap.waterTemp else { return nil }
            return isImperial ? (Double(v) * 9.0 / 5.0 + 32.0) : Double(v)
        case .air: return snap.airPressure.map(Double.init)
        }
    }

    private var topLabel: String { kind == .water ? (isImperial ? "248" : "120") : "120" }
    private var bottomLabel: String { kind == .water ? (isImperial ? "104" : "40") : "0" }
    private var isImperial: Bool { UserDefaults.standard.integer(forKey: "ATS.units") == 1 }
    private var unit: String {
        if kind == .water { return isImperial ? "°F" : "°C" }
        return "PSI"
    }
    private var title: String { kind == .water ? "TEMPERATURA" : "PRESIÓN" }

    private var barColor: Color {
        switch kind {
        case .water:
            // azul -> cian -> verde -> amarillo -> naranja -> rojo
            let f = fraction
            if f < 0.25 { return ATSColor.blue }
            if f < 0.5 { return ATSColor.cyan }
            if f < 0.65 { return ATSColor.green }
            if f < 0.8 { return ATSColor.yellow }
            if f < 0.9 { return ATSColor.orange }
            return ATSColor.red
        case .air:
            // rojo (vacio) -> cian (lleno)
            let f = fraction
            if f < 0.25 { return ATSColor.red }
            if f < 0.5 { return ATSColor.orange }
            if f < 0.75 { return ATSColor.yellow }
            return ATSColor.cyan
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 14, height: 253)
                RoundedRectangle(cornerRadius: 5)
                    .fill(barColor)
                    .frame(width: 10, height: 316 * fraction)

                // Etiquetas en los extremos
                Text(topLabel)
                    .font(.system(size: FS(9), weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                    .offset(x: -26, y: -306)
                Text(bottomLabel)
                    .font(.system(size: FS(9), weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                    .offset(x: -26, y: 0)
            }
            .frame(width: 88, height: 316, alignment: .bottom)

            VStack(spacing: 2) {
                Text(value.map { String(Int($0.rounded())) } ?? "--")
                    .font(.system(size: FS(28), weight: .semibold, design: .default))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: FS(10), weight: .regular, design: .default))
                    .foregroundColor(.white.opacity(0.6))
                Text(title)
                    .font(.system(size: FS(6.5), weight: .semibold, design: .default))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.55))
            }
            .frame(width: 88, height: 103)
        }
        .frame(width: 70, height: 352)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.022))
        )
        .onChange(of: snap.engine) { _, newValue in
            if newValue && !prevEngine { ignitionStart = Date() }
            prevEngine = newValue
            if !newValue { ignitionStart = nil }
        }
        .onAppear {
            if snap.active && snap.engine { ignitionStart = Date() }
            prevEngine = snap.engine
            smoothedFraction = realFraction
            animatedGauge.snap(realFraction)
            lastFrame = Date()
        }
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { _ in
            let now = Date()
            let dt = min(0.05, max(0, now.timeIntervalSince(lastFrame)))
            lastFrame = now
            let target = snap.active ? realFraction : 0
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || UserDefaults.standard.bool(forKey: "ATS.reduceMotion") {
                animatedGauge.snap(target)
            } else {
                animatedGauge.update(target: target, dt: dt)
            }
            smoothedFraction = animatedGauge.current
        }
    }
}

// MARK: - Advisory card (FH6)
struct AdvisoryCardView: View {
    let snap: Snap
    @ObservedObject var messages: GameMessageStore

    private var status: String {
        if snap.demo { return "DEMO" }
        return snap.active ? "EN VIVO" : L10n.t("no.signal")
    }

    private var message: String? { messages.currentMessage }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: messages.currentType.icon)
                    .foregroundColor(messages.currentType.color)
                    .font(.system(size: FS(14)))
                Text(L10n.t("panel.advisory"))
                    .font(.system(size: FS(11), weight: .semibold, design: .default))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(status)
                    .font(.system(size: FS(10), weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
            if let msg = message {
                Text(msg)
                    .font(.system(size: FS(16), weight: .semibold, design: .default))
                    .foregroundColor(messages.currentType.color)
                    .opacity(messages.opacity)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            } else {
                Text(L10n.t("no.advisory"))
                    .font(.system(size: FS(24), weight: .semibold, design: .default))
                    .foregroundColor(ATSColor.orange.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Spacer()
            Text(L10n.t("advisory.footer"))
                .font(.system(size: FS(9), weight: .regular, design: .default))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(10)
        .background(messages.currentMessage == nil ? Color.white.opacity(0.04) : messages.currentType.color.opacity(0.08))
    }
}

// MARK: - Background
struct GridBackground: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.white.opacity(0.022), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 920
            )

            Canvas { context, size in
                var path = Path()
                let step: CGFloat = 60

                for x in stride(from: CGFloat(0), through: size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: CGFloat(0), through: size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }

                context.stroke(
                    path,
                    with: .color(.white.opacity(0.024)),
                    style: StrokeStyle(lineWidth: 1)
                )
            }
        }
        .frame(width: 1920, height: 1080)
        .allowsHitTesting(false)
    }
}

// MARK: - Header
struct HeaderView: View {
    let snap: Snap
    var layout: LayoutMode = .full

    private var status: (text: String, color: Color) {
        if snap.demo {
            return ("DEMO", ATSColor.cyan)
        }
        if !snap.active {
            return ("ESPERANDO ATS", ATSColor.orange)
        }
        if snap.paused {
            return ("PAUSA", ATSColor.yellow)
        }
        if snap.ats {
            return ("EN LÍNEA", ATSColor.green)
        }
        return ("ETS2", ATSColor.cyan)
    }

    private var truckRef: String {
        guard snap.active else { return L10n.t("no.truck") }

        let brand = snap.truckBrand?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = snap.truckName?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let brand, let name else {
            return (name ?? brand ?? L10n.t("no.truck")).uppercased()
        }

        if name.localizedCaseInsensitiveContains(brand) {
            return name.uppercased()
        }
        return "\(brand) \(name)".uppercased()
    }

    private var displacement: String? {
        guard snap.active else { return nil }
        return engineDisplacement(for: snap.truckId)
            ?? engineDisplacement(for: snap.truckName)
    }

    var body: some View {
        ZStack {
            HStack(alignment: .center) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 9, height: 9)
                        .shadow(color: status.color.opacity(0.8), radius: 8)

                    Text(L10n.t("header.ats"))
                        .font(.system(size: FS(24), weight: .heavy, design: .default))
                        .tracking(8)
                        .foregroundColor(.white)

                    Text(L10n.t("header.telemetry"))
                        .font(.system(size: FS(15), weight: .semibold, design: .default))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.30))
                }

                Spacer()

                if layout != .full {
                    HStack(spacing: 4) {
                        Image(systemName: snap.weather == .clear ? "sun.max.fill" : (snap.weather == .rain ? "cloud.rain.fill" : "cloud.fill"))
                            .font(.system(size: FS(12)))
                            .foregroundColor(ATSColor.cyan)
                        Text(snap.active ? String(format: "%02d:%02d", (snap.gameTime ?? 0) / 60 % 24, (snap.gameTime ?? 0) % 60) : "--:--")
                            .font(.system(size: FS(11), weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.trailing, 8)
                }

                HStack(spacing: 12) {
                    Text(status.text)
                        .font(.system(size: FS(14), weight: .semibold, design: .default))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.62))

                    Text(snap.active ? "EN LÍNEA" : "SIN SEÑAL")
                        .font(.system(size: FS(14), weight: .medium, design: .default))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.24))

                    // Botones visibles solo en modo Full
                    if layout == .full {
                    HStack(spacing: 6) {
                        Button(action: { (NSApp.delegate as? AppDelegate)?.openSettings() }) {
                            Text("AJUSTES")
                                .font(.system(size: FS(10), weight: .bold, design: .default))
                                .tracking(1.5)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button(action: { (NSApp.delegate as? AppDelegate)?.openCredits() }) {
                            Text("CRÉDITOS")
                                .font(.system(size: FS(10), weight: .bold, design: .default))
                                .tracking(1.5)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    }  // end if layout == .full
                }
            }

            HStack(spacing: 10) {
                if let brand = snap.truckBrand,
                   let logo = BrandLogoLoader.image(brand: brand) {
                    Image(nsImage: logo)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(height: 32)
                }

                VStack(spacing: 1) {
                    Text(truckRef)
                        .font(.system(size: FS(17), weight: .semibold, design: .default))
                        .tracking(2.4)
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(1)

                    if let displacement {
                        Text(displacement)
                            .font(.system(size: FS(10.5), weight: .regular, design: .default))
                            .tracking(1.4)
                            .foregroundColor(.white.opacity(0.40))
                    }
                }
            }
        }
        .frame(height: 60)
    }
}

private func engineDisplacement(for value: String?) -> String? {
    guard let raw = value?.lowercased(), !raw.isEmpty else { return nil }

    // ATS does not expose engine displacement through telemetry. These are the
    // reference displacements for the default engine of each truck model.
    if raw.contains("t800") { return "11.9L" }
    if raw.contains("w900") { return "14.9L" }
    if raw.contains("t680") { return "12.9L" }
    if raw.contains("389") { return "12.9L" }
    if raw.contains("579") { return "12.9L" }
    if raw.contains("cascadia") { return "12.8L" }
    if raw.contains("49x") { return "12.8L" }
    if raw.contains("5700") { return "12.8L" }
    if raw.contains("57x") { return "12.8L" }
    if raw.contains("anthem") { return "12.8L" }
    if raw.contains("pinnacle") { return "12.8L" }
    if raw.contains("vnl") { return "12.8L" }
    if raw.contains("lonestar") { return "12.4L" }
    if raw.contains("9900") { return "14.9L" }
    if raw.contains(".lt") || raw == "lt" { return "12.4L" }
    return nil
}

// MARK: - Footer
struct FooterView: View {
    let snap: Snap

    var body: some View {
        HStack {
            Text("v3.0 · \(snap.active ? (snap.truckBrand ?? "ATS") : "—")")
                .font(.system(size: FS(12), weight: .medium, design: .monospaced))
                .tracking(1)
                .foregroundColor(.white.opacity(0.22))

            Spacer()

            Text(snap.active ? "EN LÍNEA · \(Date().formatted(date: .omitted, time: .shortened))" : "SIN SEÑAL")
                .font(.system(size: FS(11), weight: .semibold, design: .monospaced))
                .foregroundColor(snap.active ? ATSColor.green.opacity(0.7) : ATSColor.orange.opacity(0.6))

            Spacer()

            Text(snap.demo ? "DATOS DE PRUEBA" : (snap.active ? "DATOS EN VIVO" : L10n.t("no.signal")))
                .font(.system(size: FS(11), weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundColor(
                    snap.demo
                        ? ATSColor.cyan.opacity(0.75)
                        : (snap.active ? ATSColor.green.opacity(0.75) : ATSColor.orange.opacity(0.65))
                )

            Spacer()

            Button(action: { NSApp.terminate(nil) }) {
                Text("SALIR")
                    .font(.system(size: FS(11), weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(height: 30)
    }
}

// MARK: - Indicator lights
private enum IndicatorIcon {
    private static var cache: [String: NSImage] = [:]

    static func image(named name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        // Los iconos estan en Contents/Resources/Indicators/ (y tambien en la raiz).
        let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Indicators")
            ?? Bundle.main.url(forResource: name, withExtension: "png")
        guard let u = url, let image = NSImage(contentsOf: u) else {
            return nil
        }
        cache[name] = image
        return image
    }
}

struct IndicatorRowView: View {
    let snap: Snap
    @State private var ignitionStart: Date? = nil
    @State private var prevEngine: Bool = false

    private var allLampsOn: Bool {
        guard let start = ignitionStart else { return false }
        return Date().timeIntervalSince(start) < 1.25
    }

    private var airBrakeWarning: Bool {
        guard snap.active, let pressure = snap.airPressure else { return false }
        let air = Double(pressure)
        if let emergency = snap.airEmergency, air <= Double(emergency) { return true }
        if let warn = snap.airWarn, air <= Double(warn) { return true }
        return false
    }

    private var airBrakeColor: Color {
        guard let pressure = snap.airPressure else { return ATSColor.red }
        if let emergency = snap.airEmergency, Double(pressure) <= Double(emergency) {
            return ATSColor.red
        }
        return ATSColor.orange
    }

    var body: some View {
        HStack(spacing: 18) {
            indicator("beacon-c", "light.max", (snap.active && snap.engine && snap.beacon) || allLampsOn, ATSColor.yellow, pulses: true)
            indicator("side-markers-c", "parkingsign", (snap.active && snap.engine && snap.parking) || allLampsOn, ATSColor.green)
            indicator("low-beam-c", "lightbulb.fill", (snap.active && snap.engine && snap.lowB) || allLampsOn, ATSColor.green)
            indicator("high-beam-c", "sun.max.fill", (snap.active && snap.engine && snap.highB) || allLampsOn, ATSColor.blue)
            indicator("brake-c1", "octagon.fill", (snap.active && snap.engine && snap.brake) || allLampsOn, ATSColor.red)

            indicator("turn-lights-left-c", "arrow.left", (snap.active && snap.engine && snap.blinkL) || allLampsOn, ATSColor.green)
            CheckEngineCell(
                active: (snap.active && snap.engine && (snap.engineDmg ?? 0) >= 5) || allLampsOn,
                engineOn: snap.active && snap.engine
            )
            indicator("turn-lights-right-c", "arrow.right", (snap.active && snap.engine && snap.blinkR) || allLampsOn, ATSColor.green)

            indicator("parking-brake-2-c", "hand.raised.fill", (snap.active && snap.engine && snap.park) || allLampsOn, ATSColor.red, pulses: true)
            indicator("retarder-c", "gauge.medium", (snap.active && snap.engine && snap.retarder) || allLampsOn, ATSColor.green)
            indicator("engine-brake-round", "engine.combustion", (snap.active && snap.engine && snap.motor) || allLampsOn, ATSColor.green)
            indicator("wiper-c", "drop.fill", (snap.active && snap.engine && (snap.wipers > 0)) || allLampsOn, ATSColor.cyan, pulses: true)
            indicator("diff-lock-c", "gearshape.2.fill", (snap.active && snap.engine && snap.diffLock) || allLampsOn, ATSColor.orange, pulses: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 0)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.016))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.047), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity)
        .onChange(of: snap.engine) { _, newValue in
            if newValue && !prevEngine {
                ignitionStart = Date()
            }
            prevEngine = newValue
        }
    }

    private func indicator(
        _ iconName: String,
        _ fallbackIcon: String,
        _ active: Bool,
        _ color: Color,
        pulses: Bool = false
    ) -> some View {
        IndicatorIconView(
            iconName: iconName,
            fallbackIcon: fallbackIcon,
            active: active,
            activeColor: color,
            pulses: pulses
        )
    }
}

struct IndicatorIconView: View {
    let iconName: String
    let fallbackIcon: String
    let active: Bool
    let activeColor: Color
    var pulses = false

    private var foreground: Color {
        active ? activeColor : Color.white.opacity(0.20)
    }

    var body: some View {
        Group {
            if let icon = IndicatorIcon.image(named: iconName) {
                Image(nsImage: icon)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: FS(22), weight: .bold))
                    .foregroundColor(active ? activeColor : Color.white.opacity(0.40))
                    .frame(width: 40, height: 40)
            }
        }
        .shadow(color: active ? activeColor.opacity(0.35) : .clear, radius: 6)
        .modifier(IndicatorPulse(active: active, pulses: pulses))
        .frame(height: 46)
    }
}

private struct IndicatorPulse: ViewModifier {
    let active: Bool
    let pulses: Bool

    static func reduceMotion(active: Bool, pulses: Bool) -> Bool {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return true }
        if UserDefaults.standard.bool(forKey: "ATS.reduceMotion") { return true }
        return !(active && pulses)
    }

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: Self.reduceMotion(active: active, pulses: pulses))) { context in
            let phase = (active && pulses)
                ? (sin(context.date.timeIntervalSinceReferenceDate * 2 * Double.pi / 1.05) + 1) / 2
                : 1.0

            content
                .opacity(active
                    ? (pulses ? 0.60 + 0.40 * phase : 1.0)
                    : 0.20)
        }
    }
}

// MARK: - Check engine cell (FH6)
struct CheckEngineCell: View {
    let active: Bool
    let engineOn: Bool

    var body: some View {
        Group {
            if engineOn {
                HStack(spacing: 4) {
                    if let icon = IndicatorIcon.image(named: "check-engine-line") {
                        Image(nsImage: icon)
                            .renderingMode(active ? .original : .template)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundColor(active ? ATSColor.yellow : Color.white.opacity(0.25))
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: FS(20), weight: .bold))
                            .foregroundColor(active ? ATSColor.yellow : Color.white.opacity(0.25))
                            .frame(width: 26, height: 26)
                    }

                    VStack(alignment: .leading, spacing: -2) {
                        Text("CHECK")
                            .font(.system(size: FS(9), weight: .bold, design: .default))
                            .foregroundColor(active ? ATSColor.yellow : Color.white.opacity(0.35))
                        Text(L10n.t("checkengine.engine"))
                            .font(.system(size: FS(9), weight: .bold, design: .default))
                            .foregroundColor(active ? ATSColor.yellow : Color.white.opacity(0.35))
                    }
                }
            }
        }
        .frame(width: 88, height: 32)
        .modifier(IndicatorPulse(active: active && engineOn, pulses: active))
    }
}

// MARK: - Trip
struct TripBadgeView: View {
    let snap: Snap

    private struct Trip {
        let travelled: Int
        let planned: Int
        let remaining: Int
        let eta: String?
    }

    private static let kmFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }()

    private var trip: Trip? {
        guard snap.active, snap.onJob,
              let plannedValue = snap.planned, plannedValue > 0,
              let routeDistance = snap.routeD
        else {
            return nil
        }

        let planned = Int(plannedValue)
        let remaining = max(0, Int((Double(routeDistance) / 1_000.0).rounded()))
        let travelled = max(0, planned - remaining)
        return Trip(
            travelled: travelled,
            planned: planned,
            remaining: remaining,
            eta: etaText
        )
    }

    private var etaText: String? {
        guard let time = snap.routeT, time > 0, time < 172_800 else { return nil }
        let minutes = max(0, Int((Double(time) / 60.0).rounded()))
        let hours = minutes / 60
        let rest = minutes % 60
        return hours > 0 ? "\(hours)h \(rest)m" : "\(rest) min"
    }

    private func km(_ value: Int) -> String {
        TripBadgeView.kmFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let trip {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(km(trip.travelled))
                        .font(.system(size: FS(28), weight: .bold, design: .default))
                        .monospacedDigit()
                        .foregroundColor(ATSColor.green)
                        .lineLimit(1)

                    Text("/ \(km(trip.planned)) km")
                        .font(.system(size: FS(11.5), weight: .medium, design: .default))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.34))
                        .lineLimit(1)
                }

                Text(
                    trip.eta.map { "FALTAN \(km(trip.remaining)) km · \($0)" }
                        ?? "FALTAN \(km(trip.remaining)) km"
                )
                .font(.system(size: FS(11.5), weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.80)
            } else {
                Text(L10n.t("no.trip"))
                    .font(.system(size: FS(13), weight: .semibold, design: .default))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.34))

                Text(snap.active ? L10n.t("no.routeactive") : L10n.t("no.signal"))
                    .font(.system(size: FS(10.5), weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(width: 220, height: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.020))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ATSColor.cyan.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

// MARK: - Damage
struct DamagePanelView: View {
    let snap: Snap

    private var truck: Double? {
        guard snap.active, let value = snap.truckDmg else { return nil }
        return Double(value)
    }

    private var trailer: Double? {
        guard snap.active, let value = snap.trailerDmg else { return nil }
        return Double(value)
    }

    private var cargo: Double? {
        guard snap.active, let value = snap.cargoDmg else { return nil }
        return Double(value)
    }

    private var maxDamage: Double? {
        [truck, trailer, cargo].compactMap { $0 }.max()
    }

    private var headerColor: Color {
        guard let maxDamage else { return Color.white.opacity(0.32) }
        if maxDamage >= 50 { return ATSColor.red }
        if maxDamage >= 20 { return ATSColor.orange }
        if maxDamage >= 5 { return ATSColor.yellow }
        return ATSColor.green
    }

    private var statusText: String {
        guard let maxDamage else { return L10n.t("no.data") }
        if maxDamage >= 50 { return "CRÍTICO" }
        if maxDamage >= 20 { return "REVISAR" }
        if maxDamage >= 5 { return "LEVE" }
        return "OK"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                if let icon = IndicatorIcon.image(named: "advisor-diagnostics") {
                    Image(nsImage: icon)
                        .renderingMode(.template)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 21, height: 21)
                        .foregroundColor(headerColor)
                }

                Text(L10n.t("panel.damage"))
                    .font(.system(size: FS(16), weight: .bold, design: .default))
                    .tracking(3.5)
                    .foregroundColor(.white.opacity(0.62))

                Spacer(minLength: 0)

                Text(statusText)
                    .font(.system(size: FS(10), weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(headerColor.opacity(0.85))
            }

            VStack(spacing: 12) {
                DamageRowView(label: "CAMIÓN", value: truck)
                DamageRowView(label: "TRÁILER", value: trailer)
                DamageRowView(label: "CARGA", value: cargo)
            }

            if snap.active {
                let key = TruckImageLoader.name(for: snap)
                ZStack(alignment: .bottom) {
                    if let img = TruckImageLoader.image(named: key) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity)
                            .id(key ?? "")
                            .overlay(
                                LinearGradient(colors: [.clear, .black.opacity(0.45)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                    } else {
                        EmptyStateView(message: L10n.t("no.image"), hint: nil)
                    }
                    if snap.active, let name = snap.truckName, !name.isEmpty {
                        Text(name.uppercased())
                            .font(.system(size: FS(9), weight: .bold, design: .default))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.45))
                            .padding(.bottom, 4)
                    }
                }
                .frame(width: 360, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .animation(.easeInOut(duration: 0.5), value: key)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text(L10n.t("damage.damage"))
                    .font(.system(size: FS(9), weight: .bold, design: .default))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.28))

                Text("5% · 20% · 50%")
                    .font(.system(size: FS(9), weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.22))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.022))
        )
    }
}

struct DamageRowView: View {
    let label: String
    let value: Double?

    private var fraction: Double {
        guard let value else { return 0 }
        return min(max(value / 100, 0), 1)
    }

    private var color: Color {
        guard let value else { return Color.white.opacity(0.25) }
        if value >= 50 { return ATSColor.red }
        if value >= 20 { return ATSColor.orange }
        if value >= 5 { return ATSColor.yellow }
        return ATSColor.green
    }

    private var text: String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    private var severityText: String {
        guard let value else { return "" }
        if value >= 50 { return "CRÍTICO" }
        if value >= 20 { return "REVISAR" }
        if value >= 5 { return "LEVE" }
        return "OK"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.system(size: FS(12.5), weight: .bold, design: .default))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.45))

                Spacer(minLength: 0)

                Text(text)
                    .font(.system(size: FS(22), weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundColor(color)

                if let value, value >= 5 {
                    Text(severityText)
                        .font(.system(size: FS(9), weight: .bold, design: .default))
                        .tracking(1)
                        .foregroundColor(color.opacity(0.8))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))

                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Speed arc (FH6 224°)
struct SpeedArcView: View {
    let value: Double          // km/h
    let maxValue: Double       // 160
    let accent: Color
    let valueText: String
    let unitText: String
    let subtitle: String
    let odometerText: String
    let odometerColor: Color
    let markerValue: Double?   // limit km/h
    let markerColor: Color

    private let startDeg = 158.0
    private let sweepDeg = 224.0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size * 0.43

            ZStack {
                // Background arc
                ArcShape(startDeg: startDeg, sweepDeg: sweepDeg)
                    .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: size, height: size)

                // Filled arc
                ArcShape(startDeg: startDeg, sweepDeg: sweepDeg * min(1, max(0, value / maxValue)))
                    .stroke(accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: size, height: size)
                    .shadow(color: accent.opacity(0.35), radius: 6)

                // Tick marks every 20 km/h
                ForEach(0..<10, id: \.self) { i in
                    let kmh = Double(i) * 20.0
                    let frac = kmh / maxValue
                    let deg = startDeg + frac * sweepDeg
                    let rad = deg * .pi / 180
                    let outer = radius + 18
                    let inner = radius + 6
                    Path { p in
                        p.move(to: CGPoint(x: center.x + cos(rad) * inner,
                                           y: center.y + sin(rad) * inner))
                        p.addLine(to: CGPoint(x: center.x + cos(rad) * outer,
                                              y: center.y + sin(rad) * outer))
                    }
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                }

                // Numeric labels at ticks
                ForEach(0..<10, id: \.self) { i in
                    let kmh = Double(i) * 20.0
                    let frac = kmh / maxValue
                    let deg = startDeg + frac * sweepDeg
                    let rad = deg * .pi / 180
                    let labelRadius = radius + 30
                    Text("\(Int(kmh))")
                        .font(.system(size: FS(9), weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        .position(x: center.x + cos(rad) * labelRadius,
                                  y: center.y + sin(rad) * labelRadius)
                }

                // Limit marker
                if let mv = markerValue {
                    let frac = min(1, max(0, mv / maxValue))
                    let deg = startDeg + frac * sweepDeg
                    let rad = deg * .pi / 180
                    Path { p in
                        p.move(to: CGPoint(x: center.x + cos(rad) * (radius - 10),
                                           y: center.y + sin(rad) * (radius - 10)))
                        p.addLine(to: CGPoint(x: center.x + cos(rad) * (radius + 26),
                                              y: center.y + sin(rad) * (radius + 26)))
                    }
                    .stroke(markerColor, lineWidth: 3)
                }

                // Center number
                VStack(spacing: 2) {
                    Text(valueText)
                        .font(.system(size: FS(184), weight: .light, design: .default))
                        .monospacedDigit()
                        .foregroundColor(accent)
                    Text(unitText)
                        .font(.system(size: FS(14), weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.55))
                    Text(subtitle)
                        .font(.system(size: FS(11), weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.40))
                }
                .offset(y: -20)

                // Odometer pill
                Text(odometerText + " km")
                    .font(.system(size: FS(13), weight: .semibold, design: .monospaced))
                    .foregroundColor(odometerColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .offset(y: 188)
            }
        }
    }

    private var snapActiveColor: Color { accent }
}

private struct ArcShape: Shape {
    let startDeg: Double
    let sweepDeg: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        p.addArc(center: center, radius: r, startAngle: .degrees(startDeg),
                 endAngle: .degrees(startDeg + sweepDeg), clockwise: false)
        return p
    }
}

// MARK: - Warning lamp (FH6)
struct WarningLampView: View {
    let symbol: String
    let active: Bool
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(active ? color.opacity(0.18) : Color.white.opacity(0.04))
            Circle()
                .stroke(active ? color.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
            Image(systemName: symbol)
                .font(.system(size: FS(16), weight: .semibold))
                .foregroundColor(active ? color : Color(red: 0.14, green: 0.14, blue: 0.14))
        }
        .frame(width: 32, height: 32)
        .shadow(color: active ? color.opacity(0.5) : .clear, radius: 4)
    }
}


// MARK: - RPM bar (FH6)
struct RpmBarView: View {
    let snap: Snap
    @State private var ignitionStart: Date? = nil
    @State private var prevEngine: Bool = false
    @State private var smoothedRpm: Double = 0
    @State private var animatedRpm = AnimatedValue()
    @State private var lastFrame: Date = Date()

    private func smoothStep(_ t: Double) -> Double { let c=min(1,max(0,t)); return c*c*(3-2*c) }

    private var rpm: Double {
        guard snap.active, let v = snap.rpm else { return 0 }
        return Double(v)
    }
    private var maxRpm: Double {
        let v = Double(snap.rpmMax ?? 0)
        return v >= 800 ? v : 2500
    }
    private var realFraction: Double { maxRpm > 0 ? min(1, rpm / maxRpm) : 0 }
    private var animatedFraction: Double {
        guard snap.active, snap.engine, let start = ignitionStart else { return smoothedRpm / max(1, maxRpm) }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed >= 2.1 { return smoothedRpm / max(1, maxRpm) }
        if elapsed < 0.9 { return smoothStep(elapsed/0.9) }
        if elapsed < 1.05 { return 1.0 }
        return 1.0 + (smoothedRpm / max(1, maxRpm) - 1.0) * smoothStep((elapsed-1.05)/1.05)
    }
    private var fraction: Double { animatedFraction }

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 330, height: 14)
                RoundedRectangle(cornerRadius: 7)
                    .fill(LinearGradient(colors: [ATSColor.green, ATSColor.yellow, ATSColor.red],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 330 * fraction, height: 14)
                // redline mark at 92%
                Rectangle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 2, height: 18)
                    .offset(x: 330 * 0.92 - 1)
            }
            .frame(width: 330, height: 14)
            Text(snap.active ? "\(Int(rpm.rounded())) RPM" : "-- RPM")
                .font(.system(size: FS(10), weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .onChange(of: snap.engine) { _, newValue in
            if newValue && !prevEngine { ignitionStart = Date() }
            prevEngine = newValue
            if !newValue { ignitionStart = nil }
        }
        .onAppear {
            if snap.active && snap.engine { ignitionStart = Date() }
            prevEngine = snap.engine
            smoothedRpm = rpm
        }
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { _ in
            let now = Date()
            let dt = min(0.05, max(0, now.timeIntervalSince(lastFrame)))
            lastFrame = now
            let target = snap.active ? rpm : 0
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || UserDefaults.standard.bool(forKey: "ATS.reduceMotion") {
                animatedRpm.snap(target)
            } else {
                animatedRpm.update(target: target, dt: dt)
            }
            smoothedRpm = animatedRpm.current
        }
    }
}


// MARK: - Gear box (FH6)
struct GearBoxView: View {
    let snap: Snap
    private var gearText: String {
        guard snap.active, let gear = snap.gear else { return "--" }
        if gear > 0 { return String(gear) }
        if gear == 0 { return "N" }
        return "R"
    }
    private var gearColor: Color {
        guard snap.active, let gear = snap.gear else { return Color.white.opacity(0.30) }
        if gear < 0 { return ATSColor.red }
        if gear == 0 { return ATSColor.cyan }
        return .white
    }
    var body: some View {
        VStack(spacing: 0) {
            Text(gearText)
                .font(.system(size: FS(42), weight: .bold, design: .default))
                .foregroundColor(gearColor)
        }
        .frame(width: 70, height: 64)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Speedometer
struct SpeedometerView: View {
    let snap: Snap
    @State private var ignitionStart: Date? = nil
    @State private var prevEngine: Bool = false
    @State private var animatedSpeedValue = AnimatedValue()
    @State private var lastFrame: Date = Date()
    @State private var smoothedSpeed: Double = 0

    private let maxSpeed = 180.0

    private func smoothStep(_ t: Double) -> Double {
        let c = min(1, max(0, t))
        return c * c * (3 - 2 * c)
    }

    private var animatedSpeed: Double {
        let real = min(speedKmh, maxSpeed)
        guard snap.active, snap.engine, let start = ignitionStart else { return real }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed >= 2.1 { return real }
        if elapsed < 0.9 {
            return 180.0 * smoothStep(elapsed / 0.9)
        } else if elapsed < 1.05 {
            return 180.0
        } else {
            return 180.0 + (real - 180.0) * smoothStep((elapsed - 1.05) / 1.05)
        }
    }

    private var speedKmh: Double {
        abs(Double(snap.speed ?? 0)) * 3.6
    }

    private var limitKmh: Double? {
        guard snap.active, let limit = snap.limit, limit > 0.5 else { return nil }
        return Double(limit) * 3.6
    }

    private var accent: Color {
        guard snap.active else { return Color.white.opacity(0.30) }
        if let limitKmh, speedKmh > limitKmh + 1.0 { return ATSColor.orange }
        return ATSColor.cyan
    }

    private var valueText: String {
        guard snap.active, snap.speed != nil else { return "--" }
        return String(Int(speedKmh.rounded()))
    }

    private var subtitle: String {
        if let limitKmh {
            return "LÍMITE \(Int(limitKmh.rounded()))"
        }
        return "MÁX \(Int(maxSpeed))"
    }

    private var cruiseSetKmh: Double? {
        guard snap.active, snap.cruiseOn, let set = snap.cruise, set > 0.5 else { return nil }
        return Double(set) * 3.6
    }

    private var odometerText: String {
        guard snap.active, let odometer = snap.odometer, odometer >= 0 else {
            return "--"
        }
        return String(Int(odometer.rounded()))
    }

    private var odometerColor: Color {
        snap.active ? ATSColor.cyan : Color.white.opacity(0.25)
    }

    private var displaySpeed: Double {
        if snap.active && snap.engine && ignitionStart != nil {
            let elapsed = Date().timeIntervalSince(ignitionStart!)
            if elapsed < 2.1 { return animatedSpeed }
        }
        return smoothedSpeed
    }

    var body: some View {
        ZStack {
            SpeedArcView(
                value: displaySpeed,
                maxValue: maxSpeed,
                accent: accent,
                valueText: valueText,
                unitText: "km/h",
                subtitle: subtitle,
                odometerText: odometerText,
                odometerColor: odometerColor,
                markerValue: limitKmh,
                markerColor: ATSColor.red
            )

            GaugeBadge(active: cruiseSetKmh != nil, accent: ATSColor.green) {
                CruiseBadgeContent(speedKmh: cruiseSetKmh)
            }
            .offset(y: -160)

            // Testigos de bateria y presion de aceite (FH6)
            WarningLampView(
                symbol: "battery.25",
                active: snap.active && snap.engine && (snap.batteryVoltage ?? 27) < (snap.batteryWarn ?? 23.76),
                color: ATSColor.red
            )
            .offset(x: -97.5, y: 34)

            WarningLampView(
                symbol: "drop.fill",
                active: snap.active && snap.engine && (snap.oilPressure ?? 60) < (snap.oilWarn ?? 14),
                color: ATSColor.red
            )
            .offset(x: 65.5, y: 34)
        }
        .onChange(of: snap.engine) { _, newValue in
            if newValue && !prevEngine { ignitionStart = Date() }
            prevEngine = newValue
            if !newValue { ignitionStart = nil }
        }
        .onAppear {
            if snap.active && snap.engine { ignitionStart = Date() }
            prevEngine = snap.engine
            smoothedSpeed = min(speedKmh, maxSpeed)
            animatedSpeedValue.snap(min(speedKmh, maxSpeed))
            lastFrame = Date()
        }
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { _ in
            let now = Date()
            let dt = min(0.05, max(0, now.timeIntervalSince(lastFrame)))
            lastFrame = now
            let target = min(speedKmh, maxSpeed)
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || UserDefaults.standard.bool(forKey: "ATS.reduceMotion") {
                animatedSpeedValue.snap(target)
            } else {
                animatedSpeedValue.update(target: target, dt: dt)
            }
            smoothedSpeed = animatedSpeedValue.current
        }
    }
}

// MARK: - Tachometer
struct TachometerView: View {
    let snap: Snap

    private var gaugeMax: Double {
        let value = Double(snap.rpmMax ?? 0)
        return value >= 800 ? value : 2500
    }

    private var rpm: Double {
        min(max(Double(snap.rpm ?? 0), 0), gaugeMax)
    }

    private var fraction: Double {
        gaugeMax > 0 ? rpm / gaugeMax : 0
    }

    private var majorStep: Double {
        if gaugeMax <= 2600 { return 250 }
        if gaugeMax <= 5200 { return 500 }
        return 1000
    }

    private var accent: Color {
        guard snap.active else { return Color.white.opacity(0.30) }
        if fraction >= 0.90 { return ATSColor.red }
        if fraction >= 0.78 { return ATSColor.orange }
        if fraction >= 0.62 { return ATSColor.yellow }
        return ATSColor.green
    }

    private var rpmText: String {
        guard snap.active, snap.rpm != nil else { return "--" }
        return String(Int(rpm.rounded()))
    }

    private var gearText: String {
        guard snap.active, let gear = snap.gear else { return "--" }
        if gear > 0 { return String(gear) }
        if gear == 0 { return "N" }
        return "R"
    }

    private var gearColor: Color {
        guard snap.active, let gear = snap.gear else { return Color.white.opacity(0.30) }
        if gear < 0 { return ATSColor.red }
        if gear == 0 { return ATSColor.cyan }
        return ATSColor.green
    }

    // REV12 does not expose the check-engine lamp. Offset 1576 is
    // engineEnabled (engine running), so use engine wear as the warning source.
    private var checkEngineActive: Bool {
        guard snap.active, snap.engine, let damage = snap.engineDmg else { return false }
        return damage >= 5
    }

    var body: some View {
        ZStack {
            DialGaugeView(
                value: rpm,
                maxValue: gaugeMax,
                majorStep: majorStep,
                accent: accent,
                redlineStart: 0.86,
                valueText: rpmText,
                unitText: "RPM",
                subtitle: "MÁX \(Int(gaugeMax))",
                badgeLabel: "MARCHA",
                badgeValue: gearText,
                badgeUnit: nil,
                badgeColor: gearColor,
                markerValue: nil,
                markerColor: .clear,
                contentOffsetY: 0.205
            )

            GaugeBadge(active: checkEngineActive, accent: ATSColor.yellow) {
                if checkEngineActive {
                    // Keep the icon at its previous 85 % size while the frame
                    // matches the cruise-control badge dimensions.
                    CheckEngineIndicatorView()
                        .scaleEffect(0.85)
                }
            }
            .offset(y: -160)
        }
    }
}

private struct CheckEngineIndicatorView: View {
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "engine.combustion.fill")
                .font(.system(size: FS(38), weight: .semibold))

            Text("CHECK")
                .font(.system(size: FS(6.5), weight: .bold, design: .default))
                .tracking(1.4)
        }
        .foregroundColor(ATSColor.yellow)
        .shadow(
            color: ATSColor.yellow.opacity(pulsing ? 0.55 : 0.25),
            radius: pulsing ? 8 : 5
        )
        .scaleEffect(pulsing ? 1.035 : 1.0)
        .opacity(pulsing ? 0.82 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

private struct GaugeBadge<Content: View>: View {
    let active: Bool
    let accent: Color
    let content: Content

    init(active: Bool, accent: Color, @ViewBuilder content: () -> Content) {
        self.active = active
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(active ? 0.050 : 0.025))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    active ? accent.opacity(0.42) : Color.white.opacity(0.16),
                    lineWidth: 1
                )

            content
        }
        .frame(width: 118, height: 58)
    }
}

private struct CruiseBadgeContent: View {
    let speedKmh: Double?
    private var active: Bool { speedKmh != nil }

    var body: some View {
        HStack(spacing: 7) {
            if let icon = IndicatorIcon.image(named: "cruise-control-c") {
                Image(nsImage: icon)
                    .renderingMode(active ? .original : .template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundColor(active ? .clear : .white.opacity(0.35))
            } else {
                Image(systemName: "speedometer")
                    .font(.system(size: FS(22), weight: .semibold))
                    .foregroundColor(ATSColor.green)
                    .frame(width: 30, height: 30)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.t("cruise.label"))
                    .font(.system(size: FS(6.5), weight: .bold, design: .default))
                    .tracking(1.2)
                    .foregroundColor(active ? .white.opacity(0.48) : .white.opacity(0.30))

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if let speedKmh {
                        Text("\(Int(speedKmh.rounded()))")
                            .font(.system(size: FS(18), weight: .bold, design: .default))
                            .monospacedDigit()
                            .foregroundColor(ATSColor.green)
                    } else {
                        Text("--")
                            .font(.system(size: FS(18), weight: .bold, design: .default))
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.35))
                    }

                    Text("km/h")
                        .font(.system(size: FS(7), weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.40))
                }
            }
        }
    }
}

// MARK: - Shared dial
struct DialGaugeView: View {
    let value: Double
    let maxValue: Double
    let majorStep: Double
    let accent: Color
    let redlineStart: Double?
    let valueText: String
    let unitText: String
    let subtitle: String?
    let badgeLabel: String?
    let badgeValue: String?
    let badgeUnit: String?
    let badgeColor: Color
    let markerValue: Double?
    let markerColor: Color
    let contentOffsetY: CGFloat

    private var fraction: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / maxValue, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.035), lineWidth: 1)
                    .frame(width: side * 0.985, height: side * 0.985)

                Canvas { context, size in
                    drawGauge(&context, size: size, side: side)
                }
                .frame(width: side, height: side)

                VStack(spacing: side * 0.005) {
                    Text(valueText)
                        .font(.system(size: FS(side * 0.145), weight: .bold, design: .default))
                        .monospacedDigit()
                        .foregroundColor(accent)
                        .shadow(color: accent.opacity(0.30), radius: side * 0.022)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(unitText)
                        .font(.system(size: FS(side * 0.035), weight: .semibold, design: .default))
                        .tracking(side * 0.007)
                        .foregroundColor(.white.opacity(0.52))

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: FS(side * 0.018), weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.25))
                            .padding(.top, side * 0.004)
                    }

                    if let badgeValue {
                        HStack(alignment: .firstTextBaseline, spacing: side * 0.012) {
                            if let badgeLabel {
                                Text(badgeLabel)
                                    .font(.system(size: FS(side * 0.022), weight: .bold, design: .default))
                                    .tracking(side * 0.003)
                                    .foregroundColor(.white.opacity(0.38))
                            }

                            Text(badgeValue)
                                .font(.system(size: FS(side * 0.058), weight: .bold, design: .default))
                                .monospacedDigit()
                                .foregroundColor(badgeColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.70)

                            if let badgeUnit {
                                Text(badgeUnit)
                                    .font(.system(size: FS(side * 0.024), weight: .semibold, design: .default))
                                    .foregroundColor(.white.opacity(0.40))
                            }
                        }
                        .padding(.horizontal, side * 0.030)
                        .padding(.vertical, side * 0.008)
                        .frame(width: 210)
                        .background(Capsule().fill(Color.white.opacity(0.045)))
                        .overlay(Capsule().stroke(badgeColor.opacity(0.25), lineWidth: 1))
                        .padding(.top, side * 0.012)
                    }
                }
                .offset(y: side * contentOffsetY)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func drawGauge(_ context: inout GraphicsContext, size: CGSize, side: CGFloat) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2 + side * 0.012)
        let radius = side * 0.385
        let startAngle = 135.0
        let sweep = 270.0
        let arcWidth = side * 0.028

        // Track
        context.stroke(
            arcPath(center: center, radius: radius, start: startAngle, end: startAngle + sweep),
            with: .color(.white.opacity(0.09)),
            style: StrokeStyle(lineWidth: arcWidth, lineCap: .round)
        )

        // Redline
        if let redlineStart {
            let redStart = startAngle + sweep * redlineStart
            context.stroke(
                arcPath(center: center, radius: radius, start: redStart, end: startAngle + sweep),
                with: .color(ATSColor.red.opacity(0.52)),
                style: StrokeStyle(lineWidth: arcWidth, lineCap: .butt)
            )
        }

        // Live arc
        if fraction > 0.002 {
            context.stroke(
                arcPath(center: center, radius: radius, start: startAngle, end: startAngle + sweep * fraction),
                with: .color(accent),
                style: StrokeStyle(lineWidth: arcWidth, lineCap: .round)
            )
        }

        // Speed limit marker
        if let markerValue, markerValue > 0, markerValue < maxValue {
            let angle = startAngle + sweep * (markerValue / maxValue)
            let marker = Path { path in
                path.move(to: point(center, radius - arcWidth * 0.7, angle))
                path.addLine(to: point(center, radius + arcWidth * 0.7, angle))
            }
            context.stroke(
                marker,
                with: .color(markerColor),
                style: StrokeStyle(lineWidth: side * 0.0055, lineCap: .round)
            )
        }

        // Ticks and labels
        let minorStep = majorStep / 2
        let tickCount = Int((maxValue / minorStep).rounded())

        for i in 0...tickCount {
            let tickValue = Double(i) * minorStep
            if tickValue > maxValue + 0.1 { break }

            let angle = startAngle + sweep * (tickValue / maxValue)
            let isMajor = i % 2 == 0
            let outer = radius + side * 0.020
            let inner = radius + (isMajor ? side * 0.045 : side * 0.034)

            let tick = Path { path in
                path.move(to: point(center, outer, angle))
                path.addLine(to: point(center, inner, angle))
            }

            context.stroke(
                tick,
                with: .color(.white.opacity(isMajor ? 0.62 : 0.22)),
                style: StrokeStyle(
                    lineWidth: isMajor ? side * 0.0037 : side * 0.0022,
                    lineCap: .round
                )
            )

            if isMajor {
                let labelPoint = point(center, radius + side * 0.082, angle)
                context.draw(
                    Text(String(Int(tickValue)))
                        .font(.system(size: FS(side * 0.029), weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.48)),
                    at: labelPoint,
                    anchor: .center
                )
            }
        }

        // Needle
        let needleAngle = startAngle + sweep * fraction
        let tip = point(center, radius * 0.77, needleAngle)
        let tail = point(center, -side * 0.021, needleAngle)

        let needle = Path { path in
            path.move(to: tail)
            path.addLine(to: tip)
        }

        context.stroke(
            needle,
            with: .color(accent.opacity(0.18)),
            style: StrokeStyle(lineWidth: side * 0.034, lineCap: .round)
        )
        context.stroke(
            needle,
            with: .color(accent),
            style: StrokeStyle(lineWidth: side * 0.0092, lineCap: .round)
        )

        // Hub
        let hubSize = side * 0.0295
        let hubRect = CGRect(
            x: center.x - hubSize,
            y: center.y - hubSize,
            width: hubSize * 2,
            height: hubSize * 2
        )
        context.fill(Path(ellipseIn: hubRect), with: .color(.black))
        context.stroke(
            Path(ellipseIn: hubRect),
            with: .color(accent.opacity(0.85)),
            style: StrokeStyle(lineWidth: side * 0.0046)
        )

        let innerHubSize = side * 0.0108
        let innerHub = CGRect(
            x: center.x - innerHubSize,
            y: center.y - innerHubSize,
            width: innerHubSize * 2,
            height: innerHubSize * 2
        )
        context.fill(Path(ellipseIn: innerHub), with: .color(accent.opacity(0.9)))
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: center.x + CGFloat(cos(radians)) * radius,
            y: center.y + CGFloat(sin(radians)) * radius
        )
    }

    private func arcPath(center: CGPoint, radius: CGFloat, start: Double, end: Double) -> Path {
        var path = Path()
        let steps = max(2, Int(abs(end - start) * 2))

        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let angle = start + (end - start) * t
            let p = point(center, radius, angle)
            if i == 0 {
                path.move(to: p)
            } else {
                path.addLine(to: p)
            }
        }

        return path
    }
}

// MARK: - Mini gauges
struct MiniGaugeRow: View {
    let snap: Snap

    private var water: Double? {
        guard snap.active, let value = snap.waterTemp, value > 0 else { return nil }
        return Double(value)
    }

    private var oil: Double? {
        guard snap.active, let value = snap.oilPressure, value >= 0 else { return nil }
        return Double(value)
    }

    private var waterAccent: Color {
        guard let water else { return Color.white.opacity(0.25) }
        if let warn = snap.waterWarn, water >= Double(warn) { return ATSColor.red }
        if water >= 94 { return ATSColor.orange }
        return ATSColor.cyan
    }

    private var oilAccent: Color {
        guard let oil else { return Color.white.opacity(0.25) }
        if oil <= 0 { return Color.white.opacity(0.35) }
        if let warn = snap.oilWarn, oil <= Double(warn) { return ATSColor.red }
        if oil < 30 { return ATSColor.orange }
        return ATSColor.cyan
    }

    private var waterFraction: Double {
        guard let water else { return 0 }
        return min(max((water - 40) / 80, 0), 1)
    }

    private var oilFraction: Double {
        guard let oil else { return 0 }
        return min(max(oil / 100, 0), 1)
    }

    private func numericText(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(Int(value.rounded()))
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            MiniGaugeView(
                label: "AGUA",
                valueText: numericText(water),
                unit: "°C",
                fraction: waterFraction,
                accent: waterAccent
            )
            .frame(width: 200, height: 200)

            Spacer(minLength: 0)

            MiniGaugeView(
                label: "",
                valueText: numericText(oil),
                unit: "PSI",
                fraction: oilFraction,
                accent: oilAccent
            )
            .frame(width: 200, height: 200)

            Spacer(minLength: 0)

            FinancialPanelView(snap: snap)
                .frame(width: 200, height: 200)

            Spacer(minLength: 0)

            CompactFuelPanelView(snap: snap)
                .frame(width: 200, height: 200)

            Spacer(minLength: 0)

            WeatherPanelView(snap: snap)
                .frame(width: 200, height: 200)

            Spacer(minLength: 0)
        }
        .frame(width: 1224, height: 200)
    }
}

struct MiniGaugeView: View {
    let label: String
    let valueText: String
    let unit: String
    let fraction: Double
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            ZStack {
                Canvas { context, size in
                    draw(&context, size: size, side: side)
                }

                VStack(spacing: side * 0.012) {
                    Text(valueText)
                        .font(.system(size: FS(side * 0.205), weight: .bold, design: .default))
                        .monospacedDigit()
                        .foregroundColor(accent)
                        .shadow(color: accent.opacity(0.28), radius: side * 0.025)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(unit)
                        .font(.system(size: FS(side * 0.060), weight: .semibold, design: .default))
                        .tracking(side * 0.008)
                        .foregroundColor(.white.opacity(0.46))

                    if !label.isEmpty {
                        Text(label)
                            .font(.system(size: FS(side * 0.050), weight: .bold, design: .default))
                            .tracking(side * 0.009)
                            .foregroundColor(.white.opacity(0.36))
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, side: CGFloat) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = side * 0.405
        let lineWidth = side * 0.034
        let startAngle = -90.0
        let endAngle = startAngle + 360.0 * min(max(fraction, 0), 1)
        let ringRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.fill(Path(ellipseIn: ringRect.insetBy(dx: -lineWidth, dy: -lineWidth)), with: .color(.white.opacity(0.018)))

        context.stroke(
            Path(ellipseIn: ringRect),
            with: .color(.white.opacity(0.075)),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )

        if fraction > 0.002 {
            context.stroke(
                arcPath(center: center, radius: radius, start: startAngle, end: endAngle),
                with: .color(accent),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }

        for i in 0..<8 {
            let angle = startAngle + Double(i) * 45.0
            let outer = radius + lineWidth * 0.72
            let inner = outer - side * 0.022
            var tick = Path()
            tick.move(to: point(center, outer, angle))
            tick.addLine(to: point(center, inner, angle))

            context.stroke(
                tick,
                with: .color(.white.opacity(i % 2 == 0 ? 0.24 : 0.10)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
            )
        }
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: center.x + CGFloat(cos(radians)) * radius,
            y: center.y + CGFloat(sin(radians)) * radius
        )
    }

    private func arcPath(center: CGPoint, radius: CGFloat, start: Double, end: Double) -> Path {
        var path = Path()
        let steps = max(2, Int(abs(end - start) * 1.5))

        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let angle = start + (end - start) * t
            let p = point(center, radius, angle)
            if i == 0 {
                path.move(to: p)
            } else {
                path.addLine(to: p)
            }
        }

        return path
    }
}

// MARK: - Compact fuel panel
struct CompactFuelPanelView: View {
    let snap: Snap
    @State private var ignitionStart: Date? = nil
    @State private var prevEngine: Bool = false
    @State private var smoothedFraction: Double = 0
    @State private var animatedFuel = AnimatedValue()
    @State private var lastFrame: Date = Date()

    private func smoothStep(_ t: Double) -> Double { let c=min(1,max(0,t)); return c*c*(3-2*c) }

    private var animatedFraction: Double {
        guard snap.active, snap.engine, let start = ignitionStart else { return fraction }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed >= 2.1 { return fraction }
        if elapsed < 0.9 { return smoothStep(elapsed/0.9) }
        if elapsed < 1.05 { return 1.0 }
        return 1.0 + (fraction - 1.0) * smoothStep((elapsed-1.05)/1.05)
    }

    private let litersToGallons = 0.2641720524

    private var fuel: Double? {
        guard snap.active, let value = snap.fuel else { return nil }
        return Double(value)
    }

    private var capacity: Double? {
        guard snap.active, let value = snap.fuelCap, value > 0 else { return nil }
        return Double(value)
    }

    private var realFraction: Double {
        guard let fuel, let capacity, capacity > 0 else { return 0 }
        return min(max(fuel / capacity, 0), 1)
    }
    private var fraction: Double { smoothedFraction }

    private var range: Double? {
        guard snap.active, let value = snap.range else { return nil }
        return Double(value)
    }

    private var lowFuel: Bool {
        snap.fuelWarn || (snap.active && fraction < 0.12)
    }

    private var color: Color {
        guard snap.active, fuel != nil, capacity != nil else {
            return Color.white.opacity(0.25)
        }
        if lowFuel { return ATSColor.red }
        if fraction < 0.30 { return ATSColor.orange }
        return ATSColor.green
    }

    private var percentText: String {
        guard fuel != nil, capacity != nil else { return "--" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    private var gallonsText: String {
        guard let fuel else { return "-- gal" }
        return "\(Int((fuel * litersToGallons).rounded())) gal"
    }

    private var capacityText: String {
        guard let capacity else { return "" }
        return "de \(Int((capacity * litersToGallons).rounded())) gal"
    }

    private var rangeText: String {
        guard let range else { return "-- km" }
        return "\(Int(range.rounded())) km"
    }

    private var fuelUnit: Int {
        UserDefaults.standard.integer(forKey: "ATS.fuelUnit")
    }

    private var consText: String {
        guard snap.active, let cons = snap.cons, cons > 0, snap.speed ?? 0 > 0.5 else { return "--" }
        let l100 = cons * 100.0
        switch fuelUnit {
        case 1:
            let mpg = 235.214583 / l100
            return String(format: "%.1f MPG", mpg)
        case 2:
            let gal = l100 * 0.264172
            return String(format: "%.1f gal/100mi", gal)
        default:
            return String(format: "%.1f L/100", l100)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: FS(13), weight: .semibold))
                    .foregroundColor(color)

                Text(L10n.t("panel.fuel"))
                    .font(.system(size: FS(9.5), weight: .bold, design: .default))
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(alignment: .center, spacing: 17) {
                FuelBarView(fraction: animatedFraction, color: color)
                    .frame(width: 24, height: 114)

                VStack(alignment: .center, spacing: 4) {
                    Text(percentText)
                        .font(.system(size: FS(27), weight: .bold, design: .default))
                        .monospacedDigit()
                        .foregroundColor(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(gallonsText)
                        .font(.system(size: FS(14), weight: .semibold, design: .default))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(capacityText)
                        .font(.system(size: FS(8.5), weight: .medium, design: .default))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.32))

                    Spacer(minLength: 6)

                    Text(L10n.t("fuel.autonomy"))
                        .font(.system(size: FS(6.8), weight: .bold, design: .default))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.38))

                    Text(rangeText)
                        .font(.system(size: FS(13), weight: .semibold, design: .default))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.90))
                        .lineLimit(1)

                    Text("CONS. \(consText)")
                        .font(.system(size: FS(9), weight: .semibold, design: .default))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)

                    if lowFuel && snap.active {
                        Text(L10n.t("fuel.reserve"))
                            .font(.system(size: FS(6), weight: .bold, design: .default))
                            .tracking(1.2)
                            .foregroundColor(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(ATSColor.red))
                            .padding(.top, 1)
                    }
                }
                .frame(height: 114, alignment: .top)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.022))
        )
        .onChange(of: snap.engine) { _, newValue in
            if newValue && !prevEngine { ignitionStart = Date() }
            prevEngine = newValue
            if !newValue { ignitionStart = nil }
        }
        .onAppear {
            if snap.active && snap.engine { ignitionStart = Date() }
            prevEngine = snap.engine
            smoothedFraction = realFraction
            animatedFuel.snap(realFraction)
            lastFrame = Date()
        }
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { _ in
            let now = Date()
            let dt = min(0.05, max(0, now.timeIntervalSince(lastFrame)))
            lastFrame = now
            let target = snap.active ? realFraction : 0
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || UserDefaults.standard.bool(forKey: "ATS.reduceMotion") {
                animatedFuel.snap(target)
            } else {
                animatedFuel.update(target: target, dt: dt)
            }
            smoothedFraction = animatedFuel.current
        }
    }
}

// MARK: - Financial panel
struct FinancialPanelView: View {
    let snap: Snap

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "es_ES")
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    private var income: Int64? {
        guard snap.active else { return nil }

        if snap.onJob, let jobIncome = snap.jobIncome {
            return Int64(jobIncome)
        }
        if let delivered = snap.jobDeliveredRevenue, delivered > 0 {
            return delivered
        }
        if let jobIncome = snap.jobIncome {
            return Int64(jobIncome)
        }
        return 0
    }

    private var expenses: Int64? {
        guard snap.active else { return nil }

        let values = [
            snap.fineAmount,
            snap.tollgatePay,
            snap.ferryPay,
            snap.trainPay,
            snap.jobCancelledPenalty
        ].compactMap { $0 }

        return values.reduce(Int64(0)) { $0 + max(0, $1) }
    }

    private func money(_ value: Int64?) -> String {
        guard let value else { return "--" }

        let magnitude = abs(value)
        let formatted = Self.formatter.string(from: NSNumber(value: magnitude)) ?? "\(magnitude)"
        return value < 0 ? "-$\(formatted)" : "$\(formatted)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: FS(13), weight: .semibold))
                    .foregroundColor(ATSColor.cyan)

                Text(L10n.t("panel.finance"))
                    .font(.system(size: FS(9.5), weight: .bold, design: .default))
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.62))

                Spacer()

                if let logoName = snap.companyLogo,
                   let logo = companyLogoImage(named: logoName) {
                    Image(nsImage: logo)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 62, height: 62)
                }
            }

            Text(snap.companyName ?? L10n.t("no.company"))
                .font(.system(size: FS(13), weight: .bold, design: .default))
                .foregroundColor(.white)
                .lineLimit(1)

            Divider().overlay(Color.white.opacity(0.07))

            // 3 filas primarias (FH6)
            FinanceRow(label: "TRABAJO ACTUAL",
                       value: snap.onJob ? (snap.cargoName ?? "--") : L10n.t("no.job"),
                       color: ATSColor.cyan, large: false)
            FinanceRow(label: "GANANCIA NETA",
                       value: money(income.map { $0 - (expenses ?? 0) }),
                       color: ATSColor.cyan, large: false)
            FinanceRow(label: "SALDO DEL BANCO",
                       value: money(snap.bankBalance),
                       color: ATSColor.cyan, large: true)

            // Detalle secundario
            if let drivers = snap.hiredDrivers {
                FinanceRow(label: "CONDUCTORES", value: "\(drivers)", color: ATSColor.cyan, large: false)
            }
            FinanceRow(label: "EGRESOS RUTA", value: money(expenses), color: ATSColor.red, large: false)

            // Margen operativo con barra (FH6)
            if let inc = income, inc > 0 {
                let net = Double(inc - (expenses ?? 0))
                let frac = min(1, max(0, net / Double(inc)))
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(L10n.t("finance.margin"))
                            .font(.system(size: FS(9), weight: .bold, design: .default))
                            .tracking(1.2)
                            .foregroundColor(.white.opacity(0.30))
                        Spacer()
                        Text("\(Int((frac * 100).rounded()))%")
                            .font(.system(size: FS(9), weight: .semibold, design: .monospaced))
                            .foregroundColor(ATSColor.green.opacity(0.8))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ATSColor.green)
                                .frame(width: geo.size.width * frac)
                        }
                    }
                    .frame(height: 6)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.022))
        )
    }
}

private struct FinanceRow: View {
    let label: String
    let value: String
    let color: Color
    let large: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(label)
                .font(.system(size: FS(7.2), weight: .bold, design: .default))
                .tracking(1.15)
                .foregroundColor(.white.opacity(0.38))
                .lineLimit(1)

            Spacer(minLength: 2)

            Text(value)
                .font(.system(size: FS(large ? 24 : 20), weight: .bold, design: .default))
                .monospacedDigit()
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
    }
}

// MARK: - Weather panel
struct WeatherPanelView: View {
    let snap: Snap

    private var minutes: Int? {
        guard snap.active, let time = snap.gameTime else { return nil }
        return Int(time)
    }

    private var timeText: String {
        guard let minutes else { return "--:--" }
        return String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    private var isDay: Bool {
        guard let minutes else { return true }
        let hour = (minutes / 60) % 24
        return hour >= 6 && hour < 20
    }

    private var condition: WeatherCondition {
        snap.active ? snap.weather : .clear
    }

    private var conditionText: String {
        guard snap.active else { return L10n.t("no.signal") }
        switch condition {
        case .clear: return "DESPEJADO"
        case .cloudy: return "NUBLADO"
        case .rain: return "LLUVIA"
        case .storm: return "TORMENTA"
        }
    }

    private var accent: Color {
        guard snap.active else { return Color.white.opacity(0.25) }
        switch condition {
        case .clear: return isDay ? ATSColor.yellow : Color(red: 0.80, green: 0.88, blue: 1.00)
        case .cloudy: return Color.white.opacity(0.62)
        case .rain: return ATSColor.cyan
        case .storm: return ATSColor.yellow
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: isDay ? "cloud.sun.fill" : "cloud.moon.fill")
                    .font(.system(size: FS(13), weight: .semibold))
                    .foregroundColor(accent)

                Text(L10n.t("panel.weather"))
                    .font(.system(size: FS(9.5), weight: .bold, design: .default))
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.62))

                Spacer()

                Text(snap.active ? (isDay ? "DÍA" : "NOCHE") : "—")
                    .font(.system(size: FS(7.5), weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.32))
            }

            WeatherGlyph(condition: condition, isDay: isDay)
                .frame(width: 84, height: 72)
                .frame(maxWidth: .infinity)
                .opacity(snap.active ? 1 : 0.28)

            VStack(spacing: 1) {
                Text(timeText)
                    .font(.system(size: FS(28), weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)

                Text(L10n.t("weather.gametime"))
                    .font(.system(size: FS(6.5), weight: .bold, design: .default))
                    .tracking(1.1)
                    .foregroundColor(.white.opacity(0.28))
            }
            .frame(maxWidth: .infinity)

            Text(conditionText)
                .font(.system(size: FS(9), weight: .bold, design: .default))
                .tracking(1.5)
                .foregroundColor(accent)
                .frame(maxWidth: .infinity)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.022))
        )
    }
}

private struct WeatherGlyph: View {
    let condition: WeatherCondition
    let isDay: Bool

    private var cloudSymbol: String {
        switch condition {
        case .clear: return "cloud.fill"
        case .cloudy: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .storm: return "cloud.bolt.rain.fill"
        }
    }

    private var cloudStyle: Color {
        switch condition {
        case .clear, .cloudy: return Color.white.opacity(0.58)
        case .rain: return Color(red: 0.48, green: 0.68, blue: 0.86)
        case .storm: return Color(red: 0.56, green: 0.62, blue: 0.72)
        }
    }

    @ViewBuilder
    private func sunMoon(size: CGFloat) -> some View {
        if isDay {
            Image(systemName: "sun.max.fill")
                .font(.system(size: FS(size), weight: .medium))
                .foregroundColor(ATSColor.yellow)
                .shadow(color: ATSColor.yellow.opacity(0.25), radius: size * 0.18)
        } else {
            FullMoonView(size: size)
        }
    }

    var body: some View {
        ZStack {
            if condition == .clear {
                sunMoon(size: 54)
            } else {
                sunMoon(size: 30)
                    .offset(x: 17, y: -17)

                if condition == .storm {
                    Image(systemName: cloudSymbol)
                        .font(.system(size: FS(48), weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(cloudStyle, ATSColor.yellow, ATSColor.cyan)
                        .offset(x: -8, y: 10)
                } else {
                    Image(systemName: cloudSymbol)
                        .font(.system(size: FS(48), weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(cloudStyle)
                        .offset(x: -8, y: 10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FullMoonView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.98, green: 0.99, blue: 1.00),
                            Color(red: 0.80, green: 0.86, blue: 0.98)
                        ],
                        center: .topLeading,
                        startRadius: size * 0.04,
                        endRadius: size * 0.72
                    )
                )

            Circle()
                .fill(Color(red: 0.35, green: 0.40, blue: 0.52).opacity(0.18))
                .frame(width: size * 0.24, height: size * 0.24)
                .offset(x: -size * 0.16, y: -size * 0.10)

            Circle()
                .fill(Color(red: 0.35, green: 0.40, blue: 0.52).opacity(0.14))
                .frame(width: size * 0.15, height: size * 0.15)
                .offset(x: size * 0.18, y: size * 0.04)

            Circle()
                .fill(Color(red: 0.35, green: 0.40, blue: 0.52).opacity(0.12))
                .frame(width: size * 0.11, height: size * 0.11)
                .offset(x: -size * 0.02, y: size * 0.25)

            Circle()
                .fill(Color(red: 0.35, green: 0.40, blue: 0.52).opacity(0.10))
                .frame(width: size * 0.08, height: size * 0.08)
                .offset(x: size * 0.08, y: -size * 0.24)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.20), lineWidth: 0.6)
        )
        .shadow(
            color: Color(red: 0.75, green: 0.85, blue: 1.00).opacity(0.28),
            radius: size * 0.16
        )
    }
}

// MARK: - Cargo panel
struct CargoPanelView: View {
    let snap: Snap

    private static let massFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }()

    private var cargoName: String? {
        guard snap.active, snap.cargoLoaded,
              let name = snap.cargoName, !name.isEmpty else { return nil }
        return name
    }

    private var cargoId: String? {
        guard snap.active, snap.cargoLoaded,
              let id = snap.cargoId, !id.isEmpty else { return nil }
        return id
    }

    private var mass: Double? {
        guard snap.active, snap.cargoLoaded,
              let value = snap.cargoMass, value > 0 else { return nil }
        return Double(value)
    }

    private var damage: Double? {
        guard snap.active, snap.cargoLoaded,
              let value = snap.cargoDmg else { return nil }
        return Double(value)
    }

    private var loaded: Bool {
        snap.active && snap.cargoLoaded
    }

    private var massText: String {
        guard let mass else { return "-- kg" }
        let kg = Int(mass.rounded())
        return "\(Self.massFormatter.string(from: NSNumber(value: kg)) ?? "\(kg)") kg"
    }

    private var tonsText: String {
        guard let mass else { return "" }
        let tons = mass / 1_000
        return String(format: "%.1f t", tons).replacingOccurrences(of: ".", with: ",")
    }

    private var integrityText: String {
        guard let damage else { return "--" }
        return "\(Int((100 - damage).rounded()))%"
    }

    private var integrityFraction: Double {
        guard let damage else { return 0 }
        return min(max(1 - damage / 100, 0), 1)
    }

    private var accent: Color {
        guard snap.active else { return Color.white.opacity(0.25) }
        guard loaded else { return Color.white.opacity(0.25) }
        guard let damage else { return ATSColor.cyan }
        if damage >= 50 { return ATSColor.red }
        if damage >= 20 { return ATSColor.orange }
        if damage >= 5 { return ATSColor.yellow }
        return ATSColor.green
    }

    private var damageColor: Color {
        guard let damage else { return Color.white.opacity(0.30) }
        if damage >= 50 { return ATSColor.red }
        if damage >= 20 { return ATSColor.orange }
        if damage >= 5 { return ATSColor.yellow }
        return ATSColor.green
    }

    private var statusText: String {
        guard snap.active else { return L10n.t("no.signal") }
        return loaded ? "CARGADA" : "VACÍA"
    }

    private var typeText: String {
        guard let cargoId else { return "TIPO · --" }
        return "TIPO · \(cargoId)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: FS(19), weight: .semibold))
                    .foregroundColor(accent)

                Text(L10n.t("panel.cargo"))
                    .font(.system(size: FS(15), weight: .bold, design: .default))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.62))

                Spacer()

                Text(statusText)
                    .font(.system(size: FS(10), weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(accent.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(cargoName ?? L10n.t("no.cargo"))
                    .font(.system(size: FS(26), weight: .bold, design: .default))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                // TIPO removido (v3.2.0): sin TIPO ni REMOLQUE ni linea divisoria
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(L10n.t("cargo.weight"))
                    .font(.system(size: FS(10), weight: .bold, design: .default))
                    .tracking(2.5)
                    .foregroundColor(.white.opacity(0.38))

                Spacer()

                Text(massText)
                    .font(.system(size: FS(22), weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if !tonsText.isEmpty {
                    Text(tonsText)
                        .font(.system(size: FS(11), weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.38))
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(L10n.t("cargo.integrity"))
                        .font(.system(size: FS(9), weight: .bold, design: .default))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.34))

                    Spacer()

                    Text(integrityText)
                        .font(.system(size: FS(13), weight: .bold, design: .monospaced))
                        .foregroundColor(damageColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))

                        Capsule()
                            .fill(damageColor)
                            .frame(width: max(0, geo.size.width * integrityFraction))
                    }
                }
                .frame(height: 6)
            }

            if snap.active, snap.onJob, let src = snap.citySrc, let dst = snap.cityDst {
                HStack(spacing: 4) {
                    Text(src.uppercased())
                        .font(.system(size: FS(9), weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.5))
                    Image(systemName: "arrow.right")
                        .font(.system(size: FS(8), weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                    Text(dst.uppercased())
                        .font(.system(size: FS(9), weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    if let rd = snap.routeD, rd > 0 {
                        Text("\(Int((Double(rd)/1000.0).rounded())) km")
                            .font(.system(size: FS(9), weight: .semibold, design: .monospaced))
                            .foregroundColor(ATSColor.cyan.opacity(0.7))
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Text(snap.specialJob ? "TRABAJO ESPECIAL" : "TRABAJO ESTÁNDAR")
                    .font(.system(size: FS(9), weight: .bold, design: .default))
                    .tracking(1.8)
                    .foregroundColor(snap.specialJob ? ATSColor.yellow.opacity(0.85) : Color.white.opacity(0.30))

                Spacer()

                Text(loaded ? L10n.t("cargo.ontrailer") : L10n.t("cargo.notrailer"))
                    .font(.system(size: FS(9), weight: .semibold, design: .default))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.30))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.022))
        )
    }
}


// MARK: - Speed limit sign (FH6)
struct SpeedLimitSignView: View {
    let limitKmh: Double?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
            Circle()
                .stroke(ATSColor.red, lineWidth: 6)
            if let v = limitKmh {
                Text("\(Int(v.rounded()))")
                    .font(.system(size: FS(22), weight: .bold, design: .default))
                    .foregroundColor(.black)
            } else {
                Text("--")
                    .font(.system(size: FS(22), weight: .bold, design: .default))
                    .foregroundColor(.black.opacity(0.4))
            }
        }
        .frame(width: 88, height: 88)
    }
}

// MARK: - GPS panel
struct GPSPanelView: View {
    let snap: Snap

    private var heading: Double? {
        guard snap.active, let value = snap.heading else { return nil }
        let normalized = value.truncatingRemainder(dividingBy: 1.0)
        return normalized < 0 ? normalized + 1 : normalized
    }

    private var bearing: Double? {
        guard let heading else { return nil }
        return ((1.0 - heading) * 360.0).truncatingRemainder(dividingBy: 360.0)
    }

    private var cardinal: String {
        guard let bearing else { return "--" }
        let names = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
        let index = Int((bearing + 22.5) / 45.0) % names.count
        return names[index]
    }

    private var bearingText: String {
        guard let bearing else { return "--" }
        return String(format: "%03.0f°", bearing)
    }

    private var destination: String {
        guard snap.active, snap.onJob, let city = snap.cityDst, !city.isEmpty else {
            return L10n.t("no.destination")
        }
        return city
    }

    private var origin: String {
        guard snap.active, let city = snap.citySrc, !city.isEmpty else {
            return L10n.t("no.origin")
        }
        return city
    }

    private var routeText: String {
        guard snap.active, snap.onJob, let distance = snap.routeD, distance > 0 else {
            return "--"
        }

        let km = Int((Double(distance) / 1_000.0).rounded())

        // routeTime comes in seconds, but some jobs report a stale/absurd value.
        guard let time = snap.routeT, time > 0, time < 172_800 else {
            return "\(km) km"
        }

        let minutes = max(0, Int((Double(time) / 60.0).rounded()))
        let hours = minutes / 60
        let rest = minutes % 60
        return hours > 0 ? "\(km) km · \(hours)h \(rest)m" : "\(km) km · \(rest) min"
    }

    private var coordsText: String {
        guard snap.active, let x = snap.posX, let z = snap.posZ else {
            return "X --   Z --"
        }
        return String(format: "X %.0f   Z %.0f", x, z)
    }

    private var travelledText: String {
        guard snap.active, snap.onJob, let planned = snap.planned, planned > 0, let routeD = snap.routeD else { return "--" }
        let remaining = max(0, Int((Double(routeD) / 1000.0).rounded()))
        let travelled = max(0, Int(planned) - remaining)
        return "\(travelled) km"
    }
    private var odometerText: String {
        guard snap.active, let o = snap.odometer, o >= 0 else { return "--" }
        return String(Int(o.rounded()))
    }
    private var arrivalText: String {
        guard snap.active, snap.onJob, let t = snap.routeT, t > 0, t < 172_800,
              let gt = snap.gameTime else { return "--" }
        let totalMin = Int(gt) + Int(t / 60)
        let h = (totalMin / 60) % 24
        let m = totalMin % 60
        return String(format: "%02d:%02d", h, m)
    }

    private var accent: Color {
        snap.active ? ATSColor.cyan : Color.white.opacity(0.25)
    }

    private var statusText: String {
        guard snap.active else { return L10n.t("no.signal") }
        return snap.onJob ? L10n.t("gps.onroute") : L10n.t("gps.noroute")
    }

    private var statusColor: Color {
        guard snap.active else { return Color.white.opacity(0.25) }
        return snap.onJob ? ATSColor.green.opacity(0.80) : Color.white.opacity(0.25)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: FS(8), weight: .bold, design: .default))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.30))
            Spacer()
            Text(value)
                .font(.system(size: FS(10), weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.60))
                .lineLimit(1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: FS(19), weight: .semibold))
                    .foregroundColor(accent)

                Text(L10n.t("panel.gps"))
                    .font(.system(size: FS(15), weight: .bold, design: .default))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.62))

                Spacer()

                Text(statusText)
                    .font(.system(size: FS(10), weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(statusColor)
            }

            HStack(alignment: .center, spacing: 16) {
                CompassView(bearing: bearing, accent: accent)
                    .frame(width: 108, height: 108)

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("gps.bearing"))
                        .font(.system(size: FS(10), weight: .bold, design: .default))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.35))

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(cardinal)
                            .font(.system(size: FS(34), weight: .bold, design: .default))
                            .foregroundColor(accent)

                        Text(bearingText)
                            .font(.system(size: FS(16), weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Text(L10n.t("gps.destination"))
                        .font(.system(size: FS(10), weight: .bold, design: .default))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, 3)

                    Text(destination)
                        .font(.system(size: FS(20), weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.90))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                Spacer(minLength: 0)

                SpeedLimitSignView(limitKmh: snap.active && (snap.limit ?? 0) > 0.5 ? (Double(snap.limit!) * 3.6) : nil)
                    .frame(width: 88, height: 88)
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("gps.origin"))
                        .font(.system(size: FS(9), weight: .bold, design: .default))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.30))

                    Text(origin)
                        .font(.system(size: FS(13), weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("RUTA RESTANTE")
                        .font(.system(size: FS(9), weight: .bold, design: .default))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.30))

                    Text(routeText)
                        .font(.system(size: FS(13), weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.70))
                        .lineLimit(1)
                }
            }

            // Progreso de ruta
            if snap.active, snap.onJob, let planned = snap.planned, planned > 0, let routeD = snap.routeD {
                let remaining = max(0, Int((Double(routeD) / 1000.0).rounded()))
                let travelled = max(0, Int(planned) - remaining)
                let frac = min(1, max(0, Double(travelled) / Double(planned)))
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("PROGRESO DE RUTA")
                            .font(.system(size: FS(9), weight: .bold, design: .default))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.30))
                        Spacer()
                        Text("\\(Int((frac * 100).rounded()))%")
                            .font(.system(size: FS(9), weight: .semibold, design: .monospaced))
                            .foregroundColor(ATSColor.cyan.opacity(0.8))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ATSColor.cyan)
                                .frame(width: geo.size.width * frac)
                        }
                    }
                    .frame(height: 6)
                }
            }

            // Detalle secundario (FH6)
            VStack(alignment: .leading, spacing: 2) {
                detailRow("FALTAN", snap.active && snap.onJob ? routeText.split(separator: "·").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? "--" : "--")
                detailRow("RECORRIDO", travelledText)
                detailRow("POSICIÓN", coordsText)
            }

            Text(coordsText)
                .font(.system(size: FS(10), weight: .medium, design: .monospaced))
                .tracking(1)
                .foregroundColor(.white.opacity(0.28))
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.022))
        )
    }
}

struct CompassView: View {
    let bearing: Double?
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = side * 0.46
            let ring = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            context.fill(Path(ellipseIn: ring), with: .color(.white.opacity(0.025)))
            context.stroke(
                Path(ellipseIn: ring),
                with: .color(.white.opacity(0.10)),
                style: StrokeStyle(lineWidth: 1)
            )

            for i in 0..<36 {
                let angle = Double(i) * 10.0
                let major = i % 9 == 0
                let outer = radius * 0.92
                let inner = radius * (major ? 0.78 : 0.84)

                var tick = Path()
                tick.move(to: point(center, outer, angle))
                tick.addLine(to: point(center, inner, angle))

                context.stroke(
                    tick,
                    with: .color(.white.opacity(major ? 0.52 : 0.16)),
                    style: StrokeStyle(lineWidth: major ? 1.6 : 1.0, lineCap: .round)
                )
            }

            let labels = [(0.0, "N"), (90.0, "E"), (180.0, "S"), (270.0, "O")]
            for (angle, label) in labels {
                context.draw(
                    Text(label)
                        .font(.system(size: FS(side * 0.12), weight: .bold, design: .default))
                        .foregroundColor(.white.opacity(0.50)),
                    at: point(center, radius * 0.62, angle),
                    anchor: .center
                )
            }

            let needleAngle = bearing ?? 0
            let needleColor = bearing == nil ? accent.opacity(0.30) : accent
            let tip = point(center, radius * 0.50, needleAngle)
            let left = point(center, radius * 0.10, needleAngle - 90)
            let right = point(center, radius * 0.10, needleAngle + 90)

            var needle = Path()
            needle.move(to: tip)
            needle.addLine(to: left)
            needle.addLine(to: right)
            needle.closeSubpath()
            context.fill(needle, with: .color(needleColor))

            let hub = CGRect(
                x: center.x - side * 0.035,
                y: center.y - side * 0.035,
                width: side * 0.070,
                height: side * 0.070
            )
            context.fill(Path(ellipseIn: hub), with: .color(.black))
            context.stroke(
                Path(ellipseIn: hub),
                with: .color(needleColor.opacity(0.85)),
                style: StrokeStyle(lineWidth: 1.5)
            )
        }
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: center.x + CGFloat(sin(radians)) * radius,
            y: center.y - CGFloat(cos(radians)) * radius
        )
    }
}

struct FuelBarView: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let fillHeight = max(0, height * min(max(fraction, 0), 1))

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.045))

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ATSColor.red,
                                ATSColor.orange,
                                ATSColor.yellow,
                                ATSColor.green
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: fillHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: color.opacity(0.35), radius: 16)

                Canvas { context, size in
                    for q in [0.25, 0.50, 0.75] {
                        let y = size.height * (1 - q)
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(
                            path,
                            with: .color(.white.opacity(0.18)),
                            style: StrokeStyle(lineWidth: 1)
                        )
                    }
                    // Marcador de reserva (12 %)
                    let ry = size.height * (1 - 0.12)
                    var rpath = Path()
                    rpath.move(to: CGPoint(x: 0, y: ry))
                    rpath.addLine(to: CGPoint(x: size.width, y: ry))
                    context.stroke(
                        rpath,
                        with: .color(ATSColor.red.opacity(0.8)),
                        style: StrokeStyle(lineWidth: 2)
                    )
                }

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }
        }
    }
}
