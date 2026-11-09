//
//  EventModel.swift
//  Calendr
//
//  Created by Paker on 24/12/20.
//  Original source: https://github.com/pakerwreah/Calendr
//  Modified by Alexander on 2025-05-18.
//

import Foundation

struct EventModel: Equatable, Identifiable {
    let id: String
    let start: Date
    let end: Date
    let title: String
    let location: String?
    let notes: String?
    let url: URL?
    let isAllDay: Bool
    let type: EventType
    let calendar: CalendarModel
    let participants: [Participant]
    let timeZone: TimeZone?
    let hasRecurrenceRules: Bool
    let priority: Priority?
}

enum AttendanceStatus: Comparable {
    case accepted
    case maybe
    case pending
    case declined
    case unknown

    private var comparisonValue: Int {
        switch self {
        case .accepted: return 1
        case .maybe: return 2
        case .declined: return 3
        case .pending: return 4
        case .unknown: return 5
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.comparisonValue < rhs.comparisonValue
    }
}

enum EventType: Equatable {
    case event(AttendanceStatus)
    case birthday
    case reminder(completed: Bool)
}

enum EventStatus: Equatable {
    case upcoming
    case inProgress
    case ended
}

extension EventType {
    var isEvent: Bool { if case .event = self { return true } else { return false } }
    var isBirthday: Bool { self ~= .birthday }
    var isReminder: Bool { if case .reminder = self { return true } else { return false } }
}

extension EventModel {
    
    var eventStatus: EventStatus {
        if start > Date() {
            return .upcoming
        } else if end > Date() {
            return .inProgress
        } else {
            return .ended
        }
    }
        
    var attendance: AttendanceStatus { if case .event(let attendance) = type { return attendance } else { return .unknown } }

    var isMeeting: Bool { !participants.isEmpty }

    /// Only label a meeting provider when the event actually identifies it.
    var meetingProvider: String? {
        let content = [url?.absoluteString, location, notes]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        if content.contains("meet.google.com") || content.contains("google meet") { return "Google Meet" }
        if content.contains("zoom.us") || content.contains("zoom.com") { return "Zoom" }
        if content.contains("teams.microsoft.com") || content.contains("teams.live.com") || content.contains("microsoft teams") { return "Microsoft Teams" }
        if content.contains("webex.com") { return "Webex" }
        return nil
    }

    func calendarAppURL() -> URL? {

        guard let id = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        guard !type.isReminder else {
            return URL(string: "x-apple-reminderkit://remcdreminder/\(id)")
        }

        let date: String
        if hasRecurrenceRules {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if !isAllDay {
                formatter.timeZone = .init(secondsFromGMT: 0)
            }
            if let formattedDate = formatter.string(for: start) {
                date = "/\(formattedDate)"
            } else {
                return nil
            }
        } else {
            date =  ""
        }
        return URL(string: "ical://ekevent\(date)/\(id)?method=show&options=more")
    }
}

struct Participant: Hashable {
    let name: String
    let status: AttendanceStatus
    let isOrganizer: Bool
    let isCurrentUser: Bool
}

enum Priority {
    case high
    case medium
    case low
}
