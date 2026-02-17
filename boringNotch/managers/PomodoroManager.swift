import Combine
import Defaults
import Foundation

@MainActor
final class PomodoroManager: ObservableObject {
    enum Phase: String, Codable {
        case focus
        case shortBreak
        case longBreak

        var title: String {
            switch self {
            case .focus:
                return "Focus"
            case .shortBreak:
                return "Short Break"
            case .longBreak:
                return "Long Break"
            }
        }
    }

    enum State: String, Codable {
        case idle
        case running
        case paused
    }

    struct PersistedSession: Codable {
        let phase: Phase
        let state: State
        let pausedRemaining: TimeInterval
        let phaseEndDate: Date?
        let completedFocusSessions: Int
    }

    static let shared = PomodoroManager()

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var state: State = .idle
    @Published private(set) var remainingTime: TimeInterval = 0
    @Published private(set) var completedFocusSessions: Int = 0
    @Published private(set) var strictModeBypassedForCurrentBreak: Bool = false

    private var pausedRemaining: TimeInterval = 0
    private var phaseEndDate: Date?
    private var tickCancellable: AnyCancellable?

    private let audioPlayer = AudioPlayer()
    private var didPlayCountdownSoundForPhase: Bool = false

    private init() {
        restorePersistedSession()

        if state == .idle {
            remainingTime = duration(for: .focus)
            pausedRemaining = remainingTime
        }
    }

    var isRunning: Bool { state == .running }
    var isPaused: Bool { state == .paused }
    var hasActiveSession: Bool { state == .running || state == .paused }

    var phaseTitle: String { phase.title }

    var cycleText: String {
        let cycleLimit = max(1, Defaults[.pomodoroCycleBeforeLongBreak])
        let current = (completedFocusSessions % cycleLimit) + 1
        return "(\(current)/\(cycleLimit))"
    }

    var formattedRemainingTime: String {
        Self.format(time: remainingTime)
    }

    var isBreakPhase: Bool {
        phase == .shortBreak || phase == .longBreak
    }

    var shouldEnforceStrictMode: Bool {
        Defaults[.pomodoroEnabled]
            && Defaults[.pomodoroStrictModeEnabled]
            && hasActiveSession
            && isBreakPhase
            && !strictModeBypassedForCurrentBreak
    }

    var isWaitingToStartBreak: Bool {
        isBreakPhase && state == .paused
    }

    var progress: Double {
        let total = max(1, duration(for: phase))
        return min(max((total - remainingTime) / total, 0), 1)
    }

    func start() {
        phase = .focus
        begin(phase: .focus, startImmediately: true)
    }

    func togglePlayPause() {
        switch state {
        case .idle:
            start()
        case .running:
            pause()
        case .paused:
            resume()
        }
    }

    func pause() {
        guard state == .running else { return }
        pausedRemaining = currentRemaining()
        remainingTime = pausedRemaining
        phaseEndDate = nil
        state = .paused
        didPlayCountdownSoundForPhase = false
        stopTicker()
        persistSession()
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        phaseEndDate = Date().addingTimeInterval(pausedRemaining)
        startTicker()
        persistSession()
    }

    func reset() {
        state = .idle
        phase = .focus
        completedFocusSessions = 0
        strictModeBypassedForCurrentBreak = false
        phaseEndDate = nil
        pausedRemaining = duration(for: .focus)
        remainingTime = pausedRemaining
        didPlayCountdownSoundForPhase = false
        stopTicker()
        persistSession()
    }

    func skip() {
        playEndSoundIfEnabled()
        completeCurrentPhase()
    }

    func startCurrentBreakIfNeeded() {
        guard isWaitingToStartBreak else { return }
        resume()
    }

    func startNextBreakNow() {
        guard phase == .focus else { return }
        playEndSoundIfEnabled()
        completeCurrentPhase()
    }

    func extendCurrentFocus(byMinutes minutes: Int) {
        guard phase == .focus else { return }

        let delta = TimeInterval(max(1, minutes) * 60)

        if state == .running {
            if let phaseEndDate {
                self.phaseEndDate = phaseEndDate.addingTimeInterval(delta)
            } else {
                phaseEndDate = Date().addingTimeInterval(max(0, remainingTime) + delta)
            }
            let updatedRemaining = currentRemaining()
            remainingTime = updatedRemaining
            pausedRemaining = updatedRemaining
        } else {
            pausedRemaining += delta
            remainingTime = pausedRemaining
        }

        persistSession()
    }

    func bypassStrictModeForCurrentBreak() {
        guard isBreakPhase else { return }
        strictModeBypassedForCurrentBreak = true
    }

