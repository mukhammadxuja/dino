import SwiftUI

// Preserved standalone page. This file is not included in the app target.
struct BatteryAlertsSettingsView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            BatteryNotificationSettingsView()
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
        }
        .background(Color.white)
        .accentColor(.effectiveAccent)
        .navigationTitle("Alerts")
    }
}
