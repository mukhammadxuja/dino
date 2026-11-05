import SwiftUI

// MARK: - Custom Stepped Hover Delay Slider
struct HoverDelaySlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hare.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            GeometryReader { geo in
                let width = geo.size.width
                let clamped = min(max(value, range.lowerBound), range.upperBound)
                let pct = CGFloat((clamped - range.lowerBound) / (range.upperBound - range.lowerBound))
                let knobX = pct * max(1, width - 16)

                ZStack(alignment: .leading) {
                    // Base background track
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: 4)

                    // Active filled track
                    Capsule()
                        .fill(Color.effectiveAccent)
                        .frame(width: max(0, knobX + 8), height: 4)

                    // Tick dots
                    HStack {
                        ForEach(0..<4, id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 3.5, height: 3.5)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 6)

                    // Draggable White Knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: Color.black.opacity(0.2), radius: 2.5, y: 1)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                        )
                        .offset(x: knobX)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let fraction = max(0, min(1, gesture.location.x / width))
                            let raw = range.lowerBound + Double(fraction) * (range.upperBound - range.lowerBound)
                            let stepped = (raw / step).rounded() * step
                            value = min(max(stepped, range.lowerBound), range.upperBound)
                        }
                )
            }
            .frame(width: 130, height: 20)

            Image(systemName: "tortoise.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Text(String(format: "%.1fs", value).replacingOccurrences(of: ".", with: ","))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

