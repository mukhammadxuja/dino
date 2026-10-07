//
//  AntigravityManager.swift
//  boringNotch
//
//  Created for Antigravity Real-time Process Indicator & Logging.
//

import SwiftUI
import Combine
import Network

import SwiftUI
import Combine
import Network
import AppKit
import AVFoundation

/// Represents all lifecycle phases of Antigravity AI Agent with unique colors and states
public enum AntigravityPhase: Equatable {
    case idle
    case working(task: String)
    case analyzing(query: String)
    case analyzed(summary: String)
    case reading(file: String, lines: Int)
    case read(file: String)
    case editing(file: String, changes: String)
    case edited(file: String)
    case runningCommand(command: String)
    case commandFinished(summary: String)
    case searchingWeb(query: String)
    case planning(step: String)
    case thinking(thought: String)
    case askingPermission(action: String)
    case waitingInput(question: String)
    case taskCompleted(summary: String)
    
    public var title: String {
        switch self {
        case .idle:
            return "Antigravity"
        case .working:
            return "Working"
        case .analyzing:
            return "Analyzing"
        case .analyzed:
            return "Analyzed"
        case .reading:
            return "Reading file"
        case .read:
            return "File read"
        case .editing:
            return "Editing file"
        case .edited:
            return "Edited"
        case .runningCommand:
            return "Running command"
        case .commandFinished:
            return "Command finished"
        case .searchingWeb:
            return "Searching web"
        case .planning:
            return "Generating plan"
        case .thinking:
            return "Thinking"
        case .askingPermission:
            return "Permission Required"
        case .waitingInput:
            return "Waiting your response"
        case .taskCompleted:
            return "Done"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .idle:
            return "Standing by"
        case .working(let task):
            return task.isEmpty ? "Processing request..." : task
        case .analyzing(let query):
            return query
        case .analyzed(let summary):
            return summary
        case .reading(let file, let lines):
            return "Read \(file) \(lines) lines"
        case .read(let file):
            return "Read \(file) completed"
        case .editing(let file, let changes):
            return "Modifying \(file) (\(changes))"
        case .edited(let file):
            return "Saved \(file)"
        case .runningCommand(let command):
            return command
        case .commandFinished(let summary):
            return summary
        case .searchingWeb(let query):
            return "Query: \(query)"
        case .planning(let step):
            return step
        case .thinking(let thought):
            return thought
        case .askingPermission(let action):
            return action
        case .waitingInput(let question):
            return question
        case .taskCompleted(let summary):
            return summary.isEmpty ? "Task completed successfully" : summary
        }
    }
    
    /// Short bold action label (e.g. "Thinking", "Reading", "Editing")
    public var actionTitle: String {
        switch self {
        case .idle:
            return "Antigravity"
        case .working:
            return "Working"
        case .analyzing:
            return "Analyzing"
        case .analyzed:
            return "Analyzed"
        case .reading:
            return "Reading"
        case .read:
            return "Read"
        case .editing:
            return "Editing"
        case .edited:
            return "Edited"
        case .runningCommand:
            return "Running"
        case .commandFinished:
            return "Command"
        case .searchingWeb:
            return "Searching"
        case .planning:
            return "Planning"
        case .thinking:
            return "Thinking"
        case .askingPermission:
            return "Permission"
        case .waitingInput:
            return "Waiting response"
        case .taskCompleted:
            return "Task Completed"
        }
    }
    
    /// Target file name, command or detail to display with 50% opacity next to action
    public var targetDetail: String? {
        switch self {
        case .idle:
            return nil
        case .working(let task):
            return task.isEmpty ? nil : task
        case .analyzing(let query):
            return query.isEmpty ? nil : query
        case .analyzed(let summary):
            return summary.isEmpty ? nil : summary
        case .reading(let file, _):
            return (file as NSString).lastPathComponent
        case .read(let file):
            return (file as NSString).lastPathComponent
        case .editing(let file, _):
            return (file as NSString).lastPathComponent
        case .edited(let file):
            return (file as NSString).lastPathComponent
        case .runningCommand(let command):
            return command.isEmpty ? nil : command
        case .commandFinished(let summary):
            return summary.isEmpty ? nil : summary
        case .searchingWeb(let query):
            return query.isEmpty ? nil : query
        case .planning(let step):
            return step.isEmpty ? nil : step
        case .thinking(let thought):
            return thought.isEmpty ? nil : thought
        case .askingPermission(let action):
            return action.isEmpty ? nil : action
        case .waitingInput(let question):
            return question.isEmpty ? nil : question
        case .taskCompleted(let summary):
            return summary.isEmpty || summary == "Done" || summary == "Task completed successfully" ? nil : summary
        }
    }
    
