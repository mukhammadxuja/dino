import Combine
import Foundation

@MainActor
final class BatteryMetricsModel: ObservableObject {
    @Published private(set) var snapshot = BatteryMetricsSnapshot.unavailable

    // Owned by the page's SwiftUI task. Leaving the page or deactivating its
    // window cancels the loop; there is no singleton, persistent timer or cache.
    func monitorWhileVisible() async {
        while !Task.isCancelled {
            let next = await Task.detached(priority: .utility) {
                BatteryMetricsReader.read()
            }.value
            guard !Task.isCancelled else { return }
            if snapshot != next {
                snapshot = next
            }
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                return
            }
        }
    }
}
