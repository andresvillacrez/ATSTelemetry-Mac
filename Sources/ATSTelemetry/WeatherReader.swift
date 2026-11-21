import Foundation
import AppKit
import Darwin

/// Lee el clima directamente de la memoria del juego.
///
/// El SDK de SCS (REV12) no publica el clima. En la build Mac de ATS
/// 1.62.2.2 el objeto `economy` está referenciado desde `__DATA` en el
/// offset `0x3C18B80`. Sus campos de clima son:
///   +0x4FC  float  stored_weather_change_timer
///   +0x500  int    stored_current_weather
///   +0x5F4  float  stored_rain_wetness (puede ser NaN con tiempo seco)
///
/// El offset del puntero es específico de esta build. Si no valida, se
/// devuelve nil y el panel usa el respaldo en vivo de los limpiabrisas.
final class WeatherReader {
    private let lock = NSLock()

    private var processID: pid_t = 0
    private var taskPort: mach_port_t = 0
    private var isATS = false
    private var moduleBase: mach_vm_address_t = 0
    private var objectBase: mach_vm_address_t = 0

    private var lastRead: TimeInterval = 0
    private var lastCondition: WeatherCondition?
    private var lastReportedCondition: WeatherCondition?
    private var reportedPermissionFailure = false
    private var reportedLocateFailure = false
    private var didLogFirstRead = false

    // Offset del puntero dentro de __DATA (ATS 1.62.2.2).
    private let atsEconomyPointerOffset: UInt64 = 0x3C18B80
    private let objectPointerAdjust: Int64 = -4
    private let timerOffset: Int = 0x4FC
    private let weatherOffset: Int = 0x500
    private let wetnessOffset: Int = 0x5F4
    private let objectReadLength = 0x700
    private let cacheSeconds: TimeInterval = 0.9

