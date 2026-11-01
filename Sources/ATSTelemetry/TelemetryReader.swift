import Foundation
import Darwin

// MARK: - Shared memory offsets (scs-telemetry-common.hpp REV12)
// These are the same offsets used by com.hsgaming.scsmon. Read-only access.
private let O_SDK = 0
private let O_PAUSED = 4
private let O_GAME = 52
private let O_TIME_ABS = 64

private let O_SPEED = 948
private let O_RPM = 952
private let O_CRUISE = 988
private let O_FUEL = 1000
private let O_CONS = 1004
private let O_RANGE = 1008
private let O_ROUTED = 1060
private let O_ROUTET = 1064
private let O_LIMIT = 1068
private let O_PLANNED = 100

private let O_FCAP = 704
private let O_RPMMAX = 740
private let O_GEAR = 504

private let O_TRUCKBRAND = 2364
private let O_TRUCKID = 2428
private let O_TRUCKNAME = 2492
private let O_CARGOID = 2556
private let O_CARGO = 2620
private let O_CARGOMASS = 748
private let O_CARGOLOADED = 1564
private let O_SPECIALJOB = 1565

private let O_POSX = 2200
private let O_POSY = 2208
private let O_POSZ = 2216
private let O_HEADING = 2224

private let O_CITYDST = 2748
private let O_CITYSRC = 3004

private let O_PARK = 1566
private let O_MOTOR = 1567
private let O_FWARN = 1570
private let O_ENG = 1576
private let O_WIPERS = 1577
private let O_BL = 1580
private let O_BR = 1581
private let O_PARKING = 1582
private let O_LO = 1583
private let O_HI = 1584
private let O_BEACON = 1585
private let O_BRK = 1586
private let O_REV = 1587
private let O_HAZ = 1588
private let O_CRZON = 1589
private let O_DIFF = 1608

private let O_AIR = 992
private let O_OILP = 1016
private let O_OILTEMP = 1020
private let O_WATERTEMP = 1024
private let O_ODOMETER = 1056
private let O_BATT = 1028
private let O_AIRWARN = 720
private let O_AIREMERG = 724
private let O_OILWARN = 728
private let O_WATERWARN = 732
private let O_BATTWARN = 736

private let O_WENG = 1036
private let O_WTRA = 1040
private let O_WCAB = 1044
private let O_WCHA = 1048
private let O_WWHE = 1052

private let O_TCD = 6152
private let O_TCHA = 6156
private let O_TWHE = 6160
private let O_TBOD = 6164
private let O_JCD = 1468
private let O_TATT = 6080
private let O_ONJOB = 4300

// Financial values (REV12 zones 10 and 11). The game exposes the current
// job income and the last event amounts, but not the player's bank balance.
private let O_JOBINCOME = 4000
private let O_JOBCANCELLED = 4200
private let O_JOBDELIVERED = 4208
private let O_FINE = 4216
private let O_TOLL = 4224
private let O_FERRY = 4232
private let O_TRAIN = 4240

// MARK: - Weather
enum WeatherCondition: String, CaseIterable {
    case clear
    case cloudy
    case rain
    case storm
}

// MARK: - Snapshot
struct Snap {
    var active = false
    var paused = false
    var ats = false
    var demo = false

    var speed: Float?
    var rpm: Float?
    var fuel: Float?
    var fuelCap: Float?
    var range: Float?
    var cons: Float?
    var cruise: Float?
    var limit: Float?
    var rpmMax: Float?

    var truckBrand: String?
    var truckId: String?
    var truckName: String?
    var cargoId: String?
    var cargoName: String?
    var cargoMass: Float?
    var cargoLoaded = false
    var specialJob = false

    var routeD: Float?
    var routeT: Float?
    var planned: UInt32?
    var gear: Int32?
    var gameTime: UInt32?
    var weather: WeatherCondition = .clear

    var posX: Double?
    var posY: Double?
    var posZ: Double?
    var heading: Double?
    var cityDst: String?
    var citySrc: String?

    var park = false
    var motor = false
    var blinkL = false
    var blinkR = false
    var lowB = false
    var highB = false
    var brake = false
    var engine = false
    var cruiseOn = false
    var parking = false
    var hazard = false
    var fuelWarn = false
    var onJob = false
    var beacon = false
    var diffLock = false
    var wipers = 0

