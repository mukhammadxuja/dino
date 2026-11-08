import AppKit

// Isolate the production managers from XPC and the application's window lifecycle.
// No hardware brightness or user settings are changed by these checks.
enum SneakContentType { case brightness, backlight, volume }

@MainActor
final class BoringViewCoordinator {
    static let shared = BoringViewCoordinator()
    struct Presentation {
        var show = false
        var type: SneakContentType = .volume
        var value: CGFloat = 0
    }
    var sneakPeek = Presentation()
    func toggleSneakPeek(status: Bool, type: SneakContentType, value: CGFloat) {
        sneakPeek = Presentation(show: status, type: type, value: value)
    }
}

@MainActor
final class XPCHelperClient {
    static let shared = XPCHelperClient()
    func currentScreenBrightness() async -> Float? { 0.5 }
    func setScreenBrightness(_ value: Float) async -> Bool { true }
    func currentKeyboardBrightness() async -> Float? { 0.5 }
    func setKeyboardBrightness(_ value: Float) async -> Bool { true }
}

@MainActor
private final class Device {
    var actual: Float = 0.5
    var writes: [Float] = []
    var reads: [CheckedContinuation<Float?, Never>] = []
    var completions: [CheckedContinuation<Bool, Never>] = []
    var holdReads = false

    func read() async -> Float? {
        if holdReads {
            return await withCheckedContinuation { reads.append($0) }
        }
        return actual
    }

    func write(_ value: Float) async -> Bool {
        writes.append(value)
        let success = await withCheckedContinuation { completions.append($0) }
        if success { actual = value }
        return success
    }
}

@main
struct BrightnessResponseCheck {
    @MainActor
    static func waitUntil(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(3)
        while !condition() {
            precondition(ContinuousClock.now < deadline, "Timed out waiting for hardware request")
            await Task.yield()
        }
    }

    static func near(_ actual: Float, _ expected: Float) {
        precondition(abs(actual - expected) < 0.0001, "Expected \(expected), got \(actual)")
    }

    @MainActor
    static func main() async {
        // A blocked read/write must not block immediate HUD values or lose repeats.
        do {
            let device = Device()
            device.holdReads = true
            var visible: Float = 0
            let queue = BrightnessAdjustmentQueue(
                read: { await device.read() }, write: { await device.write($0) },
                onChange: { value, _ in visible = value }
            )
            queue.setRelative(delta: 0.1)
            near(visible, 0.1)
            queue.setRelative(delta: 0.1)
            near(visible, 0.2)
            await waitUntil { device.reads.count == 1 }
            device.reads.removeFirst().resume(returning: 0.5)
            await waitUntil { device.writes.count == 1 }
            near(device.writes[0], 0.7)
            queue.setRelative(delta: 0.1)
            queue.setRelative(delta: 0.1)
            near(visible, 0.9)
            precondition(device.writes.count == 1, "Hardware writes overlapped")
            device.completions.removeFirst().resume(returning: true)
            await waitUntil { device.writes.count == 2 }
            near(device.writes[1], 0.9)
            near(visible, 0.9)
            device.completions.removeFirst().resume(returning: true)
            await waitUntil { abs(device.actual - 0.9) < 0.0001 }
        }

        // Preserve clamping order, including a slider replacing earlier keypresses.
        do {
            let device = Device()
            var visible: Float = 0
            let queue = BrightnessAdjustmentQueue(
                read: { await device.read() }, write: { await device.write($0) },
                onChange: { value, _ in visible = value }
            )
            queue.setAbsolute(1)
            queue.setRelative(delta: 0.2)
            queue.setRelative(delta: -0.1)
            await waitUntil { device.writes.count == 1 }
            near(device.writes[0], 0.9)
            queue.setAbsolute(0.3)
            queue.setRelative(delta: 0.1)
            near(visible, 0.4)
            device.completions.removeFirst().resume(returning: true)
            await waitUntil { device.writes.count == 2 }
            near(device.writes[1], 0.4)
            device.completions.removeFirst().resume(returning: true)
            await waitUntil { abs(device.actual - 0.4) < 0.0001 }
        }

        // A stale initialization read must never overwrite a newer user action.
        do {
            let device = Device()
            device.holdReads = true
            var visible: Float = 0
            let queue = BrightnessAdjustmentQueue(
                read: { await device.read() }, write: { await device.write($0) },
                onChange: { value, _ in visible = value }
            )
            queue.refresh()
            await waitUntil { device.reads.count == 1 }
            queue.setAbsolute(0.8)
            device.reads.removeFirst().resume(returning: 0.2)
            await waitUntil { device.reads.count == 1 }
            near(visible, 0.8)
            device.reads.removeFirst().resume(returning: 0.5)
            await waitUntil { device.writes.count == 1 }
            device.completions.removeFirst().resume(returning: false)
            await waitUntil { device.reads.count == 1 }
            device.reads.removeFirst().resume(returning: 0.5)
            await waitUntil { abs(visible - 0.5) < 0.0001 }
        }

        // A failed write must rebase later keys on hardware, then accept a new burst.
        do {
            let device = Device()
            var visible: Float = 0
            let queue = BrightnessAdjustmentQueue(
                read: { await device.read() }, write: { await device.write($0) },
                onChange: { value, _ in visible = value }
            )
            queue.setRelative(delta: 0.1)
            await waitUntil { device.writes.count == 1 }
            queue.setRelative(delta: 0.1)
            device.completions.removeFirst().resume(returning: false)
            await waitUntil { device.writes.count == 2 }
            near(device.writes[1], 0.6)
            device.completions.removeFirst().resume(returning: true)
            await waitUntil { abs(device.actual - 0.6) < 0.0001 }
            // Simulate an external Control Center change between bursts.
            device.actual = 0.2
            queue.setRelative(delta: 0.1)
            await waitUntil { device.writes.count == 3 }
            near(device.writes[2], 0.3)
            near(visible, 0.3)
            device.completions.removeFirst().resume(returning: true)
            await waitUntil { abs(device.actual - 0.3) < 0.0001 }
        }

        // An unavailable initial read must not apply the first delta twice.
        do {
            var visible: Float = 0
            var writes: [Float] = []
            let queue = BrightnessAdjustmentQueue(
                read: { nil }, write: { writes.append($0); return true },
                onChange: { value, _ in visible = value }
            )
            queue.setRelative(delta: 0.0625)
            await waitUntil { writes.count == 1 }
            near(writes[0], 0.0625)
            near(visible, 0.0625)
        }

        // Both real manager entry points must present the HUD synchronously.
        let coordinator = BoringViewCoordinator.shared
        BrightnessManager.shared.setRelative(delta: 0.0625)
        precondition(coordinator.sneakPeek.show && coordinator.sneakPeek.type == .brightness)
        near(Float(coordinator.sneakPeek.value), BrightnessManager.shared.rawBrightness)
        KeyboardBacklightManager.shared.setRelative(delta: 0.0625)
        precondition(coordinator.sneakPeek.type == .backlight)
        near(Float(coordinator.sneakPeek.value), KeyboardBacklightManager.shared.rawBrightness)
        print("PASS: immediate HUD, ordered/coalesced writes, repeated keys, clamp order, slider replacement, stale refresh, failure reconciliation, both managers")
    }
}