    func read(ats: Bool) -> WeatherCondition? {
        lock.lock()
        defer { lock.unlock() }

        if !didLogFirstRead {
            didLogFirstRead = true
            weatherLog("lector de clima iniciado (ats=\(ats))")
        }

        let now = Date.timeIntervalSinceReferenceDate
        if now - lastRead < cacheSeconds {
            return lastCondition
        }
        lastRead = now

        guard let pid = runningGamePID(ats: ats) else {
            resetProcess()
            lastCondition = nil
            return nil
        }

        if pid != processID || ats != isATS || taskPort == 0 {
            resetProcess()
            processID = pid
            isATS = ats

            var task: mach_port_t = 0
            let kr = task_for_pid(mach_task_self_, pid, &task)
            guard kr == KERN_SUCCESS, task != 0 else {
                if !reportedPermissionFailure {
                    reportedPermissionFailure = true
                    weatherLog("task_for_pid falló PID \(pid) kr \(kr)")
                }
                processID = 0
                lastCondition = nil
                return nil
            }
            taskPort = task
        }

        if moduleBase == 0 {
            moduleBase = findModuleBase(pid: pid, task: taskPort, ats: ats) ?? 0
            if moduleBase != 0 {
                weatherLog("base del módulo = 0x\(String(moduleBase, radix: 16))")
            }
        }
        guard moduleBase != 0 else {
            lastCondition = nil
            return nil
        }

        if objectBase == 0 {
            guard locateObject(ats: ats) else {
                lastCondition = nil
                return nil
            }
        }

        guard let data = readData(task: taskPort, address: objectBase, size: objectReadLength) else {
            objectBase = 0
            lastCondition = nil
            return nil
        }

        let timer = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: timerOffset, as: Float.self) }
        let current = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: weatherOffset, as: Int32.self) }
        let wetness = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: wetnessOffset, as: Float.self) }

        guard timer.isFinite, current >= 0, current <= 16 else {
            objectBase = 0
            lastCondition = nil
            return nil
        }

        let condition = classify(current: current, wetness: wetness)
        if condition != lastReportedCondition {
            lastReportedCondition = condition
            weatherLog("clima = \(condition.rawValue) (índice \(current), wetness \(wetness))")
        }
        lastCondition = condition
        return condition
    }

    private func classify(current: Int32, wetness: Float) -> WeatherCondition {
        if wetness.isFinite {
            if wetness >= 0.80 { return .storm }
            if wetness >= 0.15 { return .rain }
            if wetness >= 0.02 { return .cloudy }
        }

        // El campo de humedad puede ser NaN con tiempo seco; el índice del
        // perfil sigue siendo válido (1 = despejado en esta build).
        switch current {
        case 0, 1: return .clear
        case 2: return .cloudy
        case 3: return .rain
        case 4: return .storm
        default: return current % 2 == 0 ? .cloudy : .rain
        }
    }

    private func locateObject(ats: Bool) -> Bool {
        guard ats else {
            // ETS2 usa otro offset de módulo; sin una build instalada no se
            // inventa un valor. El panel mantiene el respaldo por limpiabrisas.
            return false
        }

        let pointerAddress = moduleBase + atsEconomyPointerOffset
        guard let pointer = readUInt64(task: taskPort, address: pointerAddress),
              isValidPointer(pointer) else {
            if !reportedLocateFailure {
                reportedLocateFailure = true
                weatherLog("puntero de economía inválido en 0x\(String(pointerAddress, radix: 16))")
            }
            return false
        }

        let candidate = mach_vm_address_t(Int64(pointer) + objectPointerAdjust)
        guard let data = readData(task: taskPort, address: candidate, size: objectReadLength) else {
            return false
        }

        let timer = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: timerOffset, as: Float.self) }
        let current = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: weatherOffset, as: Int32.self) }
        guard timer.isFinite, current >= 0, current <= 16 else {
            return false
        }

        objectBase = candidate
        weatherLog("objeto de clima en 0x\(String(candidate, radix: 16))")
        return true
    }

    private func runningGamePID(ats: Bool) -> pid_t? {
        let bundleID = ats ? "com.scssoft.ats" : "com.scssoft.ets2"
        let executable = ats ? "amtrucks" : "eurotrucks2"
        let apps = NSWorkspace.shared.runningApplications

        if let app = apps.first(where: { $0.bundleIdentifier == bundleID }) {
            return app.processIdentifier
        }
        return apps.first(where: { $0.executableURL?.lastPathComponent == executable })?.processIdentifier
    }

    private func resetProcess() {
        if taskPort != 0 {
            mach_port_deallocate(mach_task_self_, taskPort)
        }
        taskPort = 0
        processID = 0
        moduleBase = 0
        objectBase = 0
        lastCondition = nil
        lastReportedCondition = nil
        reportedLocateFailure = false
    }

    private func isValidPointer(_ pointer: UInt64) -> Bool {
        pointer > 0x10000
            && pointer < 0x0000_7FFF_FFFF_FFFF
            && (pointer & 3) == 0
    }

    private func readData(task: mach_port_t, address: mach_vm_address_t, size: Int) -> Data? {
        guard size > 0 else { return nil }
        var data = Data(count: size)
        var readSize: mach_vm_size_t = 0

        let kr = data.withUnsafeMutableBytes { raw -> kern_return_t in
            guard let base = raw.baseAddress else { return KERN_INVALID_ARGUMENT }
            return mach_vm_read_overwrite(
                task,
                address,
                mach_vm_size_t(size),
                mach_vm_address_t(UInt(bitPattern: base)),
                &readSize
            )
        }

        guard kr == KERN_SUCCESS, readSize == mach_vm_size_t(size) else { return nil }
        return data
    }

    private func readUInt64(task: mach_port_t, address: mach_vm_address_t) -> UInt64? {
        guard let data = readData(task: task, address: address, size: 8) else { return nil }
        return data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt64.self) }
    }

    private func findModuleBase(pid: pid_t, task: mach_port_t, ats: Bool) -> mach_vm_address_t? {
        let expectedSuffix = ats ? "/amtrucks" : "/eurotrucks2"
        var address: mach_vm_address_t = 0
        var size: mach_vm_size_t = 0
        var bestAddress: mach_vm_address_t = 0
        var bestSize: mach_vm_size_t = 0
        var info = vm_region_basic_info_data_64_t()
        let infoCount = mach_msg_type_number_t(
            MemoryLayout<vm_region_basic_info_data_64_t>.size / MemoryLayout<integer_t>.size
        )

        for _ in 0..<4096 {
            var count = infoCount
            var objectName: mach_port_t = 0
            let kr = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                    mach_vm_region(
                        task,
                        &address,
                        &size,
                        VM_REGION_BASIC_INFO_64,
                        intPointer,
                        &count,
                        &objectName
                    )
                }
            }
            if objectName != 0 {
                mach_port_deallocate(mach_task_self_, objectName)
            }
            guard kr == KERN_SUCCESS, size > 0 else { break }

            var path = [CChar](repeating: 0, count: 1024)
            let length = path.withUnsafeMutableBufferPointer { buffer in
                proc_regionfilename(pid, address, buffer.baseAddress, UInt32(buffer.count))
            }
            if length > 0, String(cString: path).hasSuffix(expectedSuffix), size > bestSize {
                bestAddress = address
                bestSize = size
            }

            address += size
        }
        return bestAddress == 0 ? nil : bestAddress
    }

    private func weatherLog(_ message: String) {
        let line = "\(Date()) \(message)\n"
        let path = "/tmp/ATS-weather.log"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: path),
           let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
