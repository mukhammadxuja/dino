import Foundation

@main struct LifecycleCheck {
    @MainActor static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            print("FAIL: \(message)")
            exit(1)
        }
    }

    @MainActor static func main() async throws {
        let peek = PeekHarness()
        peek.toggleExpandingView(status: true, type: .music)
        await Task.yield()
        expect(peek.expandingView.show, "A music peek is shown")
        peek.cancelAllTasks()
        expect(!peek.expandingView.show, "Closing the player clears the peek as well as its timer")
        await Task.yield()
        expect(!peek.expandingView.show, "Queued work cannot reopen a cancelled peek")

        peek.toggleExpandingView(status: true, type: .music)
        expect(peek.expandingView.show && peek.expandingView.type == .music, "A new presentation commits immediately")
        peek.toggleExpandingView(status: true, type: .battery, value: 75)
        peek.toggleExpandingView(status: false, type: .music)
        expect(peek.expandingView.show && peek.expandingView.type == .battery, "An old music dismissal does not hide a newer battery HUD")
        expect(peek.expandingView.value == 75, "Replacement presentation retains its value")
        peek.cancelAllTasks()
        expect(!peek.expandingView.show, "Cleanup dismisses the replacement presentation")

        peek.toggleExpandingView(status: true, type: .music)
        try await Task.sleep(for: .milliseconds(3_200))
        expect(!peek.expandingView.show, "Automatic inline music peeks expire normally")
        print("Sneak peek lifecycle: 8 checks passed")
    }
}