    var truckDmg: Float?
    var engineDmg: Float?
    var trailerDmg: Float?
    var cargoDmg: Float?

    var airPressure: Float?
    var oilPressure: Float?
    var oilTemp: Float?
    var waterTemp: Float?
    var odometer: Float?
    var batteryVoltage: Float?
    var airWarn: Float?
    var airEmergency: Float?
    var oilWarn: Float?
    var waterWarn: Float?
    var batteryWarn: Float?

    var jobIncome: UInt64?
    var jobDeliveredRevenue: Int64?
    var jobCancelledPenalty: Int64?
    var fineAmount: Int64?
    var tollgatePay: Int64?
    var ferryPay: Int64?
    var trainPay: Int64?

    // REV12 does not expose the bank account. This comes from the newest ATS
    // savegame and is refreshed in the background by BankBalanceReader.
    var bankBalance: Int64?
}

// MARK: - POSIX shared memory / SCSTelemetry
final class Shm {
    var base: UnsafeMutableRawPointer?
    var fd: Int32 = -1

    func closeShm() {
        if let p = base {
            munmap(p, 32768)
        }
        if fd >= 0 {
            Darwin.close(fd)
        }
        base = nil
        fd = -1
    }

    deinit {
        closeShm()
    }

    func tryOpen(checkSDK: Bool) -> Bool {
        closeShm()

        // shm_open is variadic in C and unavailable to Swift directly.
        typealias ShmOpenFn = @convention(c) (UnsafePointer<CChar>, Int32, Int32) -> Int32
        guard let sym = dlsym(dlopen(nil, RTLD_NOW), "shm_open") else {
            return false
        }
        let shmOpen = unsafeBitCast(sym, to: ShmOpenFn.self)
        let f = "/SCSTelemetry".withCString { shmOpen($0, O_RDONLY, 0) }
        guard f >= 0 else { return false }

        guard let p = mmap(nil, 32768, PROT_READ, MAP_SHARED, f, 0), p != MAP_FAILED else {
            Darwin.close(f)
            return false
        }

        if checkSDK && p.loadUnaligned(fromByteOffset: O_SDK, as: UInt8.self) == 0 {
            munmap(p, 32768)
            Darwin.close(f)
            return false
        }

        base = p
        fd = f
        return true
    }

    func rb(_ offset: Int) -> Int {
        Int(base!.loadUnaligned(fromByteOffset: offset, as: UInt8.self))
    }

    func ru(_ offset: Int) -> UInt32 {
        base!.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
    }

    func ri(_ offset: Int) -> Int32 {
        base!.loadUnaligned(fromByteOffset: offset, as: Int32.self)
    }

    func rf(_ offset: Int) -> Float {
        base!.loadUnaligned(fromByteOffset: offset, as: Float.self)
    }

    func rd(_ offset: Int) -> Double {
        base!.loadUnaligned(fromByteOffset: offset, as: Double.self)
    }

    func r64(_ offset: Int) -> UInt64 {
        base!.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
    }

    func ri64(_ offset: Int) -> Int64 {
        base!.loadUnaligned(fromByteOffset: offset, as: Int64.self)
    }

