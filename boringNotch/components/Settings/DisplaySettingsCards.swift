//
//  DisplaySettingsCards.swift
//  boringNotch
//

import SwiftUI
import Defaults

// MARK: - Compact radio card shared by Appearance, Media and Lock Screen
struct CompactSelectionCard<T: Equatable, Content: View>: View {
    let value: T
    @Binding var selection: T
    let content: () -> Content

    @State private var isHovered = false

    var isSelected: Bool {
        selection == value
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                selection = value
            }
        } label: {
            content()
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

// MARK: - 1. Displays Top Selector Card (Built-in, External, Both)
struct DisplaySelectionCard: View {
    let type: DisplaySelection
    @Binding var selection: DisplaySelection

    var isSelected: Bool {
        selection == type
    }

    var body: some View {
        CompactSelectionCard(value: type, selection: $selection) {
            HStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? Color.effectiveAccent : .secondary)

                Text(type.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - 2. Form Factor Card (Notch vs Island)
struct FormFactorCard: View {
    let factor: DisplayFormFactor
    @Binding var selection: DisplayFormFactor

    var isSelected: Bool {
        selection == factor
    }

    var body: some View {
        CompactSelectionCard(value: factor, selection: $selection) {
            HStack(spacing: 8) {
                // Visual Mini Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 32, height: 20)

                    if factor == .notch {
                        // Attached top notch shape
                        VStack(spacing: 0) {
                            NotchCutoutShape()
                                .fill(Color.black)
                                .frame(width: 22, height: 9)
                            Spacer(minLength: 0)
                        }
                        .frame(width: 32, height: 20)
                    } else {
                        // Floating Island capsule
                        Capsule()
                            .fill(Color.black)
                            .frame(width: 22, height: 9)
                    }
                }
                .shadow(color: Color.black.opacity(0.15), radius: 2, y: 1)

                Text(factor.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
    }
}

// MARK: - 3. Island Visual Style Card (Dark vs Glass)
struct IslandStyleCard: View {
    let style: IslandStyle
    @Binding var selection: IslandStyle

    var isSelected: Bool {
        selection == style
    }

    var body: some View {
        CompactSelectionCard(value: style, selection: $selection) {
            HStack(spacing: 8) {
                // Visual Mini Pill
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                        .frame(width: 32, height: 20)

                    if style == .dark {
                        Capsule()
                            .fill(Color.black)
                            .frame(width: 24, height: 10)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                            )
                    } else {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.7), Color.gray.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 10)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                            )
                    }
                }
                .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)

                Text(style.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
    }
}

// MARK: - 4. Island Visibility Card (On Hover vs On Click vs Always Visible)
struct IslandVisibilityCard: View {
    let visibility: IslandVisibility
    @Binding var selection: IslandVisibility

    var isSelected: Bool {
        selection == visibility
    }

    var body: some View {
        CompactSelectionCard(value: visibility, selection: $selection) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? Color.effectiveAccent : .secondary)
                Text(visibility.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var iconName: String {
        switch visibility {
        case .onHover: return "cursorarrow.rays"
        case .onClick: return "hand.tap.fill"
        case .alwaysVisible: return "eye.fill"
        }
    }
}

// MARK: - 5. Show On Target Card (Automatic, All Displays, Follow Pointer)
struct DisplayShowOnCard: View {
    let target: DisplayShowOn
    @Binding var selection: DisplayShowOn

    var isSelected: Bool {
        selection == target
    }

    var body: some View {
        CompactSelectionCard(value: target, selection: $selection) {
            HStack(spacing: 8) {
                Image(systemName: target.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? Color.effectiveAccent : .secondary)

                Text(target.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }
}

// MARK: - Custom Shape for Notch Cutout Icon
struct NotchCutoutShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - 4))
        path.addQuadCurve(
            to: CGPoint(x: rect.width - 4, y: rect.height),
            control: CGPoint(x: rect.width, y: rect.height)
        )
        path.addLine(to: CGPoint(x: 4, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.height - 4),
            control: CGPoint(x: 0, y: rect.height)
        )
        path.closeSubpath()
        return path
    }
}
