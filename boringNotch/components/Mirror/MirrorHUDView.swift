//
//  MirrorHUDView.swift
//  boringNotch
//
//  Created for Dino Architecture Evolution.
//

import AVFoundation
import AppKit
import Defaults
import SwiftUI

public struct MirrorHUDView: View {
    @ObservedObject private var manager = MirrorManager.shared
    @State private var isAppeared: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Background & Camera Feed
            cameraViewport

            // Soft Ring Light Effect (FaceTime ambient glow)
            if manager.isRingLightActive {
                ringLightOverlay
            }

            // Top Header Bar
            VStack {
                headerBar
                Spacer()
                // Bottom Glassmorphic Control Bar
                controlsBar
            }

            // Toast feedback when snapshot is captured
            if manager.showSnapshotToast {
                snapshotToastView
            }
        }
        .frame(width: 290, height: 320)
        // Deep OLED Black matching notch aesthetic
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(manager.isRingLightActive ? 0.35 : 0.12), lineWidth: 1)
        )
        // Spring animation emerging directly out from the physical Notch
        .scaleEffect(isAppeared ? 1.0 : 0.88, anchor: .top)
        .offset(y: isAppeared ? 0 : -28)
        .opacity(isAppeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78, blendDuration: 0)) {
                isAppeared = true
            }
        }
        .onDisappear {
            isAppeared = false
        }
    }

    // MARK: - Camera Viewport

    @ViewBuilder
    private var cameraViewport: some View {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            permissionDeniedView
        } else if let layer = manager.previewLayer, manager.isSessionRunning {
            MirrorCameraPreviewLayer(previewLayer: layer)
                .scaleEffect(x: manager.isFlipped ? -manager.zoomLevel : manager.zoomLevel, y: manager.zoomLevel)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: manager.zoomLevel)
                .animation(.smooth(duration: 0.22), value: manager.isFlipped)
        } else {
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.9)
                Text("Connecting camera...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Soft Ring Light Overlay

    private var ringLightOverlay: some View {
        ZStack {
            // Diffused outer glow
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(red: 1.0, green: 0.98, blue: 0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 14
                )
                .blur(radius: 12)
                .opacity(0.85)

            // Inner illumination stroke
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.70), lineWidth: 4)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "video.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))

                Text("Mirror")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(Color.black.opacity(0.45))
            .clipShape(Capsule())

            Spacer()

            Button {
                MirrorPanelController.shared.hide()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    // MARK: - Floating Control Bar

    private var controlsBar: some View {
        HStack(spacing: 6) {
            // Ring Light Toggle
            MirrorControlButton(
                icon: manager.isRingLightActive ? "lightbulb.fill" : "lightbulb",
                title: "Ring Light",
                isActive: manager.isRingLightActive
            ) {
                withAnimation(.smooth(duration: 0.2)) {
                    manager.isRingLightActive.toggle()
                }
            }

            // Zoom 1x / 2x Toggle
            MirrorControlButton(
                icon: manager.zoomLevel > 1.0 ? "plus.magnifyingglass" : "magnifyingglass",
                title: manager.zoomLevel > 1.0 ? "2x" : "1x",
                isActive: manager.zoomLevel > 1.0
            ) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    manager.zoomLevel = (manager.zoomLevel > 1.0) ? 1.0 : 2.0
                }
            }

            // Flip / Mirror Toggle
            MirrorControlButton(
                icon: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill",
                title: manager.isFlipped ? "Mirror" : "Normal",
                isActive: manager.isFlipped
            ) {
                withAnimation(.smooth(duration: 0.22)) {
                    manager.isFlipped.toggle()
                }
            }

            Spacer(minLength: 0)

            // Quick Snapshot Button
            Button {
                manager.captureSnapshot()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                    Text("Copy")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Take photo & copy to clipboard")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    // MARK: - Snapshot Feedback Toast

    private var snapshotToastView: some View {
        VStack {
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text("Copied to clipboard!")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5.5)
            .background(Color.black.opacity(0.85))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
            .padding(.bottom, 55)
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color.white.opacity(0.40))

            Text("Camera Access Required")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.white)

            Text("Please allow camera permission in System Settings to use Mirror.")
                .font(.system(size: 10.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.horizontal, 20)

            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mirror Control Button

private struct MirrorControlButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9.5))
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
            }
            .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.65))
            .padding(.horizontal, 6.5)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.25) : (isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06)))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Mirror Camera Preview Layer (NSViewRepresentable)

private struct MirrorCameraPreviewLayer: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        previewLayer.videoGravity = .resizeAspectFill
        view.layer?.addSublayer(previewLayer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = nsView.bounds
        CATransaction.commit()
    }
}
