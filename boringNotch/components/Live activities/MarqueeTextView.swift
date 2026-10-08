//
//  MarqueeTextView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 08/08/2024.
//

import SwiftUI

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct MeasureSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(GeometryReader { geometry in
            Color.clear.preference(key: SizePreferenceKey.self, value: geometry.size)
        })
    }
}

struct MarqueeText: View {
    @Binding var text: String
    var font: Font = .body
    var nsFont: NSFont.TextStyle = .body
    var textColor: Color = .primary
    var backgroundColor: Color = .clear
    var minDuration: Double = 3.0
    var frameWidth: CGFloat = 200
    var alignment: Alignment = .center
    
    @State private var animate = false
    @State private var textSize: CGSize = .zero
    @State private var offset: CGFloat = 0
    
    init(
        _ text: Binding<String>,
        font: Font = .body,
        nsFont: NSFont.TextStyle = .body,
        textColor: Color = .primary,
        backgroundColor: Color = .clear,
        minDuration: Double = 3.0,
        frameWidth: CGFloat = 200,
        alignment: Alignment = .center
    ) {
        _text = text
        self.font = font
        self.nsFont = nsFont
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.minDuration = minDuration
        self.frameWidth = frameWidth
        self.alignment = alignment
    }
    
    private var needsScrolling: Bool {
        textSize.width > frameWidth
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: needsScrolling ? .leading : alignment) {
                if needsScrolling {
                    HStack(spacing: 24) {
                        Text(text)
                        Text(text)
                    }
                    .id(text)
                    .font(font)
                    .foregroundColor(textColor)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: self.animate ? offset : 0)
                    .animation(
                        self.animate ?
                            .linear(duration: Double(max(1, textSize.width) / 28))
                            .delay(minDuration)
                            .repeatForever(autoreverses: false) : .none,
                        value: self.animate
                    )
                } else {
                    Text(text)
                        .id(text)
                        .font(font)
                        .foregroundColor(textColor)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: alignment)
                }
            }
            .background(
                Text(text)
                    .font(font)
                    .fixedSize(horizontal: true, vertical: false)
                    .hidden()
                    .modifier(MeasureSizeModifier())
            )
            .onPreferenceChange(SizePreferenceKey.self) { size in
                self.textSize = CGSize(width: size.width, height: NSFont.preferredFont(forTextStyle: nsFont).pointSize)
                self.animate = false
                self.offset = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    if size.width > frameWidth {
                        self.animate = true
                        self.offset = -(size.width + 24)
                    }
                }
            }
            .frame(width: frameWidth, alignment: needsScrolling ? .leading : alignment)
            .clipped()
        }
        .frame(height: max(14, textSize.height * 1.3))
    }
}
