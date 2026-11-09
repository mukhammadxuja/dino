//
//  CalendarManager.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 08/09/24.
//

import Defaults
import EventKit
import SwiftUI

// MARK: - CalendarManager

@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    struct ReminderUndo: Identifiable {
        let id: String
        let title: String
    }

    @Published var currentWeekStartDate: Date
    @Published var events: [EventModel] = []
    @Published var monthEvents: [EventModel] = []
    @Published var allCalendars: [CalendarModel] = []
    @Published var eventCalendars: [CalendarModel] = []
    @Published var reminderLists: [CalendarModel] = []
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var reminderUndo: ReminderUndo?
    private var selectedCalendars: [CalendarModel] = []
    private let calendarService = CalendarService()
    private var cacheGeneration = 0
    private var monthCache: [Date: [EventModel]] = [:]
    private var pendingMonthRequests: [Date: Task<[EventModel], Never>] = [:]
    private var eventStoreRefreshTask: Task<Void, Never>?
    private var undoExpiryTask: Task<Void, Never>?

    private var eventStoreChangedObserver: NSObjectProtocol?

    private init() {
        self.currentWeekStartDate = CalendarManager.startOfDay(Date())
        self.calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
        self.reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        setupEventStoreChangedObserver()
        Task {
            await reloadCalendarAndReminderLists()
            await updateEvents()
        }
    }

    deinit {
        if let observer = eventStoreChangedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        eventStoreRefreshTask?.cancel()
        undoExpiryTask?.cancel()
    }

    private func setupEventStoreChangedObserver() {
        eventStoreChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                self?.scheduleEventStoreRefresh()
            }
        }
    }

    private func invalidateMonthCache() {
        cacheGeneration += 1
        monthCache.removeAll()
        for task in pendingMonthRequests.values { task.cancel() }
        pendingMonthRequests.removeAll()
    }

    private func scheduleEventStoreRefresh() {
        invalidateMonthCache()
        eventStoreRefreshTask?.cancel()
        eventStoreRefreshTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            guard let self else { return }
            self.eventStoreRefreshTask = nil
            await self.reloadCalendarAndReminderLists()
            guard !Task.isCancelled else { return }
            await self.updateEvents()
        }
    }

    @MainActor
    func reloadCalendarAndReminderLists() async {
        let all = await calendarService.calendars()
        self.eventCalendars = all.filter { !$0.isReminder }
        self.reminderLists = all.filter { $0.isReminder }
        self.allCalendars = all // for legacy compatibility, can be removed if not needed
        updateSelectedCalendars()
    }

    func checkCalendarAuthorization() async {
        await checkAuthorization(for: .event)
    }
    
    func checkReminderAuthorization() async {
        await checkAuthorization(for: .reminder)
    }

    private func checkAuthorization(for type: EKEntityType) async {
        let previous = type == .event ? calendarAuthorizationStatus : reminderAuthorizationStatus
        var status = EKEventStore.authorizationStatus(for: type)
        if status == .notDetermined {
            guard let granted = try? await calendarService.requestAccess(to: type) else { return }
            status = granted ? .fullAccess : .denied
        }
        if type == .event { calendarAuthorizationStatus = status }
        else { reminderAuthorizationStatus = status }
        guard previous != status else { return }
        invalidateMonthCache()
        await reloadCalendarAndReminderLists()
        await updateEvents()
    }
        

    func updateSelectedCalendars() {
        // Populate selectedCalendarIDs based on Defaults calendar selection state
        switch Defaults[.calendarSelectionState] {
        case .all:
            selectedCalendarIDs = Set(allCalendars.map { $0.id })
        case .selected(let identifiers):
            selectedCalendarIDs = identifiers
        }

        // Update the local calendar objects that correspond to the selected ids
        selectedCalendars = allCalendars.filter { selectedCalendarIDs.contains($0.id) }
    }

    func getCalendarSelected(_ calendar: CalendarModel) -> Bool {
        return selectedCalendarIDs.contains(calendar.id)
    }

    func setCalendarSelected(_ calendar: CalendarModel, isSelected: Bool) async {
        var selectionState = Defaults[.calendarSelectionState]

        switch selectionState {
        case .all:
            if !isSelected {
                let identifiers = Set(allCalendars.map { $0.id }).subtracting([calendar.id])
                selectionState = .selected(identifiers)
            }

        case .selected(var identifiers):
            if isSelected {
                identifiers.insert(calendar.id)
            } else {
                identifiers.remove(calendar.id)
            }

            selectionState =
                identifiers.isEmpty
                ? .all : identifiers.count == allCalendars.count ? .all : .selected(identifiers)  // if empty, select all
        }

        Defaults[.calendarSelectionState] = selectionState
        updateSelectedCalendars()
        invalidateMonthCache()
        await updateEvents()
    }

    static func startOfDay(_ date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }

    func updateCurrentDate(_ date: Date) async {
        let previousMonth = Calendar.current.dateInterval(of: .month, for: currentWeekStartDate)?.start
        currentWeekStartDate = Calendar.current.startOfDay(for: date)
        if let monthStart = Calendar.current.dateInterval(of: .month, for: date)?.start,
           let cached = monthCache[monthStart] {
            monthEvents = cached
            events = eventsForDay(currentWeekStartDate, in: cached)
        } else if Calendar.current.dateInterval(of: .month, for: date)?.start == previousMonth {
            events = eventsForDay(currentWeekStartDate, in: monthEvents)
        } else {
            events = []
            monthEvents = []
        }
        await updateEvents()
    }

    private func updateEvents() async {
        guard eventStoreRefreshTask == nil else { return }
        guard let month = Calendar.current.dateInterval(of: .month, for: currentWeekStartDate) else { return }
        if let cached = monthCache[month.start] {
            monthEvents = cached
            events = eventsForDay(currentWeekStartDate, in: cached)
            return
        }
        let generation = cacheGeneration
        let request: Task<[EventModel], Never>
        if let pending = pendingMonthRequests[month.start] {
            request = pending
        } else {
            let calendarIDs = selectedCalendars.map { $0.id }
            request = Task { [calendarService] in
                await calendarService.events(from: month.start, to: month.end, calendars: calendarIDs)
            }
            pendingMonthRequests[month.start] = request
        }
        let result = await request.value
        guard generation == cacheGeneration else { return }
        pendingMonthRequests[month.start] = nil
        monthCache[month.start] = result
        guard Calendar.current.dateInterval(of: .month, for: currentWeekStartDate)?.start == month.start else { return }
        monthEvents = result
        events = eventsForDay(currentWeekStartDate, in: result)
    }

    private func eventsForDay(_ start: Date, in events: [EventModel]) -> [EventModel] {
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events.filter { event in
            if event.type.isReminder {
                return event.start >= start && event.start < dayEnd
            }
            return event.start < dayEnd && (event.end > start || event.start >= start)
        }
    }
    
    @discardableResult
    func setReminderCompleted(reminderID: String, completed: Bool) async -> Bool {
        let title = monthEvents.first(where: { $0.id == reminderID })?.title ?? "Reminder"
        let saved = await calendarService.setReminderCompleted(reminderID: reminderID, completed: completed)
        if saved && completed {
            undoExpiryTask?.cancel()
            reminderUndo = ReminderUndo(id: reminderID, title: title)
            undoExpiryTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard self?.reminderUndo?.id == reminderID else { return }
                self?.reminderUndo = nil
            }
        }
        if saved { invalidateMonthCache() }
        await updateEvents()
        return saved
    }

    @discardableResult
    func undoReminderCompletion() async -> Bool {
        guard let undo = reminderUndo else { return false }
        undoExpiryTask?.cancel()
        let saved = await calendarService.setReminderCompleted(reminderID: undo.id, completed: false)
        if saved {
            if reminderUndo?.id == undo.id { reminderUndo = nil }
            invalidateMonthCache()
            await updateEvents()
        }
        return saved
    }
}
