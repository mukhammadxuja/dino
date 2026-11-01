//
//  LottieView.swift
//  boringNotch
//
//  Created by Alexander on 2025-11-14.
//

import SwiftUI
import Lottie

struct LottieView: NSViewRepresentable {
    let url: URL
    let speed: Double
    let loopMode: LottieLoopMode

    final class Coordinator {
        var requestedURL: URL?
        var requestID = UUID()
        var lastFailedURL: URL?
        var lastFailureAt: Date?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let animationView = nsView.subviews.first as? LottieAnimationView else { return }
        animationView.loopMode = loopMode
        animationView.animationSpeed = CGFloat(speed)

        if context.coordinator.requestedURL != url {
            if context.coordinator.lastFailedURL == url,
               let failedAt = context.coordinator.lastFailureAt,
               Date().timeIntervalSince(failedAt) < 10 { return }
            context.coordinator.requestedURL = url
            let requestID = UUID()
            context.coordinator.requestID = requestID
            let coordinator = context.coordinator
            LottieAnimation.loadedFrom(url: url) { [weak animationView, weak coordinator] animation in
                DispatchQueue.main.async {
                    guard let animationView, let coordinator,
                          coordinator.requestID == requestID,
                          coordinator.requestedURL == url else { return }
                    if let animation {
                        coordinator.lastFailedURL = nil
                        coordinator.lastFailureAt = nil
                        animationView.animation = animation
                        animationView.play()
                    } else {
                        animationView.animation = nil
                        coordinator.requestedURL = nil
                        coordinator.lastFailedURL = url
                        coordinator.lastFailureAt = Date()
                    }
                }
            }
        } else if animationView.animation != nil && !animationView.isAnimationPlaying {
            animationView.play()
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.requestID = UUID()
        coordinator.requestedURL = nil
        (nsView.subviews.first as? LottieAnimationView)?.stop()
    }
}
