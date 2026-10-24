//
//  InlineHUDs.swift
//  boringNotch
//
//  Created by Richard Kunkli on 14/09/2024.
//

import SwiftUI
import Defaults

struct InlineHUD: View {
    @EnvironmentObject var vm: BoringViewModel
    @Binding var type: SneakContentType
    @Binding var value: CGFloat
    @Binding var icon: String
    @Binding var hoverAnimation: Bool
    @Binding var gestureProgress: CGFloat
    private var isExternalScreen: Bool {
        if let uuid = vm.screenUUID, let screen = NSScreen.screen(withUUID: uuid) {
            return !screen.isBuiltin
        }
        return !(NSScreen.main?.isBuiltin ?? true)
    }

    @ViewBuilder
    private var leftIconView: some View {
        HStack(spacing: 5) {
            Group {
                switch (type) {
                    case .volume:
                        if icon.isEmpty {
                            Image(systemName: SpeakerSymbol(value))
                                .contentTransition(.interpolate)
                                .symbolVariant(value > 0 ? .none : .slash)
                                .frame(width: 20, height: 15, alignment: .leading)
                        } else {
                            Image(systemName: icon)
                                .contentTransition(.interpolate)
                                .opacity(value.isZero ? 0.6 : 1)
                                .scaleEffect(value.isZero ? 0.85 : 1)
                                .frame(width: 20, height: 15, alignment: .leading)
                        }
                    case .brightness:
                        Image(systemName: BrightnessSymbol(value))
                            .contentTransition(.interpolate)
                            .frame(width: 20, height: 15, alignment: .center)
                    case .backlight:
                        Image(systemName: value > 0.5 ? "light.max" : "light.min")
                            .contentTransition(.interpolate)
                            .frame(width: 20, height: 15, alignment: .center)
                    case .mic:
                        ZStack {
                            Capsule()
                                .fill(value.isZero ? Color.red : Color.green)
                                .frame(width: 24, height: 16)
                            Image(systemName: value.isZero ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                        .contentTransition(.interpolate)
                        .frame(width: 24, height: 16, alignment: .center)
                    case .micActivity:
                        ZStack {
                            if value > 0 {
                                Capsule()
                                    .fill(Color.orange)
                                    .frame(width: 24, height: 16)
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(Color.white)
                            } else {
                                Image(systemName: "mic.slash.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.gray)
                            }
                        }
                        .contentTransition(.interpolate)
                        .frame(width: 24, height: 16, alignment: .center)
                    case .camera:
                        ZStack {
                            if value > 0 {
                                Capsule()
                                    .fill(Color.green)
                                    .frame(width: 24, height: 16)
                                Image(systemName: "video.fill")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(Color.white)
                            } else {
                                Image(systemName: "video.slash.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.gray)
                            }
                        }
                        .contentTransition(.interpolate)
                        .frame(width: 24, height: 16, alignment: .center)
                    case .screenRecord:
                        ZStack {
                            if value > 0 {
                                Capsule()
                                    .fill(Color.red)
                                    .frame(width: 24, height: 16)
                                Image(systemName: "record.circle.fill")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(Color.white)
                            } else {
                                Image(systemName: "record.circle")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.gray)
                            }
                        }
                        .contentTransition(.interpolate)
                        .frame(width: 24, height: 16, alignment: .center)
                    default:
                        EmptyView()
                }
            }
            .foregroundStyle(.white)
            .symbolVariant(.fill)
            
            if type != .mic && type != .micActivity && type != .camera && type != .screenRecord {
                Text(Type2Name(type))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .contentTransition(.numericText())
            }
        }
    }

    @ViewBuilder
    private var rightStatusView: some View {
        HStack {
            if (type == .mic) {
                Text(value.isZero ? "muted" : "unmuted")
                    .foregroundStyle(value.isZero ? Color.red.opacity(0.85) : Color.white)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: isExternalScreen ? nil : .infinity, alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .micActivity) {
                Text(value > 0 ? "Mic On" : "Mic Off")
                    .foregroundStyle(value > 0 ? Color.orange : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: isExternalScreen ? nil : .infinity, alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .camera) {
                Text(value > 0 ? "Camera On" : "Camera Off")
                    .foregroundStyle(value > 0 ? Color.green : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: isExternalScreen ? nil : .infinity, alignment: .trailing)
                    .contentTransition(.interpolate)
            } else if (type == .screenRecord) {
                Text(value > 0 ? "Recording" : "Stopped")
                    .foregroundStyle(value > 0 ? Color.red : Color.gray)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: isExternalScreen ? nil : .infinity, alignment: .trailing)
                    .contentTransition(.interpolate)
            } else {
                HStack(spacing: 4) {
                    DraggableProgressBar(value: $value, onChange: { v in
                        if type == .volume {
                            VolumeManager.shared.setAbsolute(Float32(v))
                        } else if type == .brightness {
                            BrightnessManager.shared.setAbsolute(value: Float32(v))
                        }
                    })
                    .frame(width: isExternalScreen ? 55 : nil)
                    if (type == .volume && value.isZero) {
                        Text("muted")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                            .allowsTightening(true)
                            .multilineTextAlignment(.trailing)
                    } else if Defaults[.showClosedNotchHUDPercentage] {
                        Text("\(Int(value * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                            .allowsTightening(true)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }

    var body: some View {
        if isExternalScreen {
            HStack(spacing: 0) {
                leftIconView
                Spacer()
                rightStatusView
            }
            .padding(.horizontal, 4)
            .frame(width: 150, height: vm.closedNotchSize.height + (hoverAnimation ? 8 : 0), alignment: .center)
        } else {
            HStack {
                leftIconView
                    .frame(width: 100 - (hoverAnimation ? 0 : 12) + gestureProgress / 2, height: vm.notchSize.height - (hoverAnimation ? 0 : 12), alignment: .leading)
                
                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width - 20)
                
                rightStatusView
                    .padding(.trailing, 4)
                    .frame(width: 100 - (hoverAnimation ? 0 : 12) + gestureProgress / 2, height: vm.closedNotchSize.height - (hoverAnimation ? 0 : 12), alignment: .center)
            }
            .frame(height: vm.closedNotchSize.height + (hoverAnimation ? 8 : 0), alignment: .center)
        }
    }
    
    func SpeakerSymbol(_ value: CGFloat) -> String {
        switch(value) {
            case 0:
                return "speaker"
            case 0...0.3:
                return "speaker.wave.1"
            case 0.3...0.8:
                return "speaker.wave.2"
            case 0.8...1:
                return "speaker.wave.3"
            default:
                return "speaker.wave.2"
        }
    }
    
    func BrightnessSymbol(_ value: CGFloat) -> String {
        switch(value) {
            case 0...0.6:
                return "sun.min"
            case 0.6...1:
                return "sun.max"
            default:
                return "sun.min"
        }
    }
    
    func Type2Name(_ type: SneakContentType) -> String {
        switch(type) {
            case .volume:
                return "Volume"
            case .brightness:
                return "Brightness"
            case .backlight:
                return "Backlight"
            case .mic:
                return "Mic"
            default:
                return ""
        }
    }
}

#Preview {
    InlineHUD(type: .constant(.brightness), value: .constant(0.4), icon: .constant(""), hoverAnimation: .constant(false), gestureProgress: .constant(0))
        .padding(.horizontal, 8)
        .background(Color.black)
        .padding()
        .environmentObject(BoringViewModel())
}
