import AppKit
import Foundation
import SwiftUI

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

// MARK: - Root view
struct DashboardView: View {
    let reader: TelemetryReader

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 1920.0, geo.size.height / 1080.0)

            ZStack {
                Color.black

                ZStack {
                    TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { _ in
                        DashboardContent(snap: reader.snapshot())
                    }
                }
                .frame(width: 1920, height: 1080)
                .scaleEffect(scale)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}

struct DashboardContent: View {
    let snap: Snap

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(snap: snap)

            HStack(alignment: .top, spacing: 34) {
                VStack(spacing: 0) {
                    IndicatorRowView(snap: snap)
                        .frame(width: 1224, height: 46)

                    Color.clear
                        .frame(height: 10)

                    ZStack(alignment: .top) {
                        HStack(alignment: .top, spacing: 24) {
                            SpeedometerView(snap: snap)
                                .frame(width: 600, height: 600)

                            TachometerView(snap: snap)
                                .frame(width: 600, height: 600)
                        }

                        TripBadgeView(snap: snap)
                            .offset(y: 8)
                    }
                    .frame(width: 1224, height: 600)

                    Color.clear
                        .frame(height: 18)

                    MiniGaugeRow(snap: snap)
                        .frame(width: 1224, height: 200)
                }
                .frame(width: 1224)

                VStack(spacing: 17) {
                    DamagePanelView(snap: snap)
                        .frame(width: 400, height: 280)

                    CargoPanelView(snap: snap)
                        .frame(width: 400, height: 280)

                    GPSPanelView(snap: snap)
                        .frame(width: 400, height: 280)
                }
                .frame(width: 400)
            }
            .frame(width: 1658)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            FooterView(snap: snap)
        }
        .padding(.horizontal, 70)
        .padding(.vertical, 40)
        .frame(width: 1920, height: 1080)
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
        guard snap.active else { return "SIN CAMIÓN" }

        let brand = snap.truckBrand?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = snap.truckName?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let brand, let name else {
            return (name ?? brand ?? "SIN CAMIÓN").uppercased()
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

                    Text("ATS")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .tracking(8)
                        .foregroundColor(.white)

                    Text("TELEMETRÍA")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.30))
                }

                Spacer()

                HStack(spacing: 18) {
                    Text(status.text)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.62))

                    Text("PM1562")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.24))
                }
            }

            VStack(spacing: 1) {
                Text(truckRef)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .tracking(2.4)
                    .foregroundColor(.white.opacity(0.82))
                    .lineLimit(1)

                if let displacement {
                    Text(displacement)
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.40))
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
            Text("SCS TELEMETRY  ·  LECTURA DIRECTA /SCSTelemetry")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .tracking(1)
                .foregroundColor(.white.opacity(0.22))

            Spacer()

            Text(snap.demo ? "DATOS DE PRUEBA" : (snap.active ? "DATOS EN VIVO" : "SIN SEÑAL"))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundColor(
                    snap.demo
                        ? ATSColor.cyan.opacity(0.75)
                        : (snap.active ? ATSColor.green.opacity(0.75) : ATSColor.orange.opacity(0.65))
                )
        }
        .frame(height: 30)
    }
}

// MARK: - Indicator lights
private enum IndicatorIcon {
    private static var cache: [String: NSImage] = [:]

    static func image(named name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        cache[name] = image
        return image
    }
}

