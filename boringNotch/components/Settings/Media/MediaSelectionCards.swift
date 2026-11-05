import Defaults
import SwiftUI

// MARK: - Media Source Radio Selection Card
struct MediaSourceCard: View {
    let source: MediaControllerType
    @Binding var selection: MediaControllerType
    @State private var isHovered = false

    var isSelected: Bool {
        selection == source
    }

    private var iconName: String {
        switch source {
        case .nowPlaying:
            return "waveform"
        case .appleMusic:
            return "apple.logo"
        case .spotify:
            return "dot.radiowaves.left.and.right"
        case .youtubeMusic:
            return "play.rectangle.fill"
        }
    }

    private var iconColor: Color {
        switch source {
        case .nowPlaying:
            return .purple
        case .appleMusic:
            return .pink
        case .spotify:
            return Color(red: 0.11, green: 0.84, blue: 0.38)
        case .youtubeMusic:
            return .red
        }
    }

    var body: some View {
        Button {
            guard selection != source else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selection = source
                NotificationCenter.default.post(
                    name: Notification.Name.mediaControllerChanged,
                    object: nil
                )
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? iconColor : (isHovered ? .primary : .secondary))

                Text(source.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.effectiveAccent.opacity(0.12)
                            : (isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? Color.effectiveAccent : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hov in
            isHovered = hov
        }
    }
}

// MARK: - Sneak Peek Style Radio Selection Card
struct SneakPeekStyleCard: View {
    let style: SneakPeekStyle
    @Binding var selection: SneakPeekStyle

    var isSelected: Bool {
        selection == style
    }

    private var iconName: String {
        switch style {
        case .standard:
            return "rectangle.topthird.inset.filled"
        case .inline:
            return "text.line.first.and.arrowtriangle.forward"
        }
    }

    private var description: String {
        switch style {
        case .standard:
            return "Rich card popup"
        case .inline:
            return "Compact banner"
        }
    }

    var body: some View {
        CompactSelectionCard(value: style, selection: $selection) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? Color.effectiveAccent : .secondary)

                Text(style.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .help(description)
    }
}
