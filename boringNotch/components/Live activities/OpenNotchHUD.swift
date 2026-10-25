//
//  OpenNotchHUD.swift
//  boringNotch
//
//  Created by Alexander on 2024-11-23.
//

import SwiftUI
import Defaults

struct OpenNotchHUD: View {
    @EnvironmentObject var vm: BoringViewModel
    @Binding var type: SneakContentType
    @Binding var value: CGFloat
    @Binding var icon: String
    @Default(.showOpenNotchHUDPercentage) var showPercentage
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Group {
                switch type {
                case .volume:
                    if icon.isEmpty {
                        Image(systemName: SpeakerSymbol(value))
                            .contentTransition(.interpolate)
                    } else {
                        Image(systemName: icon)
                            .contentTransition(.interpolate)
                    }
                case .brightness:
                    Image(systemName: "sun.max.fill")
                        .contentTransition(.symbolEffect)
                case .backlight:
                    Image(systemName: value > 0.5 ? "light.max" : "light.min")
                        .contentTransition(.interpolate)
                case .mic:
                    ZStack {
                        Capsule()
                            .fill(value.isZero ? Color.red : Color.green)
                            .frame(width: 26, height: 18)
                        Image(systemName: value.isZero ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .contentTransition(.interpolate)
                case .micActivity:
                    ZStack {
                        if value > 0 {
                            Capsule()
                                .fill(Color.orange)
                                .frame(width: 26, height: 18)
                            Image(systemName: "mic.fill")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "mic.slash.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .contentTransition(.interpolate)
                case .camera:
                    ZStack {
                        if value > 0 {
                            Capsule()
                                .fill(Color.green)
                                .frame(width: 26, height: 18)
                            Image(systemName: "video.fill")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "video.slash.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .contentTransition(.interpolate)
                case .screenRecord:
                    ZStack {
                        if value > 0 {
                            Capsule()
                                .fill(Color.red)
                                .frame(width: 26, height: 18)
                            Image(systemName: "record.circle.fill")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "record.circle")
                                .foregroundColor(.gray)
                        }
                    }
                    .contentTransition(.interpolate)
                case .capsLock:
                    ZStack {
                        if value > 0 {
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: 26, height: 18)
                            Image(systemName: "capslock.fill")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "capslock")
                                .foregroundColor(.gray)
                        }
                    }
                    .contentTransition(.interpolate)
                case .location:
                    ZStack {
                        if value > 0 {
                            Capsule()
                                .fill(Color.blue)
                                .frame(width: 26, height: 18)
                            Image(systemName: "location.fill")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "location.slash.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .contentTransition(.interpolate)
                case .airPods:
                    Image(systemName: "airpodspro")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                default:
                    EmptyView()
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 20, alignment: .center)
            
            // Slider or Status Text
            if type == .mic {
                Text(value > 0 ? "Unmuted" : "Muted")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(value > 0 ? .white : .red)
                    .fixedSize()
            } else if type == .micActivity {
                Text(value > 0 ? "Mic In Use" : "Mic Off")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(value > 0 ? .orange : .gray)
                    .fixedSize()
            } else if type == .camera {
                Text(value > 0 ? "Camera On" : "Camera Off")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(value > 0 ? .green : .gray)
                    .fixedSize()
            } else if type == .screenRecord {
                Text(value > 0 ? "Recording Screen" : "Recording Stopped")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(value > 0 ? .red : .gray)
                    .fixedSize()
            } else if type == .capsLock {
                Text(value > 0 ? "Caps Lock On" : "Caps Lock Off")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(value > 0 ? .white : .gray)
                    .fixedSize()
            } else if type == .location {
                Text(value > 0 ? "Location In Use" : "Location Off")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(value > 0 ? .blue : .gray)
                    .fixedSize()
            } else if type == .airPods {
                Text("\(icon.isEmpty ? "AirPods Pro" : icon) Connected (\(Int(value))%)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .fixedSize()
            } else {
                DraggableProgressBar(value: $value, onChange: { newVal in
                     updateSystemValue(newVal)
                })
                .frame(width: showPercentage ? 65 : 108) // Fixed width for consistency
            }
            
            // Percentage Text
            if type != .mic && type != .micActivity && type != .camera && type != .screenRecord && type != .capsLock && type != .location && type != .airPods && showPercentage {
                Text("\(Int(value * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.gray)
                    .monospacedDigit()
                    .frame(width: 35, alignment: .trailing)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    func SpeakerSymbol(_ value: CGFloat) -> String {
        switch(value) {
            case 0: return "speaker.slash"
            case 0...0.33: return "speaker.wave.1"
            case 0.33...0.66: return "speaker.wave.2"
            default: return "speaker.wave.3"
        }
    }
    
    func updateSystemValue(_ newVal: CGFloat) {
        switch type {
        case .volume:
            VolumeManager.shared.setAbsolute(Float32(newVal))
        case .brightness:
            BrightnessManager.shared.setAbsolute(value: Float32(newVal))
        default:
            break
        }
    }
}

#Preview {
    OpenNotchHUD(type: .constant(.volume), value: .constant(0.5), icon: .constant(""))
        .environmentObject(BoringViewModel())
        .padding()
        .background(Color.gray)
}
