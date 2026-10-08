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
    var minDuration: Double = 1.5
    var frameWidth: CGFloat = 200
    var alignment: Alignment = .leading
    var fadeMaskWhenScrolling: Bool = false
    
    @State private var animate: Bool = false
    @State private var textWidth: CGFloat = 0
    @State private var restartTask: Task<Void, Never>?
    
    init(
        _ text: Binding<String>,
        font: Font = .body,
        nsFont: NSFont.TextStyle = .body,
        textColor: Color = .primary,
        backgroundColor: Color = .clear,
        minDuration: Double = 1.5,
        frameWidth: CGFloat = 200,
        alignment: Alignment = .leading,
        fadeMaskWhenScrolling: Bool = false
    ) {
        _text = text
        self.font = font
        self.nsFont = nsFont
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.minDuration = minDuration
        self.frameWidth = frameWidth
        self.alignment = alignment
        self.fadeMaskWhenScrolling = fadeMaskWhenScrolling
        
        let initialWidth = Self.measureWidth(text.wrappedValue, nsFont: nsFont)
        _textWidth = State(initialValue: initialWidth)
    }
    
    static func measureWidth(_ str: String, nsFont: NSFont.TextStyle) -> CGFloat {
        guard !str.isEmpty else { return 0 }
        let pointSize = NSFont.preferredFont(forTextStyle: nsFont).pointSize
        let font = NSFont.systemFont(ofSize: pointSize > 0 ? pointSize : 11, weight: .medium)
        let size = (str as NSString).size(withAttributes: [.font: font])
        return ceil(size.width)
    }
    
    private var needsScrolling: Bool {
        textWidth > frameWidth && textWidth > 0
    }
    
    private let spacing: CGFloat = 28
    
    var body: some View {
        let scrollDist = textWidth + spacing
        let scrollDuration = Double(max(1, textWidth) / 26)
        let effectiveAlignment: Alignment = needsScrolling ? .leading : alignment
        
        ZStack(alignment: effectiveAlignment) {
            HStack(spacing: spacing) {
                Text(text)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if needsScrolling {
                    Text(text)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .id(text)
            .font(font)
            .foregroundColor(textColor)
            .offset(x: (needsScrolling && animate) ? -scrollDist : 0)
            .animation(
                (needsScrolling && animate)
                    ? Animation.linear(duration: scrollDuration)
                        .delay(minDuration)
                        .repeatForever(autoreverses: false)
                    : nil,
                value: animate
            )
        }
        .frame(width: frameWidth, alignment: effectiveAlignment)
        .clipped()
        .conditionalModifier(fadeMaskWhenScrolling && needsScrolling) { content in
            content.mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.05),
                        .init(color: .black, location: 0.95),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .onChange(of: text) { _, newText in
            self.textWidth = Self.measureWidth(newText, nsFont: nsFont)
            triggerAnimation()
        }
        .onAppear {
            if textWidth == 0 {
                textWidth = Self.measureWidth(text, nsFont: nsFont)
            }
            triggerAnimation()
        }
        .onDisappear {
            restartTask?.cancel()
            animate = false
        }
    }
    
    private func triggerAnimation() {
        restartTask?.cancel()
        animate = false
        
        guard textWidth > frameWidth else { return }
        
        restartTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            self.animate = true
        }
    }
}
