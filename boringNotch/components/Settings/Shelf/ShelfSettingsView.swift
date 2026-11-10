import AppKit
import Defaults
import SwiftUI

struct ShelfSettingsView: View {
    @Default(.boringShelf) private var boringShelf
    @Default(.openShelfByDefault) private var openShelfByDefault
    @Default(.expandedDragDetection) private var expandedDragDetection
    @Default(.copyOnDrag) private var copyOnDrag
    @Default(.autoRemoveShelfItems) private var autoRemoveShelfItems
    @Default(.quickShareProvider) private var quickShareProvider
    @StateObject private var quickShareService = QuickShareService.shared

    private var selectedProvider: QuickShareProvider? {
        quickShareService.availableProviders.first(where: { $0.id == quickShareProvider })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection("Shelf") {
                    MediaSettingsRow(
                        icon: "books.vertical.fill", iconColor: .purple,
                        title: "Enable shelf", subtitle: "Keep recently dropped items available in the notch"
                    ) {
                        toggle($boringShelf, label: "Enable shelf")
                    }
                    MediaSettingsDivider()
                    MediaSettingsRow(
                        icon: "rectangle.stack.fill", iconColor: .blue,
                        title: "Open shelf by default", subtitle: "Open the shelf when items are available"
                    ) {
                        toggle($openShelfByDefault, label: "Open shelf by default")
                    }
                    MediaSettingsDivider()
                    MediaSettingsRow(
                        icon: "arrow.up.left.and.arrow.down.right", iconColor: .orange,
                        title: "Expanded drag detection", subtitle: "Make it easier to drop files onto the shelf"
                    ) {
                        toggle($expandedDragDetection, label: "Expanded drag detection")
                    }
                    .onChange(of: expandedDragDetection) {
                        NotificationCenter.default.post(name: .expandedDragDetectionChanged, object: nil)
                    }
                    MediaSettingsDivider()
                    MediaSettingsRow(
                        icon: "doc.on.doc.fill", iconColor: .teal,
                        title: "Copy items on drag", subtitle: "Keep the original file when dragging it from the shelf"
                    ) {
                        toggle($copyOnDrag, label: "Copy items on drag")
                    }
                    MediaSettingsDivider()
                    MediaSettingsRow(
                        icon: "trash.fill", iconColor: .red,
                        title: "Remove after dragging", subtitle: "Clear items from the shelf once they are used"
                    ) {
                        toggle($autoRemoveShelfItems, label: "Remove after dragging")
                    }
                }

                settingsSection("Quick Share") {
                    MediaSettingsRow(
                        icon: "square.and.arrow.up.fill", iconColor: .effectiveAccent,
                        title: "Quick Share service", subtitle: "Choose the service used to share shelf items"
                    ) {
                        Picker("Quick Share service", selection: $quickShareProvider) {
                            ForEach(quickShareService.availableProviders, id: \.id) { provider in
                                Text(provider.id).tag(provider.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 145)
                    }

                    if let selectedProvider {
                        MediaSettingsDivider()
                        MediaSettingsRow(
                            icon: "checkmark.circle.fill", iconColor: .green,
                            title: "Using \(selectedProvider.id)",
                            subtitle: "Files dropped on the shelf will be shared with this service"
                        ) {
                            EmptyView()
                        }
                    }
                }
            }
            .padding(20)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Shelf")
        .task { await quickShareService.discoverAvailableProviders() }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
            VStack(spacing: 0, content: content)
                .hudSettingsCard()
        }
    }

    private func toggle(_ binding: Binding<Bool>, label: String) -> some View {
        Toggle(label, isOn: binding)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.effectiveAccent)
    }
}