    /// Vibrant Accent Colors for Pixel Snake Loading Animation
    public var accentColor: Color {
        switch self {
        case .idle:
            return Color.gray
        case .working:
            // Electric Sky Blue / Azure
            return Color(red: 0.30, green: 0.68, blue: 1.0)
        case .analyzing:
            // 1. Sky Blue / Cyan
            return Color(red: 0.22, green: 0.72, blue: 1.0)
        case .analyzed:
            // 2. Mint Teal
            return Color(red: 0.20, green: 0.88, blue: 0.72)
        case .reading:
            // 3. Coral Peach
            return Color(red: 1.0, green: 0.50, blue: 0.40)
        case .read:
            // 4. Soft Lime
            return Color(red: 0.42, green: 0.86, blue: 0.48)
        case .editing:
            // 5. Warm Amber / Gold
            return Color(red: 1.0, green: 0.72, blue: 0.18)
        case .edited:
            // 6. Emerald Green
            return Color(red: 0.16, green: 0.82, blue: 0.46)
        case .runningCommand:
            // 7. Electric Indigo / Violet
            return Color(red: 0.68, green: 0.45, blue: 1.0)
        case .commandFinished:
            // 8. Aqua Marine
            return Color(red: 0.25, green: 0.90, blue: 0.65)
        case .searchingWeb:
            // 9. Deep Sapphire Blue
            return Color(red: 0.25, green: 0.56, blue: 1.0)
        case .planning:
            // 10. Sunset Orange
            return Color(red: 1.0, green: 0.55, blue: 0.12)
        case .thinking:
            // 11. Magenta / Orchid
            return Color(red: 0.86, green: 0.42, blue: 0.92)
        case .askingPermission:
            // 12. Crimson Coral
            return Color(red: 1.0, green: 0.32, blue: 0.36)
        case .waitingInput:
            // 13. Electric Purple
            return Color(red: 0.78, green: 0.48, blue: 1.0)
        case .taskCompleted:
            // 14. Pure Success Green
            return Color(red: 0.20, green: 0.92, blue: 0.42)
        }
    }
}

@MainActor
public final class AntigravityManager: ObservableObject {
    public static let shared = AntigravityManager()
    
    @Published public var currentPhase: AntigravityPhase = .idle
    @Published public var isVisible: Bool = false
    @Published public var permissionGranted: Bool? = nil
    
    private var demoTask: Task<Void, Never>?
    private var fileWatcherTask: Task<Void, Never>?
    private var lastObservedLineCount: Int = 0
    private var lastWatchedFilePath: String? = nil
    private var autoDismissTask: Task<Void, Never>?
    private var localListener: NWListener?
    
    public init() {
        NSLog("🚀 [AntigravityManager] Initializing manager & starting services...")
        startRealtimeWatcher()
        startLocalServer()
    }
    
    /// Trigger a specific phase manually or from logs
    public func setPhase(_ phase: AntigravityPhase, autoDismissAfter: Double? = nil) {
        NSLog("🚀 [Antigravity] PHASE CHANGED -> [%@] %@", phase.title, phase.subtitle)
        
        // Play notification sound when agent needs user response or finishes task
        switch phase {
        case .waitingInput, .askingPermission, .taskCompleted:
            playCompletedSound()
        default:
            break
        }
        
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            self.currentPhase = phase
            self.isVisible = (phase != .idle)
        }
        
        // Expand closed notch width smoothly
        BoringViewCoordinator.shared.toggleExpandingView(
            status: (phase != .idle),
            type: .antigravity
        )
        
        // Determine dismiss duration: Exactly 5 seconds for taskCompleted, 4.5s for normal steps, nil for waitingInput
        let effectiveDismissDelay: Double? = {
            if let custom = autoDismissAfter { return custom }
            switch phase {
            case .taskCompleted:
                return 5.0 // Wait 5 seconds before disappearing
            case .idle, .waitingInput, .askingPermission:
                return nil // Do not auto-dismiss while awaiting response
            default:
                return 4.5
            }
        }()
        
