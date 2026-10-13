//
//  MirrorManager.swift
//  boringNotch
//
//  Created for Dino Architecture Evolution.
//

import AVFoundation
import AppKit
import Combine
import Defaults
import SwiftUI

@MainActor
public final class MirrorManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    public static let shared = MirrorManager()

    @Published public var previewLayer: AVCaptureVideoPreviewLayer?
    @Published public var isSessionRunning: Bool = false
    @Published public var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published public var cameraAvailable: Bool = false
    @Published public var cameraName: String = "FaceTime HD Camera"

    // Visual controls
    @Published public var isRingLightActive: Bool = Defaults[.mirrorRingLight] {
        didSet { Defaults[.mirrorRingLight] = isRingLightActive }
    }
    @Published public var zoomLevel: CGFloat = Defaults[.mirrorZoomLevel] {
        didSet { Defaults[.mirrorZoomLevel] = zoomLevel }
    }
    @Published public var isFlipped: Bool = Defaults[.mirrorIsFlipped] {
        didSet { Defaults[.mirrorIsFlipped] = isFlipped }
    }
    @Published public var showSnapshotToast: Bool = false

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private let sessionQueue = DispatchQueue(label: "BoringNotch.MirrorManager.SessionQueue", qos: .userInitiated)
    private var snapshotCompletion: ((NSImage?) -> Void)?

    private override init() {
        super.init()
        checkAuthorization()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceChanged), name: .AVCaptureDeviceWasDisconnected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceChanged), name: .AVCaptureDeviceWasConnected, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Authorization

    public func checkAuthorization() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = status
        cameraAvailable = (status == .authorized)
    }

    public func requestAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in
                self.authorizationStatus = granted ? .authorized : .denied
                self.cameraAvailable = granted
                if granted {
                    self.startSession()
                }
                completion(granted)
            }
        }
    }

    // MARK: - Session Control

    public func startSession() {
        checkAuthorization()
        guard authorizationStatus == .authorized else {
            if authorizationStatus == .notDetermined {
                requestAccess { _ in }
            }
            return
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if let session = self.captureSession, session.isRunning {
                Task { @MainActor in
                    self.isSessionRunning = true
                }
                return
            }

            self.setupSession()
        }
    }

    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if let session = self.captureSession, session.isRunning {
                session.stopRunning()
            }
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }

    private func setupSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .high

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )

        guard let device = discovery.devices.first else {
            session.commitConfiguration()
            Task { @MainActor in
                self.cameraAvailable = false
                self.isSessionRunning = false
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            let pOutput = AVCapturePhotoOutput()
            if session.canAddOutput(pOutput) {
                session.addOutput(pOutput)
                self.photoOutput = pOutput
            }

            session.commitConfiguration()
            session.startRunning()

            self.captureSession = session

            Task { @MainActor in
                self.cameraName = device.localizedName
                self.cameraAvailable = true
                self.isSessionRunning = session.isRunning

                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                self.previewLayer = layer
            }
        } catch {
            session.commitConfiguration()
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }

    @objc private func deviceChanged() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isSessionRunning {
                self.setupSession()
            }
        }
    }

    // MARK: - Quick Snapshot

    public func captureSnapshot() {
        guard isSessionRunning, let output = photoOutput else { return }

        let settings = AVCapturePhotoSettings()
        snapshotCompletion = { [weak self] image in
            guard let self = self, let img = image else { return }

            let finalImage: NSImage
            if self.isFlipped {
                finalImage = self.flipImageHorizontally(img)
            } else {
                finalImage = img
            }

            // Write to Clipboard
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([finalImage])

            // Feedback
            NSSound(named: "Bottle")?.play()
            self.showSnapshotToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                self.showSnapshotToast = false
            }
        }

        output.capturePhoto(with: settings, delegate: self)
    }

    nonisolated public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = NSImage(data: data) else {
            Task { @MainActor in
                self.snapshotCompletion?(nil)
            }
            return
        }

        Task { @MainActor in
            self.snapshotCompletion?(image)
        }
    }

    private func flipImageHorizontally(_ image: NSImage) -> NSImage {
        let flipped = NSImage(size: image.size, flipped: false) { rect in
            let transform = NSAffineTransform()
            transform.translateX(by: rect.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            transform.concat()
            image.draw(in: rect)
            return true
        }
        return flipped
    }
}
