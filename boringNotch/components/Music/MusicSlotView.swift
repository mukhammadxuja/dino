//
//  MusicSlotView.swift
//  Dino
//
//  Created for Dino Architecture Evolution.
//

import AppKit
import Defaults
import SwiftUI

public struct MusicClosedPillView: View {
    @ObservedObject private var musicManager = MusicManager.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 10) {
            // Leading: Playing wave / visualizer icon
            if musicManager.isPlaying {
                MusicVisualizerBarsView()
                    .frame(width: 18, height: 14)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer(minLength: 0)
            
            // Trailing: Small Album Art
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, 8)
    }
}

// Mini animated wave bars when music is playing
struct MusicVisualizerBarsView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green)
                    .frame(width: 3, height: animating ? CGFloat([14, 8, 12][index]) : CGFloat([6, 12, 6][index]))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                animating = true
            }
        }
    }
}

public struct MusicExpandedCardView: View {
    @ObservedObject private var musicManager = MusicManager.shared
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 16) {
            // Album Art
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            
            // Details & Controls
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(musicManager.songTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(musicManager.artistName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                // Progress Bar
                ProgressView(value: 0.4) // Dynamic bindable progress
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .padding(.vertical, 2)
                
                // Controls
                HStack(spacing: 16) {
                    Button(action: { musicManager.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { musicManager.togglePlay() }) {
                        Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { musicManager.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(width: 360, height: 140)
    }
}