    private func begin(phase: Phase, startImmediately: Bool) {
        self.phase = phase
        if phase == .focus {
            strictModeBypassedForCurrentBreak = false
        }
        let phaseDuration = duration(for: phase)
        remainingTime = phaseDuration
        pausedRemaining = phaseDuration
        didPlayCountdownSoundForPhase = false

        if startImmediately {
            state = .running
            phaseEndDate = Date().addingTimeInterval(phaseDuration)
            startTicker()
        } else {
            state = .paused
            phaseEndDate = nil
            stopTicker()
        }

        persistSession()
    }

    private func duration(for phase: Phase) -> TimeInterval {
        switch phase {
        case .focus:
            return TimeInterval(max(1, Defaults[.pomodoroFocusMinutes]) * 60)
        case .shortBreak:
            return TimeInterval(max(1, Defaults[.pomodoroShortBreakMinutes]) * 60)
        case .longBreak:
            return TimeInterval(max(1, Defaults[.pomodoroLongBreakMinutes]) * 60)
        }
    }

    private func currentRemaining() -> TimeInterval {
        guard let end = phaseEndDate else {
            return pausedRemaining
        }
        return max(0, end.timeIntervalSinceNow)
    }

    private func startTicker() {
        stopTicker()
        tickCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.handleTick()
            }
    }

    private func stopTicker() {
        tickCancellable?.cancel()
        tickCancellable = nil
    }

    private func handleTick() {
        guard state == .running else { return }
        let current = currentRemaining()
        remainingTime = current

#if DEBUG
        let debugSecondsLeft = Int(ceil(max(0, current)))
        if debugSecondsLeft <= 6 {
            print("⏱️ [Pomodoro] phase=\(phase.rawValue) remaining=\(debugSecondsLeft)s")
        }
#endif

        playTickSoundIfNeeded(remaining: current)

        if current <= 0 {
#if DEBUG
            print("✅ [Pomodoro] Phase completed: \(phase.rawValue). Playing end sound.")
#endif
            playEndSoundIfEnabled()
            completeCurrentPhase()
            return
        }

        persistSession()
    }

    private func completeCurrentPhase() {
        if phase == .focus {
            completedFocusSessions += 1
            let cycleLimit = max(1, Defaults[.pomodoroCycleBeforeLongBreak])
            let shouldRunLongBreak = completedFocusSessions % cycleLimit == 0
            begin(
                phase: shouldRunLongBreak ? .longBreak : .shortBreak,
                startImmediately: Defaults[.pomodoroAutoStartBreaks]
            )
            return
        }

        begin(
            phase: .focus,
            startImmediately: Defaults[.pomodoroAutoStartFocus]
        )
    }

    private func playTickSoundIfNeeded(remaining: TimeInterval) {
        guard let fileName = Defaults[.pomodoroTickSound].fileName else { return }

        let secondsLeft = Int(ceil(max(0, remaining)))
        guard secondsLeft == 6 else { return }
        guard !didPlayCountdownSoundForPhase else { return }
        didPlayCountdownSoundForPhase = true
#if DEBUG
        print("🔔 [Pomodoro] Countdown sound at 6s left: \(fileName).mp3")
#endif
        audioPlayer.play(fileName: fileName, fileExtension: "mp3", subdirectory: "sounds")
    }

    private func playEndSoundIfEnabled() {
        guard let fileName = Defaults[.pomodoroEndSound].fileName else { return }
#if DEBUG
        print("🔊 [Pomodoro] End sound: \(fileName).mp3")
#endif
        audioPlayer.play(fileName: fileName, fileExtension: "mp3", subdirectory: "sounds")
    }

    private func persistSession() {
        let session = PersistedSession(
            phase: phase,
            state: state,
            pausedRemaining: max(0, pausedRemaining),
            phaseEndDate: phaseEndDate,
            completedFocusSessions: completedFocusSessions
        )

        let encoder = JSONEncoder()
        Defaults[.pomodoroPersistedSession] = try? encoder.encode(session)
    }

    private func restorePersistedSession() {
        guard let data = Defaults[.pomodoroPersistedSession] else { return }
        let decoder = JSONDecoder()
        guard let session = try? decoder.decode(PersistedSession.self, from: data) else { return }

        phase = session.phase
        completedFocusSessions = session.completedFocusSessions

        switch session.state {
        case .idle:
            state = .idle
            pausedRemaining = max(0, session.pausedRemaining)
            remainingTime = pausedRemaining
            phaseEndDate = nil
        case .paused:
            state = .paused
            pausedRemaining = max(0, session.pausedRemaining)
            remainingTime = pausedRemaining
            phaseEndDate = nil
        case .running:
            state = .running
            phaseEndDate = session.phaseEndDate
            let remaining = currentRemaining()
            remainingTime = remaining
            pausedRemaining = remaining

            if remaining <= 0 {
                completeCurrentPhase()
            } else {
                startTicker()
            }
        }
    }

    private static func format(time: TimeInterval) -> String {
        let totalSeconds = max(0, Int(time.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}