        autoDismissTask?.cancel()
        if let delay = effectiveDismissDelay, phase != .idle {
            autoDismissTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if !Task.isCancelled && self.currentPhase == phase {
                    NSLog("🚀 [Antigravity] Auto-dismissing phase to idle after \(delay)s")
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                        self.isVisible = false
                        self.currentPhase = .idle
                    }
                    BoringViewCoordinator.shared.toggleExpandingView(status: false, type: .antigravity)
                }
            }
        }
    }
    
    private var completionAudioPlayer: AVAudioPlayer?
    
    private func playCompletedSound() {
        // 1. Try loading directly from NSDataAsset (Xcode Asset Catalog Dataset)
        if let asset = NSDataAsset(name: "completed-sound") {
            do {
                completionAudioPlayer?.stop()
                completionAudioPlayer = try AVAudioPlayer(data: asset.data)
                completionAudioPlayer?.volume = 1.0
                completionAudioPlayer?.prepareToPlay()
                completionAudioPlayer?.play()
                NSLog("🔊 [Antigravity Sound] Successfully played completed-sound from NSDataAsset")
                return
            } catch {
                NSLog("⚠️ [Antigravity Sound] NSDataAsset AVAudioPlayer error: %@", error.localizedDescription)
            }
        }
        
        // 2. Try AudioPlayer helper
        if AudioPlayer().playIfAvailable(fileName: "completed-sound", fileExtension: "mp3") {
            return
        }
        
        NSSound(named: "Ping")?.play()
    }
    
    // MARK: - Real-time Antigravity Transcript File Watcher
    
    public func startRealtimeWatcher() {
        fileWatcherTask?.cancel()
        fileWatcherTask = Task.detached(priority: .background) { [weak self] in
            let fm = FileManager.default
            let homeDir = fm.homeDirectoryForCurrentUser.path
            let brainDir = (homeDir as NSString).appendingPathComponent(".gemini/antigravity-ide/brain")
            
            NSLog("🚀 [Antigravity Watcher] Monitoring brain directory: %@", brainDir)
            
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000) // Poll every 300ms
                
                guard let transcriptPath = Self.findLatestTranscript(in: brainDir) else {
                    continue
                }
                
                let lastCount = await self?.lastObservedLineCount ?? 0
                let lastPath = await self?.lastWatchedFilePath
                
                guard let (newLines, totalCount) = Self.readAppendedLines(
                    from: transcriptPath,
                    lastCount: lastCount,
                    lastPath: lastPath
                ) else {
                    continue
                }
                
                await self?.updateWatcherState(path: transcriptPath, totalCount: totalCount)
                
                for line in newLines {
                    if let phase = Self.parseTranscriptLine(line) {
                        NSLog("🚀 [Antigravity Watcher] Detected new action from log: %@", phase.title)
                        await self?.setPhase(phase)
                    }
                }
            }
        }
    }
    
    private func updateWatcherState(path: String, totalCount: Int) {
        if self.lastWatchedFilePath != path {
            NSLog("🚀 [Antigravity Watcher] Switched to active conversation log: %@", path)
            self.lastWatchedFilePath = path
        }
        self.lastObservedLineCount = totalCount
    }
    
    nonisolated private static func findLatestTranscript(in brainDir: String) -> String? {
        let fm = FileManager.default
        guard let conversations = try? fm.contentsOfDirectory(atPath: brainDir) else { return nil }
        
        var latestDate: Date = .distantPast
        var latestPath: String? = nil
        
        for conv in conversations {
            let logFile = (brainDir as NSString)
                .appendingPathComponent(conv)
                .appending("/.system_generated/logs/transcript.jsonl")
            
            if let attrs = try? fm.attributesOfItem(atPath: logFile),
               let modDate = attrs[.modificationDate] as? Date {
                if modDate > latestDate {
                    latestDate = modDate
                    latestPath = logFile
                }
            }
        }
        return latestPath
    }
    
    nonisolated private static func readAppendedLines(from path: String, lastCount: Int, lastPath: String?) -> ([String], Int)? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        let currentCount = lines.count
        
        // Initial launch or new log file sync: Just track the count, do not re-play old history or trigger sounds
        if lastPath == nil || path != lastPath || lastCount > currentCount {
            return ([], currentCount)
        }
        
        if currentCount > lastCount {
            let newLines = Array(lines[lastCount..<currentCount])
            return (newLines, currentCount)
        }
        return nil
    }
    
    nonisolated private static func parseTranscriptLine(_ jsonLine: String) -> AntigravityPhase? {
        guard let data = jsonLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // 0. Check User Input (Immediate Working... HUD when user sends prompt)
        if let type = json["type"] as? String, type == "USER_INPUT" {
            let content = (json["content"] as? String) ?? ""
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let firstLine = trimmed.components(separatedBy: .newlines).first ?? "Processing request..."
            return .working(task: firstLine.isEmpty ? "Processing request..." : firstLine)
        }
        
        // 1. Check tool calls (Active Actions)
        if let toolCalls = json["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty, let firstTool = toolCalls.first {
            let name = (firstTool["name"] as? String) ?? ""
            let args = (firstTool["args"] as? [String: Any]) ?? [:]
            let toolAction = (firstTool["toolAction"] as? String) ?? ""
            let toolSummary = (firstTool["toolSummary"] as? String) ?? ""
            
            switch name {
            case "view_file":
                let fullPath = ((args["AbsolutePath"] as? String) ?? "").replacingOccurrences(of: "\"", with: "")
                let filename = (fullPath as NSString).lastPathComponent
                let lineCount = ((args["EndLine"] as? Int) ?? 0) - ((args["StartLine"] as? Int) ?? 1) + 1
                let finalLines = lineCount > 1 ? lineCount : 55
                return .reading(file: filename.isEmpty ? "file" : filename, lines: finalLines)
                
            case "grep_search", "list_dir":
                let query = ((args["Query"] as? String) ?? (args["query"] as? String) ?? toolAction).replacingOccurrences(of: "\"", with: "")
                return .analyzing(query: query.isEmpty ? "Analyzing codebase..." : query)
                
            case "search_web":
                let query = ((args["query"] as? String) ?? "Searching documentation").replacingOccurrences(of: "\"", with: "")
                return .searchingWeb(query: query)
                
            case "replace_file_content", "multi_replace_file_content", "write_to_file":
                let target = ((args["TargetFile"] as? String) ?? "").replacingOccurrences(of: "\"", with: "")
                let filename = (target as NSString).lastPathComponent
                return .editing(file: filename.isEmpty ? "source file" : filename, changes: "Applying edits")
                
            case "run_command":
                let cmd = (args["CommandLine"] as? String) ?? toolSummary
                return .runningCommand(command: cmd)
                
            case "ask_question":
                return .waitingInput(question: "Waiting your response...")
                
            default:
                if !toolSummary.isEmpty {
                    return .analyzing(query: toolSummary)
                }
            }
        }
        
        // 2. Check if model has completed its turn/response to the user (No active tool calls)
        if let type = json["type"] as? String, type == "PLANNER_RESPONSE", let status = json["status"] as? String, status == "DONE" {
            let toolCalls = (json["tool_calls"] as? [[String: Any]]) ?? []
            if toolCalls.isEmpty {
                return .taskCompleted(summary: "Completed")
            }
        }
        
        return nil
    }
    
    // MARK: - Local IPC TCP Server on 127.0.0.1:9876
    
    private func startLocalServer() {
        do {
            let port = NWEndpoint.Port(rawValue: 9876) ?? .init(integerLiteral: 9876)
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params, on: port)
            
            listener.newConnectionHandler = { connection in
                connection.start(queue: .main)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                    guard let data = data, let text = String(data: data, encoding: .utf8) else { return }
                    NSLog("🚀 [Antigravity Local Server] Received payload: %@", text)
                    DispatchQueue.main.async {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if trimmed.hasPrefix("demo") {
                            AntigravityManager.shared.startDemoSequence()
                        } else if trimmed.hasPrefix("read_file") {
                            AntigravityManager.shared.setPhase(.reading(file: "NotchHomeView.swift", lines: 80))
                        } else if trimmed.hasPrefix("read_done") {
                            AntigravityManager.shared.setPhase(.read(file: "NotchHomeView.swift"))
                        } else if trimmed.hasPrefix("edit_file") {
                            AntigravityManager.shared.setPhase(.editing(file: "AntigravityLiveActivity.swift", changes: "+24 -6"))
                        } else if trimmed.hasPrefix("edit_done") {
                            AntigravityManager.shared.setPhase(.edited(file: "AntigravityLiveActivity.swift"))
                        } else if trimmed.hasPrefix("analyze_active") {
                            AntigravityManager.shared.setPhase(.analyzing(query: "Analyzing codebase architecture..."))
                        } else if trimmed.hasPrefix("analyze_done") {
                            AntigravityManager.shared.setPhase(.analyzed(summary: "Found 12 component definitions"))
                        } else if trimmed.hasPrefix("cmd_active") {
                            AntigravityManager.shared.setPhase(.runningCommand(command: "swift build --configuration release"))
                        } else if trimmed.hasPrefix("cmd_done") {
                            AntigravityManager.shared.setPhase(.commandFinished(summary: "Exit code: 0 (Success)"))
                        } else if trimmed.hasPrefix("web") {
                            AntigravityManager.shared.setPhase(.searchingWeb(query: "Apple HIG dynamic island guidelines"))
                        } else if trimmed.hasPrefix("plan") {
                            AntigravityManager.shared.setPhase(.planning(step: "Phase 3: Integration & Testing"))
                        } else if trimmed.hasPrefix("think") {
                            AntigravityManager.shared.setPhase(.thinking(thought: "Optimizing spring animations..."))
                        } else if trimmed.hasPrefix("permission") {
                            AntigravityManager.shared.setPhase(.askingPermission(action: "Allow run_command: 'npm build'?"))
                        } else if trimmed.hasPrefix("wait") {
                            AntigravityManager.shared.setPhase(.waitingInput(question: "Please confirm migration path"))
                        } else if trimmed.hasPrefix("done") {
                            AntigravityManager.shared.setPhase(.taskCompleted(summary: "All 14 phases verified successfully!"))
                        } else if trimmed.hasPrefix("stop") {
                            AntigravityManager.shared.stopDemo()
                        } else {
                            AntigravityManager.shared.setPhase(.analyzing(query: text))
                        }
                    }
                }
            }
            listener.start(queue: .main)
            self.localListener = listener
            NSLog("🚀 [Antigravity Local Server] Listening on 127.0.0.1:9876 for direct IPC events")
        } catch {
            NSLog("⚠️ [Antigravity Local Server] Could not start server: %@", error.localizedDescription)
        }
    }
    
    // MARK: - Automated Complete 14-Phase Demo Sequence
    
    public func startDemoSequence() {
        demoTask?.cancel()
        demoTask = Task { @MainActor in
            let demoSteps: [(AntigravityPhase, Double)] = [
                // 1. Analyzing
                (.analyzing(query: "Analyzing codebase architecture..."), 2.4),
                // 2. Analyzed
                (.analyzed(summary: "Found 12 component definitions"), 2.0),
                // 3. Reading file
                (.reading(file: "NotchHomeView.swift", lines: 80), 2.4),
                // 4. File read
                (.read(file: "NotchHomeView.swift"), 2.0),
                // 5. Editing file
                (.editing(file: "AntigravityLiveActivity.swift", changes: "+24 -6"), 2.4),
                // 6. Edited
                (.edited(file: "AntigravityLiveActivity.swift"), 2.0),
                // 7. Running command
                (.runningCommand(command: "swift build --release"), 2.4),
                // 8. Command finished
                (.commandFinished(summary: "Build Succeeded (0.4s)"), 2.0),
                // 9. Searching web
                (.searchingWeb(query: "Apple HIG dynamic notch design"), 2.4),
                // 10. Generating plan
                (.planning(step: "Phase 3: Visual Polish & Verification"), 2.4),
                // 11. Thinking
                (.thinking(thought: "Optimizing spring curves..."), 2.4),
                // 12. Asking permission
                (.askingPermission(action: "Allow run_command: 'npm run dev'?"), 3.0),
                // 13. Waiting input (cycles 3 dots + sound)
                (.waitingInput(question: "Select option to proceed"), 3.0),
                // 14. Done / Completed (checkmark + sound + 5s hold)
                (.taskCompleted(summary: "All 14 phases verified!"), 5.0),
                // Idle return
                (.idle, 0.5)
            ]
            
            for (phase, duration) in demoSteps {
                if Task.isCancelled { break }
                self.setPhase(phase, autoDismissAfter: duration)
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            }
            self.setPhase(.idle)
        }
    }
    
    public func stopDemo() {
        demoTask?.cancel()
        setPhase(.idle)
    }
    
    public func respondToPermission(allow: Bool) {
        self.permissionGranted = allow
        withAnimation {
            if allow {
                self.setPhase(.runningCommand(command: "Executing approved task..."))
            } else {
                self.setPhase(.idle)
            }
        }
    }
}
