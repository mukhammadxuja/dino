import SwiftUI

struct KbdKeyView: View {
    let key: String
    @Environment(\.colorScheme) var colorScheme
    
    private var isDark: Bool {
        colorScheme == .dark
    }
    
    var body: some View {
        Text(key)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundStyle(isDark ? Color.white.opacity(0.9) : Color.black.opacity(0.85))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isDark ? Color(white: 0.22) : Color(white: 0.94))
                    .shadow(color: Color.black.opacity(isDark ? 0.4 : 0.08), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.12), lineWidth: 0.8)
            )
    }
}

struct KbdShortcutBadge: View {
    var keys: [String] = ["⌃", "⇧", "A"]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                KbdKeyView(key: key)
            }
        }
    }
}
