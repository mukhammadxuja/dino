//  BrightnessManager.swift
//  boringNotch
//
//  Created by JeanLouis on 08/22/24.

import AppKit

/// Shows changes immediately while serializing hardware writes and preserving key order.
@MainActor
final class BrightnessAdjustmentQueue {
    private enum Adjustment {
        case relative(Float)
        case absolute(Float)

        func applying(to value: Float) -> Float {
            switch self {
            case .relative(let delta): return max(0, min(1, value + delta))
            case .absolute(let target): return max(0, min(1, target))
            }
        }
    }

    private let read: () async -> Float?
    private let write: (Float) async -> Bool
    private let onChange: (Float, Bool) -> Void
    private var value: Float = 0
    private var revision: UInt = 0
    private var pending: [Adjustment] = []
    private var worker: Task<Void, Never>?

    init(read: @escaping () async -> Float?, write: @escaping (Float) async -> Bool,
         onChange: @escaping (Float, Bool) -> Void) {
        self.read = read
        self.write = write
        self.onChange = onChange
    }

    func refresh() {
        guard worker == nil else { return }
        let requestedRevision = revision
        Task {
            guard let current = await read(), revision == requestedRevision else { return }
            update(current, touchDate: false)
        }
    }

    func setRelative(delta: Float) {
        enqueue(.relative(delta))
    }

    func setAbsolute(_ target: Float) {
        enqueue(.absolute(target))
    }

    private func enqueue(_ adjustment: Adjustment) {
        revision &+= 1
        let startingValue = value
        pending.append(adjustment)
        update(adjustment.applying(to: value), touchDate: true)
        guard worker == nil else { return }
        worker = Task { await drain(startingValue: startingValue) }
    }

    private func update(_ newValue: Float, touchDate: Bool) {
        value = newValue
        onChange(newValue, touchDate)
    }

    private func drain(startingValue: Float) async {
        // Read once per burst to account for changes made in Control Center.
        // The HUD already reflects the keypress while this request is in flight.
        var actual = await read() ?? startingValue
        while !pending.isEmpty {
            let target = pending.reduce(actual) { $1.applying(to: $0) }
            pending.removeAll(keepingCapacity: true)
            update(target, touchDate: false)
            if await write(target) {
                actual = target
            } else {
                actual = await read() ?? actual
            }
        }
        update(actual, touchDate: false)
        worker = nil
    }
}

@MainActor
final class BrightnessManager: ObservableObject {
	static let shared = BrightnessManager()

	@Published private(set) var rawBrightness: Float = 0
	@Published private(set) var animatedBrightness: Float = 0
	@Published private(set) var lastChangeAt: Date = .distantPast

	private let visibleDuration: TimeInterval = 1.2
	private let client = XPCHelperClient.shared
	private lazy var adjustments = BrightnessAdjustmentQueue(
		read: { [client] in await client.currentScreenBrightness() },
		write: { [client] in await client.setScreenBrightness($0) },
		onChange: { [weak self] value, touchDate in
			self?.publish(brightness: value, touchDate: touchDate)
		}
	)

	private init() { refresh() }

	var shouldShowOverlay: Bool { Date().timeIntervalSince(lastChangeAt) < visibleDuration }

	func refresh() {
		adjustments.refresh()
	}

	func setRelative(delta: Float) {
		adjustments.setRelative(delta: delta)
		BoringViewCoordinator.shared.toggleSneakPeek(status: true, type: .brightness, value: CGFloat(rawBrightness))
	}

	func setAbsolute(value: Float) {
		adjustments.setAbsolute(value)
	}

	private func publish(brightness: Float, touchDate: Bool) {
		if touchDate { lastChangeAt = Date() }
		if rawBrightness != brightness { rawBrightness = brightness }
		if animatedBrightness != brightness { animatedBrightness = brightness }
		let coordinator = BoringViewCoordinator.shared
		if coordinator.sneakPeek.show && coordinator.sneakPeek.type == .brightness
			&& coordinator.sneakPeek.value != CGFloat(brightness) {
			coordinator.sneakPeek.value = CGFloat(brightness)
		}
	}
}

// (DisplayServices helpers moved into XPC helper)

// MARK: - Keyboard Backlight Controller
@MainActor
final class KeyboardBacklightManager: ObservableObject {
	static let shared = KeyboardBacklightManager()

	@Published private(set) var rawBrightness: Float = 0
	@Published private(set) var lastChangeAt: Date = .distantPast

	private let visibleDuration: TimeInterval = 1.2
	private let client = XPCHelperClient.shared
	private lazy var adjustments = BrightnessAdjustmentQueue(
		read: { [client] in await client.currentKeyboardBrightness() },
		write: { [client] in await client.setKeyboardBrightness($0) },
		onChange: { [weak self] value, touchDate in
			self?.publish(brightness: value, touchDate: touchDate)
		}
	)

	private init() { refresh() }

	var shouldShowOverlay: Bool { Date().timeIntervalSince(lastChangeAt) < visibleDuration }

	func refresh() {
		adjustments.refresh()
	}

	func setRelative(delta: Float) {
		adjustments.setRelative(delta: delta)
		BoringViewCoordinator.shared.toggleSneakPeek(
			status: true, type: .backlight, value: CGFloat(rawBrightness)
		)
	}

	func setAbsolute(value: Float) {
		adjustments.setAbsolute(value)
	}

	private func publish(brightness: Float, touchDate: Bool) {
		if touchDate { lastChangeAt = Date() }
		if rawBrightness != brightness { rawBrightness = brightness }
		let coordinator = BoringViewCoordinator.shared
		if coordinator.sneakPeek.show && coordinator.sneakPeek.type == .backlight
			&& coordinator.sneakPeek.value != CGFloat(brightness) {
			coordinator.sneakPeek.value = CGFloat(brightness)
		}
	}
}