    func rs(_ offset: Int, length: Int = 64) -> String? {
        guard let base else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(length)

        for i in 0..<length {
            let byte = base.loadUnaligned(fromByteOffset: offset + i, as: UInt8.self)
            if byte == 0 { break }
            bytes.append(byte)
        }

        let value = String(decoding: bytes, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

func getSnap(_ shm: Shm) -> Snap {
    var s = Snap()
    guard shm.base != nil else { return s }
    if shm.rb(O_SDK) == 0 { return s }

    s.active = true
    s.paused = shm.rb(O_PAUSED) != 0
    s.ats = shm.ru(O_GAME) == 2
    s.gameTime = shm.ru(O_TIME_ABS)

    s.speed = shm.rf(O_SPEED)
    s.rpm = shm.rf(O_RPM)
    s.gear = shm.ri(O_GEAR)
    s.fuel = shm.rf(O_FUEL)
    s.fuelCap = shm.rf(O_FCAP)
    s.range = shm.rf(O_RANGE)
    s.cons = shm.rf(O_CONS)
    s.rpmMax = shm.rf(O_RPMMAX)
    s.cruise = shm.rf(O_CRUISE)
    s.cruiseOn = shm.rb(O_CRZON) != 0
    s.limit = shm.rf(O_LIMIT)

    s.truckBrand = shm.rs(O_TRUCKBRAND)
    s.truckId = shm.rs(O_TRUCKID)
    s.truckName = shm.rs(O_TRUCKNAME)

    s.cargoId = shm.rs(O_CARGOID)
    s.cargoName = shm.rs(O_CARGO)
    s.cargoMass = shm.rf(O_CARGOMASS)
    s.cargoLoaded = shm.rb(O_CARGOLOADED) != 0
    s.specialJob = shm.rb(O_SPECIALJOB) != 0

    s.posX = shm.rd(O_POSX)
    s.posY = shm.rd(O_POSY)
    s.posZ = shm.rd(O_POSZ)
    s.heading = shm.rd(O_HEADING)
    s.cityDst = shm.rs(O_CITYDST)
    s.citySrc = shm.rs(O_CITYSRC)

    s.lowB = shm.rb(O_LO) != 0
    s.highB = shm.rb(O_HI) != 0
    s.blinkL = shm.rb(O_BL) != 0
    s.blinkR = shm.rb(O_BR) != 0
    s.brake = shm.rb(O_BRK) != 0
    s.park = shm.rb(O_PARK) != 0
    s.motor = shm.rb(O_MOTOR) != 0
    s.engine = shm.rb(O_ENG) != 0
    s.parking = shm.rb(O_PARKING) != 0
    s.hazard = shm.rb(O_HAZ) != 0
    s.fuelWarn = shm.rb(O_FWARN) != 0
    s.beacon = shm.rb(O_BEACON) != 0
    s.diffLock = shm.rb(O_DIFF) != 0
    s.wipers = shm.rb(O_WIPERS)

    // REV12 does not expose cloud cover or storm state. Wipers are the only
    // available rain hint; the menu can override this with a manual state.
    s.weather = s.wipers > 0 ? .rain : .clear

    s.airPressure = shm.rf(O_AIR)
    s.oilPressure = shm.rf(O_OILP)
    s.oilTemp = shm.rf(O_OILTEMP)
    s.waterTemp = shm.rf(O_WATERTEMP)
    s.odometer = shm.rf(O_ODOMETER)
    s.batteryVoltage = shm.rf(O_BATT)
    s.airWarn = shm.rf(O_AIRWARN)
    s.airEmergency = shm.rf(O_AIREMERG)
    s.oilWarn = shm.rf(O_OILWARN)
    s.waterWarn = shm.rf(O_WATERWARN)
    s.batteryWarn = shm.rf(O_BATTWARN)

    s.onJob = shm.rb(O_ONJOB) != 0
    s.jobIncome = shm.r64(O_JOBINCOME)
    s.jobDeliveredRevenue = shm.ri64(O_JOBDELIVERED)
    s.jobCancelledPenalty = shm.ri64(O_JOBCANCELLED)
    s.fineAmount = shm.ri64(O_FINE)
    s.tollgatePay = shm.ri64(O_TOLL)
    s.ferryPay = shm.ri64(O_FERRY)
    s.trainPay = shm.ri64(O_TRAIN)
    s.planned = shm.ru(O_PLANNED)
    s.routeD = shm.rf(O_ROUTED)
    s.routeT = shm.rf(O_ROUTET)

    s.engineDmg = shm.rf(O_WENG) * 100

    var maxTruck: Float?
    for v in [shm.rf(O_WENG), shm.rf(O_WTRA), shm.rf(O_WCAB), shm.rf(O_WCHA), shm.rf(O_WWHE)] {
        if maxTruck == nil || v > maxTruck! { maxTruck = v }
    }
    if let m = maxTruck { s.truckDmg = m * 100 }

    let hasTrailer = shm.rb(O_TATT) != 0
    var maxTrailer: Float?
    for v in [shm.rf(O_TCHA), shm.rf(O_TWHE), shm.rf(O_TBOD)] {
        if maxTrailer == nil || v > maxTrailer! { maxTrailer = v }
    }
    if hasTrailer, let m = maxTrailer { s.trailerDmg = m * 100 }

    if hasTrailer {
        s.cargoDmg = max(shm.rf(O_TCD), shm.rf(O_JCD)) * 100
    }

    return s
}

// MARK: - Reader
final class TelemetryReader {
    private let shm = Shm()
    private let bankReader = BankBalanceReader()
    private let demoMode: Bool
    private let demoStart = Date.timeIntervalSinceReferenceDate
    private var lastOpenAttempt: TimeInterval = 0

    // Manual weather selection from the status menu. When nil, the reader
    // infers rain from the wipers and otherwise reports clear weather.
    var weatherOverride: WeatherCondition?

    init(demoMode: Bool = ProcessInfo.processInfo.arguments.contains("--demo")) {
        self.demoMode = demoMode
    }

    func snapshot() -> Snap {
        if demoMode {
            return applyingWeatherOverride(demoSnapshot())
        }

        let now = Date.timeIntervalSinceReferenceDate
        if shm.base == nil, now - lastOpenAttempt >= 1.0 {
            lastOpenAttempt = now
            _ = shm.tryOpen(checkSDK: true)
        }

        var snap = applyingWeatherOverride(getSnap(shm))
        if snap.active {
            snap.bankBalance = bankReader.current()
        }

        // If the game closed, drop the old mapping and retry later.
        if !snap.active && shm.base != nil {
            shm.closeShm()
        }

        return snap
    }

    private func applyingWeatherOverride(_ snap: Snap) -> Snap {
        guard let weatherOverride else { return snap }
        var result = snap
        result.weather = weatherOverride
        return result
    }

    private func demoSnapshot() -> Snap {
        let t = Date.timeIntervalSinceReferenceDate - demoStart
        var s = Snap()
        s.active = true
        s.paused = false
        s.ats = true
        s.demo = true
        s.engine = true
        s.motor = true
        s.rpmMax = 2100
        s.fuelCap = 600
        s.gameTime = UInt32((6 * 60 + Int(t * 30)) % (24 * 60))
        s.weather = WeatherCondition.allCases[Int(t / 5) % WeatherCondition.allCases.count]

        let wave = sin(t * 0.9) * 0.5 + sin(t * 2.1) * 0.08
        s.rpm = Float(min(max(1450 + wave * 520, 550), 2050))
        s.truckBrand = "Kenworth"
        s.truckId = "vehicle.kenworth.t800_gtm"
        s.truckName = "T800"
        s.cargoId = "bulldozer"
        s.cargoName = "Buldócer"
        s.cargoMass = 18_189.1
        s.cargoLoaded = true
        s.specialJob = false
        s.fuel = Float(max(90, 320 - t * 0.03))
        s.range = Float(max(120, 740 - t * 0.06))
        s.speed = 22.2
        s.gear = 10
        s.cons = 0.00028
        s.cruise = 20.8
        s.limit = 27.7
        s.cruiseOn = true
        s.fuelWarn = false
        s.lowB = true
        s.highB = true
        s.parking = true
        s.blinkL = true
        s.blinkR = false
        s.hazard = false
        s.brake = false
        s.park = true
        s.beacon = true
        s.wipers = 1
        s.diffLock = true
        s.truckDmg = 12
        s.engineDmg = 18
        s.trailerDmg = 45
        s.cargoDmg = 80
        s.airPressure = 118
        s.oilPressure = 60
        s.oilTemp = 103
        s.waterTemp = 92
        s.odometer = 4_524.6 + Float(t * 0.01)
        s.batteryVoltage = 26.8
        s.airWarn = 59.16
        s.airEmergency = 29.58
        s.oilWarn = 14
        s.waterWarn = 95
        s.batteryWarn = 23.76

        s.onJob = true
        s.jobIncome = 94_144
        s.jobDeliveredRevenue = 173_664
        s.jobCancelledPenalty = 0
        s.fineAmount = 0
        s.tollgatePay = 1_250
        s.ferryPay = 0
        s.trainPay = 0
        s.bankBalance = 5_341_147
        s.planned = 350
        s.posX = 1_234.5 + t * 0.8
        s.posY = 0
        s.posZ = -5_678.9 - t * 0.4
        s.heading = (0.12 + t * 0.012).truncatingRemainder(dividingBy: 1)
        s.cityDst = "Los Angeles"
        s.citySrc = "Phoenix"
        s.routeD = 123_000
        s.routeT = 5_700
        return s
    }
}
