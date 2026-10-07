//
//  HoverButton.swift
//  boringNotch
//
//  Created by Kraigo on 04.09.2024.
//

import SwiftUI

struct HoverButton: View {
    var icon: String
    var iconColor: Color = .primary
    var scale: Image.Scale = .medium
    var cornerRadius: CGFloat? = nil
    var customFont: Font? = nil
    var customSize: CGFloat? = nil
    var action: () -> Void
    var contentTransition: ContentTransition = .symbolEffect
    
    @State private var isHovering = false

    init(
        icon: String,
        iconColor: Color = .primary,
        scale: Image.Scale = .medium,
        cornerRadius: CGFloat? = nil,
        customFont: Font? = nil,
        customSize: CGFloat? = nil,
        contentTransition: ContentTransition = .symbolEffect,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.scale = scale
        self.cornerRadius = cornerRadius
        self.customFont = customFont
        self.customSize = customSize
        self.action = action
        self.contentTransition = contentTransition
    }

    var body: some View {
        let size = customSize ?? CGFloat(scale == .large ? 42 : 32)
        
        Button(action: action) {
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .frame(width: size, height: size)
                .overlay {
                    ZStack {
                        if let cornerRadius {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(isHovering ? Color.white.opacity(0.14) : .clear)
                        } else {
                            Capsule()
                                .fill(isHovering ? Color.white.opacity(0.14) : .clear)
                        }

                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                            .contentTransition(contentTransition)
                            .font(customFont ?? (scale == .large ? .system(size: 24, weight: .bold) : .system(size: 18, weight: .bold)))
                    }
                    .frame(width: size, height: size)
                }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}