struct IndicatorRowView: View {
    let snap: Snap

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
        HStack(spacing: 22) {
            indicator("beacon-c", "light.max", snap.beacon, ATSColor.yellow, pulses: true)
            indicator("side-markers-c", "parkingsign", snap.parking, ATSColor.green)
            indicator("low-beam-c", "lightbulb.fill", snap.lowB, ATSColor.green)
            indicator("high-beam-c", "sun.max.fill", snap.highB, ATSColor.blue)
            indicator("brake-c1", "octagon.fill", snap.brake, ATSColor.red)

            // Centro de la fila: direccionales izquierda y derecha.
            indicator("turn-lights-left-c", "arrow.left", snap.blinkL, ATSColor.green)
            indicator("turn-lights-right-c", "arrow.right", snap.blinkR, ATSColor.green)

            indicator("parking-brake-2-c", "hand.raised.fill", snap.park, ATSColor.red, pulses: true)
            indicator("air-brake-warning", "exclamationmark.brakesignal", airBrakeWarning, airBrakeColor)
            indicator("exhaust-brake-c", "engine.combustion", snap.motor, ATSColor.orange)
            indicator("wiper-c", "drop.fill", snap.wipers > 0, ATSColor.cyan, pulses: true)
            indicator("diff-lock-c", "gearshape.2.fill", snap.diffLock, ATSColor.orange, pulses: true)
        }
        .frame(maxWidth: .infinity)
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
                    .renderingMode(active ? .original : .template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(foreground)
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(foreground)
                    .frame(width: 40, height: 40)
            }
        }
        .shadow(color: active ? activeColor.opacity(0.35) : .clear, radius: 6)
        .modifier(IndicatorPulse(active: active && pulses))
        .frame(height: 46)
    }
}

private struct IndicatorPulse: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { context in
            let phase = active
                ? (sin(context.date.timeIntervalSinceReferenceDate * 2 * Double.pi / 1.05) + 1) / 2
                : 1.0

            content
                .opacity(active ? 0.60 + 0.40 * phase : 1.0)
                .scaleEffect(active ? CGFloat(1.0 + 0.05 * phase) : 1.0)
        }
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
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(ATSColor.green)
                        .lineLimit(1)

                    Text("/ \(km(trip.planned)) km")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.34))
                        .lineLimit(1)
                }

                Text(
                    trip.eta.map { "FALTAN \(km(trip.remaining)) km · \($0)" }
                        ?? "FALTAN \(km(trip.remaining)) km"
                )
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.80)
            } else {
                Text("SIN VIAJE")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.34))

                Text(snap.active ? "SIN RUTA ACTIVA" : "SIN SEÑAL")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
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
        guard let maxDamage else { return "SIN DATOS" }
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

                Text("DAÑOS")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(3.5)
                    .foregroundColor(.white.opacity(0.62))

                Spacer(minLength: 0)

                Text(statusText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(headerColor.opacity(0.85))
            }

            VStack(spacing: 12) {
                DamageRowView(label: "CAMIÓN", value: truck)
                DamageRowView(label: "TRÁILER", value: trailer)
                DamageRowView(label: "CARGA", value: cargo)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text("DAÑO")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.28))

                Text("5% · 20% · 50%")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.22))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.022))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
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

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.45))

                Spacer(minLength: 0)

                Text(text)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(color)
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

// MARK: - Speedometer
struct SpeedometerView: View {
    let snap: Snap

    private let maxSpeed = 160.0

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

    var body: some View {
        ZStack {
            DialGaugeView(
                value: min(speedKmh, maxSpeed),
                maxValue: maxSpeed,
                majorStep: 20,
                accent: accent,
                redlineStart: nil,
                valueText: valueText,
                unitText: "km/h",
                subtitle: subtitle,
                badgeLabel: nil,
                badgeValue: odometerText,
                badgeUnit: "km",
                badgeColor: odometerColor,
                markerValue: limitKmh,
                markerColor: ATSColor.red,
                contentOffsetY: 0.205
            )

            GaugeBadge(active: cruiseSetKmh != nil, accent: ATSColor.green) {
                if let cruiseSetKmh {
                    CruiseBadgeContent(speedKmh: cruiseSetKmh)
                }
            }
            .offset(y: -128)
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
            .offset(y: -128)
        }
    }
}

