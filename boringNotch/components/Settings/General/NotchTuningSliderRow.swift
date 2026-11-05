import AppKit
import Defaults
import SwiftUI

struct NotchTuningSliderRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let axis: NotchTuningAxis
    let range: ClosedRange<Int>
    @Binding var value: Int
    @State private var draftValue: Int
    @State private var isDragging = false

    private let thumbSize: CGFloat = 22
    init(title: String, subtitle: String, icon: String, axis: NotchTuningAxis, range: ClosedRange<Int>, value: Binding<Int>) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.axis = axis
        self.range = range
        self._value = value
        self._draftValue = State(initialValue: min(range.upperBound, max(range.lowerBound, value.wrappedValue)))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.effectiveAccent.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.effectiveAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.effectiveAccent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.effectiveAccent.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(Color.effectiveAccent.opacity(0.18), lineWidth: 1))
            }

            GeometryReader { geometry in
                let usableWidth = max(1, geometry.size.width - thumbSize)
                let fraction = CGFloat(draftValue - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)
                let thumbX = usableWidth * fraction

                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.13))
                        .frame(width: usableWidth, height: 6)
                        .offset(x: thumbSize / 2, y: 11)

                    Capsule()
                        .fill(Color.effectiveAccent)
                        .frame(width: thumbX, height: 6)
                        .offset(x: thumbSize / 2, y: 11)

                    ForEach(0..<(range.upperBound - range.lowerBound + 1), id: \.self) { index in
                        Circle()
                            .fill(Color.primary.opacity(0.25))
                            .frame(width: 3, height: 3)
                            .offset(x: thumbSize / 2 + usableWidth * CGFloat(index) / CGFloat(range.upperBound - range.lowerBound) - 1.5, y: 32)
                    }

                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.17), radius: 4, y: 2)
                        .offset(x: thumbX, y: 3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                NotchTuningPreviewState.shared.begin(axis, value: draftValue)
                            }
                            let progress = min(1, max(0, (gesture.location.x - thumbSize / 2) / usableWidth))
                            let raw = CGFloat(range.lowerBound) + progress * CGFloat(range.upperBound - range.lowerBound)
                            let newValue = Int(raw.rounded())
                            if draftValue != newValue {
                                draftValue = newValue
                                NotchTuningPreviewState.shared.update(newValue)
                                performSelectionHaptic()
                            }
                        }
                        .onEnded { _ in
                            finishDragging()
                        }
                )
            }
            .frame(height: 40)
            .accessibilityLabel(title)
            .accessibilityValue(valueLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: value) { _, newValue in
            if !isDragging { draftValue = newValue }
        }
        .onDisappear {
            finishDragging()
        }
    }

    private func finishDragging() {
        guard isDragging else { return }
        isDragging = false
        let selectedValue = draftValue
        NotchTuningPreviewState.shared.end {
            value = selectedValue
        }
    }

    private var valueLabel: String {
        draftValue > 0 ? "+\(draftValue)" : "\(draftValue)"
    }

    private func performSelectionHaptic() {
        if Defaults[.enableHaptics] {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }
}

