//
//  ClipboardPanelView.swift
//  boringNotch
//
//  Created for Dino Architecture Evolution.
//

import SwiftUI

public struct ClipboardPanelView: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @FocusState private var isSearchFocused: Bool
    @State private var isAppeared: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            filterBar
            Divider()
                .background(Color.white.opacity(0.10))
            contentList
            footerBar
        }
        .frame(width: 370, height: 360)
        // Deep OLED Black matching notch aesthetic
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        // Spring animation emerging directly out from the Notch/Island
        .scaleEffect(isAppeared ? 1.0 : 0.88, anchor: .top)
        .offset(y: isAppeared ? 0 : -28)
        .opacity(isAppeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78, blendDuration: 0)) {
                isAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            isAppeared = false
        }
    }

    // MARK: - Header & Search Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.65))

            ZStack(alignment: .leading) {
                if manager.searchText.isEmpty {
                    Text("Search clipboard...")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.42))
                }

                TextField("", text: $manager.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .regular))
                    .focused($isSearchFocused)
                    .foregroundColor(.white)
                    .contentShape(Rectangle())
                    .onSubmit {
                        if let first = manager.filteredItems.first {
                            manager.selectAndPaste(item: first)
                        }
                    }
            }

            if !manager.searchText.isEmpty {
                Button {
                    manager.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }

            ColorPickerButton {
                manager.pickColorFromScreen()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(ClipboardItemType.allCases) { type in
                    Button {
                        withAnimation(.smooth(duration: 0.18)) {
                            manager.selectedFilter = type
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.system(size: 8.5))
                            Text(type.rawValue)
                                .font(.system(size: 10.5, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(
                            manager.selectedFilter == type
                                ? Color.white
                                : Color.white.opacity(0.08)
                        )
                        .foregroundColor(
                            manager.selectedFilter == type
                                ? Color.black
                                : Color.white.opacity(0.85)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Content List

    private var contentList: some View {
        Group {
            let items = manager.filteredItems
            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            ClipboardRowView(item: item, index: index)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack(spacing: 8) {
            Text("\(manager.filteredItems.count) items")
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.40))

            Spacer()

            HStack(spacing: 6) {
                FooterButton(title: "Clear All") {
                    manager.clearAll()
                }

                Text("|")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.white.opacity(0.25))

                FooterButton(title: "Esc") {
                    ClipboardPanelController.shared.hide()
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 9)
        .padding(.bottom, 12)
        .background(Color.white.opacity(0.03))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: manager.selectedFilter == .color ? "paintpalette" : "doc.on.clipboard")
                .font(.system(size: 26))
                .foregroundStyle(Color.white.opacity(0.20))

            Text(manager.searchText.isEmpty ? (manager.selectedFilter == .color ? "No colors copied yet" : "No clipboard history yet") : "No matching items")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))

            if manager.selectedFilter == .color {
                Button {
                    manager.pickColorFromScreen()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "eyedropper.halffull")
                        Text("Pick Color from Screen")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                Text("Copy text, images, or links to see them here")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.30))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Compact & Clean Clipboard Row View

private struct ClipboardRowView: View {
    let item: ClipboardItem
    let index: Int
    @ObservedObject var manager = ClipboardManager.shared
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            leadingPreviewIcon(for: item)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.previewTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                }

                HStack(spacing: 4) {
                    if let appName = item.sourceAppName {
                        Text(appName)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("•")
                            .font(.system(size: 7))
                    }

                    Text(item.formattedTime)
                        .lineLimit(1)

                    if item.type != .text {
                        Text("•")
                            .font(.system(size: 7))
                        Text(item.previewSubtitle)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .font(.system(size: 9.5))
                .foregroundStyle(Color.white.opacity(0.38))
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Trailing area: Action buttons on hover, or Hotkey badge when idle
            if isHovered {
                HStack(spacing: 4) {
                    Button {
                        manager.togglePin(item: item)
                    } label: {
                        Image(systemName: item.isPinned ? "pin.slash.fill" : "pin")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        manager.removeItem(item: item)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            } else if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.40))
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            manager.selectAndPaste(item: item)
        }
    }

    @ViewBuilder
    private func leadingPreviewIcon(for item: ClipboardItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: 24, height: 24)

            switch item.type {
            case .image:
                if let data = item.imageData, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.85))
                }

            case .color:
                if let hex = item.stringValue, let color = Color(hex: hex) {
                    Circle()
                        .fill(color)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                } else {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.85))
                }

            case .link:
                Image(systemName: "link")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.85))

            case .file:
                Image(systemName: "doc.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.85))

            default:
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
    }
}

// MARK: - Color Picker Button

private struct ColorPickerButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "eyedropper.halffull")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(isHovered ? 0.95 : 0.65))
                .padding(4.5)
                .background(Color.white.opacity(isHovered ? 0.16 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Pick Color from Screen")
        .onHover { isHovered = $0 }
    }
}

// MARK: - Footer Button

private struct FooterButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(isHovered ? 0.90 : 0.55))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