private struct CheckEngineIndicatorView: View {
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "engine.combustion.fill")
                .font(.system(size: 38, weight: .semibold))

            Text("CHECK")
                .font(.system(size: 6.5, weight: .bold, design: .rounded))
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
    let speedKmh: Double

    var body: some View {
        HStack(spacing: 7) {
            if let icon = IndicatorIcon.image(named: "cruise-control-c") {
                Image(nsImage: icon)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            } else {
                Image(systemName: "speedometer")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(ATSColor.green)
                    .frame(width: 30, height: 30)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("CRUCERO")
                    .font(.system(size: 6.5, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.48))

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(speedKmh.rounded()))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(ATSColor.green)

                    Text("km/h")
                        .font(.system(size: 7, weight: .medium, design: .rounded))
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
                        .font(.system(size: side * 0.145, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(accent)
                        .shadow(color: accent.opacity(0.30), radius: side * 0.022)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(unitText)
                        .font(.system(size: side * 0.035, weight: .semibold, design: .rounded))
                        .tracking(side * 0.007)
                        .foregroundColor(.white.opacity(0.52))

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: side * 0.018, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.25))
                            .padding(.top, side * 0.004)
                    }

                    if let badgeValue {
                        HStack(alignment: .firstTextBaseline, spacing: side * 0.012) {
                            if let badgeLabel {
                                Text(badgeLabel)
                                    .font(.system(size: side * 0.022, weight: .bold, design: .rounded))
                                    .tracking(side * 0.003)
                                    .foregroundColor(.white.opacity(0.38))
                            }

                            Text(badgeValue)
                                .font(.system(size: side * 0.058, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(badgeColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.70)

                            if let badgeUnit {
                                Text(badgeUnit)
                                    .font(.system(size: side * 0.024, weight: .semibold, design: .rounded))
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
                        .font(.system(size: side * 0.029, weight: .semibold, design: .rounded))
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
                        .font(.system(size: side * 0.205, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(accent)
                        .shadow(color: accent.opacity(0.28), radius: side * 0.025)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(unit)
                        .font(.system(size: side * 0.060, weight: .semibold, design: .rounded))
                        .tracking(side * 0.008)
                        .foregroundColor(.white.opacity(0.46))

                    if !label.isEmpty {
                        Text(label)
                            .font(.system(size: side * 0.050, weight: .bold, design: .rounded))
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

    private let litersToGallons = 0.2641720524

    private var fuel: Double? {
        guard snap.active, let value = snap.fuel else { return nil }
        return Double(value)
    }

    private var capacity: Double? {
        guard snap.active, let value = snap.fuelCap, value > 0 else { return nil }
        return Double(value)
    }

    private var fraction: Double {
        guard let fuel, let capacity, capacity > 0 else { return 0 }
        return min(max(fuel / capacity, 0), 1)
    }

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

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)

                Text("COMBUSTIBLE")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(alignment: .center, spacing: 17) {
                FuelBarView(fraction: fraction, color: color)
                    .frame(width: 24, height: 114)

                VStack(alignment: .leading, spacing: 4) {
                    Text(percentText)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(gallonsText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(capacityText)
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.32))

                    Spacer(minLength: 6)

                    Text("AUTONOMÍA")
                        .font(.system(size: 6.8, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.38))

                    Text(rangeText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.90))
                        .lineLimit(1)

                    if lowFuel && snap.active {
                        Text("RESERVA")
                            .font(.system(size: 6, weight: .bold, design: .rounded))
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
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
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
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ATSColor.cyan)

                Text("FINANZAS")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.62))
            }

            FinanceRow(
                label: "INGRESOS",
                value: money(income),
                color: ATSColor.green,
                large: false
            )

            FinanceRow(
                label: "EGRESOS",
                value: money(expenses),
                color: ATSColor.red,
                large: false
            )

            Divider()
                .overlay(Color.white.opacity(0.07))

            FinanceRow(
                label: "DINERO TOTAL",
                value: money(snap.bankBalance),
                color: ATSColor.cyan,
                large: true
            )

            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.022))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
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
                .font(.system(size: 7.2, weight: .bold, design: .rounded))
                .tracking(1.15)
                .foregroundColor(.white.opacity(0.38))
                .lineLimit(1)

            Spacer(minLength: 2)

            Text(value)
                .font(.system(size: large ? 24 : 20, weight: .bold, design: .rounded))
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
        guard snap.active else { return "SIN SEÑAL" }
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accent)

                Text("CLIMA")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundColor(.white.opacity(0.62))

                Spacer()

                Text(snap.active ? (isDay ? "DÍA" : "NOCHE") : "—")
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.32))
            }

            WeatherGlyph(condition: condition, isDay: isDay)
                .frame(width: 84, height: 72)
                .frame(maxWidth: .infinity)
                .opacity(snap.active ? 1 : 0.28)

            VStack(spacing: 1) {
                Text(timeText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)

                Text("HORA DEL JUEGO")
                    .font(.system(size: 6.5, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundColor(.white.opacity(0.28))
            }
            .frame(maxWidth: .infinity)

            Text(conditionText)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundColor(accent)
                .frame(maxWidth: .infinity)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.022))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
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
                .font(.system(size: size, weight: .medium))
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
                        .font(.system(size: 48, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(cloudStyle, ATSColor.yellow, ATSColor.cyan)
                        .offset(x: -8, y: 10)
                } else {
                    Image(systemName: cloudSymbol)
                        .font(.system(size: 48, weight: .semibold))
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
        guard snap.active else { return "SIN SEÑAL" }
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
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(accent)

                Text("CARGA")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.62))

                Spacer()

                Text(statusText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(accent.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(cargoName ?? "SIN CARGA")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(typeText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.34))
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("PESO")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2.5)
                    .foregroundColor(.white.opacity(0.38))

                Spacer()

                Text(massText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if !tonsText.isEmpty {
                    Text(tonsText)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.38))
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("INTEGRIDAD")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.34))

                    Spacer()

                    Text(integrityText)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
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

            Spacer(minLength: 0)

            HStack {
                Text(snap.specialJob ? "TRABAJO ESPECIAL" : "TRABAJO ESTÁNDAR")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundColor(snap.specialJob ? ATSColor.yellow.opacity(0.85) : Color.white.opacity(0.30))

                Spacer()

                Text(loaded ? "EN REMOLQUE" : "SIN REMOLQUE")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.30))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.022))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
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
            return "SIN DESTINO"
        }
        return city
    }

    private var origin: String {
        guard snap.active, let city = snap.citySrc, !city.isEmpty else {
            return "SIN ORIGEN"
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

    private var accent: Color {
        snap.active ? ATSColor.cyan : Color.white.opacity(0.25)
    }

    private var statusText: String {
        guard snap.active else { return "SIN SEÑAL" }
        return snap.onJob ? "EN RUTA" : "SIN RUTA"
    }

    private var statusColor: Color {
        guard snap.active else { return Color.white.opacity(0.25) }
        return snap.onJob ? ATSColor.green.opacity(0.80) : Color.white.opacity(0.25)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(accent)

                Text("GPS")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.62))

                Spacer()

                Text(statusText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(statusColor)
            }

            HStack(alignment: .center, spacing: 16) {
                CompassView(bearing: bearing, accent: accent)
                    .frame(width: 108, height: 108)

                VStack(alignment: .leading, spacing: 5) {
                    Text("RUMBO")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.35))

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(cardinal)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(accent)

                        Text(bearingText)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Text("DESTINO")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, 3)

                    Text(destination)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.90))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ORIGEN")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.30))

                    Text(origin)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("RUTA RESTANTE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.30))

                    Text(routeText)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.70))
                        .lineLimit(1)
                }
            }

            Text(coordsText)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1)
                .foregroundColor(.white.opacity(0.28))
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.022))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
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
                        .font(.system(size: side * 0.12, weight: .bold, design: .rounded))
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
                }

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }
        }
    }
}
