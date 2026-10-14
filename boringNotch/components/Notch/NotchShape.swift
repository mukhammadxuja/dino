//
//  NotchShape.swift
//  boringNotch
//
// Created by Kai Azim on 2023-08-24.
// Original source: https://github.com/MrKai77/DynamicNotchKit
// Modified by Alexander on 2025-05-18.

import SwiftUI

struct NotchShape: Shape {
    private var topCornerRadius: CGFloat
    private var bottomCornerRadius: CGFloat

    init(
        topCornerRadius: CGFloat? = nil,
        bottomCornerRadius: CGFloat? = nil
    ) {
        self.topCornerRadius = topCornerRadius ?? 6
        self.bottomCornerRadius = bottomCornerRadius ?? 14
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get {
            .init(
                topCornerRadius,
                bottomCornerRadius
            )
        }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        guard rect.width > 0 && rect.height > 0 else { return path }

        var tRadius = max(0, topCornerRadius)
        var bRadius = max(0, bottomCornerRadius)

        // Ensure vertical curves fit within available height so vertical lines never invert/self-intersect
        let sumRadii = tRadius + bRadius
        if sumRadii > rect.height && sumRadii > 0 {
            let scale = rect.height / sumRadii
            tRadius *= scale
            bRadius *= scale
        }

        // Ensure horizontal corners fit within available width
        let totalWidthNeeded = (tRadius + bRadius) * 2
        if totalWidthNeeded > rect.width && totalWidthNeeded > 0 {
            let scale = rect.width / totalWidthNeeded
            tRadius *= scale
            bRadius *= scale
        }

        path.move(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX + tRadius,
                y: rect.minY + tRadius
            ),
            control: CGPoint(
                x: rect.minX + tRadius,
                y: rect.minY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.minX + tRadius,
                y: rect.maxY - bRadius
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX + tRadius + bRadius,
                y: rect.maxY
            ),
            control: CGPoint(
                x: rect.minX + tRadius,
                y: rect.maxY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX - tRadius - bRadius,
                y: rect.maxY
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.maxX - tRadius,
                y: rect.maxY - bRadius
            ),
            control: CGPoint(
                x: rect.maxX - tRadius,
                y: rect.maxY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX - tRadius,
                y: rect.minY + tRadius
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.maxX,
                y: rect.minY
            ),
            control: CGPoint(
                x: rect.maxX - tRadius,
                y: rect.minY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY
            )
        )

        return path
    }
}

#Preview {
    NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
        .frame(width: 200, height: 32)
        .padding(10)
}
