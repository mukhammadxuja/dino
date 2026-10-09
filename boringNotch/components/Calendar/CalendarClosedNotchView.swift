//
//  CalendarClosedNotchView.swift
//  Dino
//

import Defaults
import SwiftUI

public struct CalendarClosedNotchView: View {
    @EnvironmentObject private var vm: BoringViewModel
    var isCurrentDisplayIsland: Bool
    var isCurrentScreenBuiltin: Bool

    public init(
        isCurrentDisplayIsland: Bool,
        isCurrentScreenBuiltin: Bool
    ) {
        self.isCurrentDisplayIsland = isCurrentDisplayIsland
        self.isCurrentScreenBuiltin = isCurrentScreenBuiltin
    }

    public var body: some View {
        let itemSize = max(0, vm.effectiveClosedNotchHeight - (isCurrentDisplayIsland ? 10 : 12))
        let centerSpacerWidth: CGFloat = isCurrentDisplayIsland
            ? (isCurrentScreenBuiltin ? 76 : 50)
            : (vm.closedNotchSize.width + 14)

        HStack(spacing: 0) {
            Image(systemName: "calendar")
                .font(.system(size: isCurrentScreenBuiltin ? 14 : 13, weight: .semibold))
                .foregroundStyle(Color.effectiveAccent)
                .frame(width: itemSize, height: itemSize)

            Rectangle()
                .fill(Color.clear)
                .frame(
                    width: centerSpacerWidth,
                    height: vm.effectiveClosedNotchHeight
                )

            Text("\(Calendar.current.component(.day, from: Date()))")
                .font(.system(size: isCurrentScreenBuiltin ? 14 : 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.effectiveAccent)
                .frame(width: itemSize, height: itemSize)
        }
        .contentShape(Rectangle())
        .frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
    }
}
