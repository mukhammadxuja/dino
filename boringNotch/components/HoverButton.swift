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
    var action: () -> Void
    var contentTransition: ContentTransition = .symbolEffect;
    
    @State private var isHovering = false

    init(
        icon: String,
        iconColor: Color = .primary,
        scale: Image.Scale = .medium,
        cornerRadius: CGFloat? = nil,
        contentTransition: ContentTransition = .symbolEffect,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.scale = scale
        self.cornerRadius = cornerRadius
        self.action = action
        self.contentTransition = contentTransition
    }

    var body: some View {
        let size = CGFloat(scale == .large ? 40 : 30)
        
        Button(action: action) {
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .frame(width: size, height: size)
                .overlay {
                    ZStack {
                        if let cornerRadius {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(isHovering ? Color.gray.opacity(0.2) : .clear)
                        } else {
                            Capsule()
                                .fill(isHovering ? Color.gray.opacity(0.2) : .clear)
                        }

                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                            .contentTransition(contentTransition)
                            .font(scale == .large ? .largeTitle : .body)
                    }
                    .frame(width: size, height: size)
                }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.3)) {
                isHovering = hovering
            }
        }
    }
}
