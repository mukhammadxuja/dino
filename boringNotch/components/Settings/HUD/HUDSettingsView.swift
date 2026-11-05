import SwiftUI

struct HUDSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HUDSystemSettingsCard()
                HUDIndicatorSettingsSection()
            }
            .padding(20)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("HUDs")
    }
}

#Preview {
    HUDSettingsView()
}
