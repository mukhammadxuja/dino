//
//  MirrorSlotView.swift
//  boringNotch
//
//  Created for Dino Architecture Evolution.
//

import AVFoundation
import AppKit
import SwiftUI

public struct MirrorSlotView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var webcamManager = WebcamManager.shared
    let isCurrentDisplayIsland: Bool

    @State private var isHovered: Bool = false
    @State private var isCameraReadyToStart: Bool = false
    @State private var startCameraTask: Task<Void, Never>? = nil

    public init(isCurrentDisplayIsland: Bool = true) {
        self.isCurrentDisplayIsland = isCurrentDisplayIsland
    }

    private var cameraSide: CGFloat {
        let size = vm.mirrorSlotCardSize(isIsland: isCurrentDisplayIsland)
        let hPadding: CGFloat = isCurrentDisplayIsland ? 12 : (10 + 14)
        return size.width - (2 * hPadding)
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // Camera Viewport (Guaranteed 1:1 Square, mirrored)
            cameraViewport
                .frame(width: cameraSide, height: cameraSide)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            // Hover close button
            if isHovered {
                Button {
                    withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.78)) {
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            for vm in appDelegate.viewModels.values {
                                vm.close()
                            }
                        } else {
                            BoringViewModel.shared.close()
                        }
                        DinoCoordinator.shared.dismissOnDemand()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .background(Color.black.opacity(0.35).clipShape(Circle()))
                }
                .buttonStyle(.plain)
                .padding(8)
                .transition(.opacity)
            }
        }
        .frame(width: cameraSide, height: cameraSide, alignment: .top)
        .onHover { isHovered = $0 }
        .onAppear {
            startCameraTask?.cancel()
            startCameraTask = Task { @MainActor in
                // Allow the notch/island spring opening animation to settle completely first
                try? await Task.sleep(nanoseconds: 380_000_000)
                guard !Task.isCancelled else { return }
                isCameraReadyToStart = true
                webcamManager.startSession()
            }
        }
        .onDisappear {
            startCameraTask?.cancel()
            startCameraTask = nil
            isCameraReadyToStart = false
            webcamManager.stopSession()
        }
    }

    // MARK: - Camera Viewport

    private var cameraViewport: some View {
        ZStack {
            if isCameraReadyToStart && webcamManager.isSessionRunning {
                MirrorCameraPreviewView(webcamManager: webcamManager)
                    .scaleEffect(x: -1.0, y: 1.0) // Mirrored reflection by default
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .transition(.opacity)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))

                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)

                        Text("Starting camera...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isCameraReadyToStart && webcamManager.isSessionRunning)
    }
}

// MARK: - Multi-Window Independent Camera Preview Layer

struct MirrorCameraPreviewView: NSViewRepresentable {
    @ObservedObject var webcamManager: WebcamManager

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        if let layer = webcamManager.createPreviewLayer() {
            layer.frame = view.bounds
            view.layer = layer
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let layer = nsView.layer as? AVCaptureVideoPreviewLayer {
            layer.frame = nsView.bounds
            if layer.session == nil, let session = webcamManager.captureSession {
                layer.session = session
            }
        } else if let layer = webcamManager.createPreviewLayer() {
            layer.frame = nsView.bounds
            nsView.layer = layer
        }
        CATransaction.commit()
    }
}
