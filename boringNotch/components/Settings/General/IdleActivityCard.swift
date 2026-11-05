import SwiftUI

// MARK: - Idle Activity Radio Selection Card
struct IdleActivityCard: View {
    let action: IdleClickAction
    @Binding var selection: IdleClickAction
    @State private var isHovered = false

    private var label: String {
        switch action {
        case .none: return "None"
        case .music: return "Playing"
        case .pomodoro: return "Timer"
        case .weather: return "Weather"
        case .calendar: return "Calendar"
        case .shelf: return "Shelf"
        }
    }

    private var icon: String {
        switch action {
        case .none: return "circle.slash"
        case .music: return "waveform"
        case .pomodoro: return "timer"
        case .weather: return "cloud.sun.fill"
        case .calendar: return "calendar"
        case .shelf: return "tray.full.fill"
        }
    }

    var body: some View {
        let isSelected = selection == action
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selection = action
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? .effectiveAccent : (isHovered ? .primary : .secondary))
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.effectiveAccent.opacity(0.12) :
                          (isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.effectiveAccent : Color.primary.opacity(0.08),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { isHovered = $0 }
    }
}

