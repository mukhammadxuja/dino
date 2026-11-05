import SwiftUI

struct AppearanceSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AppearanceHoverSettingsSection()
                AppearanceDisplaySettingsSection()
                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .navigationTitle("Appearance")
    }
}
