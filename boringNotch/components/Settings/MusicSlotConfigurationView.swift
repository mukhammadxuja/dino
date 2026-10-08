//
//  MusicSlotConfigurationView.swift
//  boringNotch
//
//  Created by Alexander on 2025-11-17.
//

import Defaults
import SwiftUI
import UniformTypeIdentifiers

struct MusicSlotConfigurationView: View {
    @Default(.musicControlSlots) private var musicControlSlots
    @ObservedObject private var musicManager = MusicManager.shared
    @State private var draggedSlot: MusicControlButton?
    @State private var hoveredSlotIndex: Int? = nil

    private let fixedSlotCount: Int = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with colored icon, title, description
            headerSection

            // Centered Layout Preview
            centeredPreviewSection

            // Palette of available customizable controls
            paletteSection

            // Footer with Reset button
            footerSection
        }
        .onAppear {
            ensureSlotCapacity(fixedSlotCount)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Player Controls Layout")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.primary)
                Text("Customize secondary buttons on the sides of core playback controls")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Centered Preview Section
    private var centeredPreviewSection: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()

                HStack(spacing: 8) {
                    // Slot 0: Customizable Left Slot
                    customizableSlotView(at: 0, label: "Left")

                    // Slot 1: Fixed Previous
                    fixedPlaybackSlotView(icon: "backward.fill", label: "Prev", size: 16)

                    // Slot 2: Fixed Play/Pause
                    fixedPlaybackSlotView(icon: "playpause.fill", label: "Play", size: 18, isPrimary: true)

                    // Slot 3: Fixed Next
                    fixedPlaybackSlotView(icon: "forward.fill", label: "Next", size: 16)

                    // Slot 4: Customizable Right Slot
                    customizableSlotView(at: 4, label: "Right")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

                Spacer()
            }

            Text("Center controls are fixed. Click or drag to configure Left and Right buttons.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Fixed Center Control View
    private func fixedPlaybackSlotView(icon: String, label: String, size: CGFloat, isPrimary: Bool = false) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isPrimary ? Color.primary.opacity(0.12) : Color.primary.opacity(0.07))
                    .frame(width: isPrimary ? 46 : 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: size, weight: .bold))
                    .foregroundColor(.primary)
            }

            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Customizable Slot View (Slots 0 and 4)
    @ViewBuilder
    private func customizableSlotView(at index: Int, label: String) -> some View {
        let slot = slotValue(at: index)
        let isHovered = hoveredSlotIndex == index

        VStack(spacing: 4) {
            ZStack {
                if slot != .none {
                    // Filled slot
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.effectiveAccent.opacity(isHovered ? 0.18 : 0.12))
                        .frame(width: 44, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.effectiveAccent.opacity(isHovered ? 0.7 : 0.4), lineWidth: 1.2)
                        )

                    Image(systemName: slot.iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(controlColor(for: slot))
                } else {
                    // Empty slot
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .frame(width: 44, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
                        )

                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .frame(width: 44, height: 40)
            .overlay(alignment: .topTrailing) {
                if slot != .none {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            updateSlot(.none, at: index)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(isHovered ? .red : .secondary)
                            .background(Circle().fill(Color.white))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onHover { hov in
                hoveredSlotIndex = hov ? index : nil
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    if slot != .none {
                        updateSlot(.none, at: index)
                    }
                }
            }
            .onDrag {
                if slot != .none {
                    DispatchQueue.main.async { draggedSlot = slot }
                    return NSItemProvider(object: NSString(string: "slot:\(index)"))
                }
                return NSItemProvider()
            }
            .onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
                let handled = handleDrop(providers, toIndex: index)
                DispatchQueue.main.async { draggedSlot = nil }
                return handled
            }

            Text(slot != .none ? slot.label : "\(label) Slot")
                .font(.system(size: 9.5, weight: slot != .none ? .semibold : .medium))
                .foregroundColor(slot != .none ? .primary : .secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Palette Section (Available Controls)
    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Controls")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                ForEach(MusicControlButton.pickerOptions, id: \.self) { control in
                    paletteItemView(for: control)
                }
            }
        }
    }

    // MARK: - Palette Item View
    private var activeInSlots: [MusicControlButton] {
        [slotValue(at: 0), slotValue(at: 4)].filter { $0 != .none }
    }

    private func isControlActive(_ control: MusicControlButton) -> Bool {
        activeInSlots.contains(control)
    }

    private func paletteItemView(for control: MusicControlButton) -> some View {
        let isActive = isControlActive(control)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                toggleControlPlacement(control)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? Color.effectiveAccent.opacity(0.12) : Color.primary.opacity(0.04))
                        .frame(width: 42, height: 42)

                    Image(systemName: control.iconName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(controlColor(for: control))

                    if isActive {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.effectiveAccent)
                                    .background(Circle().fill(Color.white))
                            }
                            Spacer()
                        }
                        .frame(width: 44, height: 44)
                        .offset(x: 2, y: -2)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            isActive ? Color.effectiveAccent : Color.primary.opacity(0.08),
                            lineWidth: isActive ? 1.5 : 1
                        )
                )

                Text(controlShortLabel(for: control))
                    .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrag {
            return NSItemProvider(object: NSString(string: "control:\(control.rawValue)"))
        }
    }

    // MARK: - Footer Section with Reset Button
    private var footerSection: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    musicControlSlots = MusicControlButton.defaultLayout
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                    Text("Reset to Defaults")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers
    private func controlColor(for control: MusicControlButton) -> Color {
        switch control {
        case .shuffle:
            return .orange
        case .goBackward, .goForward:
            return .blue
        case .repeatMode:
            return .purple
        case .favorite:
            return .pink
        case .volume:
            return .teal
        default:
            return .primary
        }
    }

    private func controlShortLabel(for control: MusicControlButton) -> String {
        switch control {
        case .shuffle: return "Shuffle"
        case .goBackward: return "15s Back"
        case .goForward: return "15s Fwd"
        case .repeatMode: return "Repeat"
        case .favorite: return "Favorite"
        case .volume: return "Volume"
        default: return control.label
        }
    }

    private func toggleControlPlacement(_ control: MusicControlButton) {
        if let idx0 = slotValue(at: 0) == control ? 0 : (slotValue(at: 4) == control ? 4 : nil) {
            updateSlot(.none, at: idx0)
        } else {
            // Assign to first empty slot (slot 0 or slot 4)
            if slotValue(at: 0) == .none {
                updateSlot(control, at: 0)
            } else if slotValue(at: 4) == .none {
                updateSlot(control, at: 4)
            } else {
                // If both are filled, replace slot 0
                updateSlot(control, at: 0)
            }
        }
    }

    private func ensureSlotCapacity(_ target: Int) {
        guard target > musicControlSlots.count else { return }
        let missing = target - musicControlSlots.count
        musicControlSlots.append(contentsOf: Array(repeating: .none, count: missing))
    }

    private func slotValue(at index: Int) -> MusicControlButton {
        guard musicControlSlots.indices.contains(index) else { return .none }
        return musicControlSlots[index]
    }

    private func handleDrop(_ providers: [NSItemProvider], toIndex: Int) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSString.self) {
                provider.loadObject(ofClass: NSString.self) { item, _ in
                    if let nsstring = item as? NSString {
                        let raw = nsstring as String
                        DispatchQueue.main.async {
                            processDropString(raw, toIndex: toIndex)
                        }
                    } else if let str = item as? String {
                        DispatchQueue.main.async {
                            processDropString(str, toIndex: toIndex)
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    private func processDropString(_ raw: String, toIndex: Int) {
        guard toIndex == 0 || toIndex == 4 else { return }

        if raw.hasPrefix("slot:") {
            let from = Int(raw.replacingOccurrences(of: "slot:", with: "")) ?? -1
            guard from >= 0 && from < fixedSlotCount else { return }
            var slots = musicControlSlots
            if from < slots.count && toIndex < slots.count {
                slots.swapAt(from, toIndex)
                musicControlSlots = slots
            }
        } else if raw.hasPrefix("control:") {
            let val = raw.replacingOccurrences(of: "control:", with: "")
            if let control = MusicControlButton(rawValue: val) {
                var slots = musicControlSlots
                if let existing = slots.firstIndex(of: control), existing != toIndex {
                    slots[existing] = .none
                    musicControlSlots = slots
                }
                updateSlot(control, at: toIndex)
            }
        }
    }

    private func updateSlot(_ value: MusicControlButton, at index: Int) {
        var slots = musicControlSlots
        if index >= slots.count {
            slots.append(contentsOf: Array(repeating: .none, count: index - slots.count + 1))
        }
        slots[index] = value
        // Ensure center controls remain previous, playPause, next
        if slots.count >= 4 {
            slots[1] = .previous
            slots[2] = .playPause
            slots[3] = .next
        }
        musicControlSlots = slots
    }
}
