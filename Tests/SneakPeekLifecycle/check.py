"""Compile production expanding-peek methods without app startup or user settings."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root / 'boringNotch/BoringViewCoordinator.swift').read_text()
start = source.index('    func toggleExpandingView(')
end = source.index('    /// Projection of the selected slot;', start)
presentation = source[start:end]
start = source.index('    func cancelAllTasks()')
brace = source.index('{', start)
depth = 1
end = brace + 1
while depth:
    depth += (source[end] == '{') - (source[end] == '}')
    end += 1
cleanup = source[start:end]
start = source.index('enum SneakContentType')
end = source.index('@MainActor\nclass BoringViewCoordinator', start)
models = source[start:end]
fixture = '''import Foundation
import Combine
import SwiftUI

enum HUDAnimations {
    static let presentation = Animation.interactiveSpring(response: 0.34, dampingFraction: 0.62)
}

@MainActor final class PeekHarness: ObservableObject {
    private var sneakPeekTask: Task<Void, Never>?
    private var hudEnableTask: Task<Void, Never>?
''' + presentation + cleanup + '\n}\n'
checks = root / 'Tests/SneakPeekLifecycle/LifecycleCheck.swift'
with tempfile.TemporaryDirectory(prefix='dino-peek-lifecycle-') as directory:
    directory = Path(directory)
    generated = directory / 'ProductionPeekHarness.swift'
    generated.write_text(fixture[:fixture.index('@MainActor final class')] + models + fixture[fixture.index('@MainActor final class'):])
    executable = directory / 'check'
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5',
                    '-module-cache-path', '/tmp/dino-lyrics-module-cache', str(generated), str(checks),
                    '-o', str(executable)], check=True, cwd=root)
    subprocess.run([str(executable)], check=True, cwd=root)
