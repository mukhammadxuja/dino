//
//  BoringCalendar.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 08/09/24.
//

import Defaults
import SwiftUI

struct Config: Equatable {
    //    var count: Int = 10  // 3 days past + today + 7 days future
    var past: Int = 7
    var future: Int = 14
    var steps: Int = 1  // Each step is one day
    var spacing: CGFloat = 0
    var showsText: Bool = true
    var offset: Int = 2  // Number of dates to the left of the selected date
}

struct WheelPicker: View {
    @EnvironmentObject var vm: BoringViewModel
    @Binding var selectedDate: Date
    @State private var scrollPosition: Int?
    @State private var haptics: Bool = false
    @State private var byClick: Bool = false
    let config: Config

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: config.spacing) {
                let spacerNum = config.offset
                let dateCount = totalDateItems()
                let totalItems = dateCount + 2 * spacerNum
                ForEach(0..<totalItems, id: \.self) { index in
                    if index < spacerNum || index >= spacerNum + dateCount {
                        // Leading/trailing spacers sized to match a date cell
                        Spacer()
                            .frame(width: 24, height: 24)
                            .id(index)
                    } else {
                        let date = dateForItemIndex(index: index, spacerNum: spacerNum)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        dateButton(date: date, isSelected: isSelected, id: index) {
                            selectedDate = date
                            byClick = true
                            withAnimation {
                                scrollPosition = index
                            }
                            if Defaults[.enableHaptics] {
                                haptics.toggle()
                            }
                        }
                    }
                }
            }
            .frame(height: 50)
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .scrollTargetBehavior(.viewAligned)  // Ensures scroll view snaps the centered view
        .safeAreaPadding(.horizontal)
        .sensoryFeedback(.alignment, trigger: haptics)
        .onChange(of: scrollPosition) { oldValue, newValue in
            if !byClick {
                handleScrollChange(newValue: newValue, config: config)
            } else {
                byClick = false
            }
        }
        .onAppear {
            scrollToToday(config: config)
        }
        // When parent updates the bound selectedDate (e.g., view reopen), center the wheel on it
        .onChange(of: selectedDate) { _, newValue in
            let targetIndex = indexForDate(newValue)
            if scrollPosition != targetIndex {
                byClick = true
                withAnimation {
                    scrollPosition = targetIndex
                }
            }
        }
    }

    private func dateButton(
        date: Date, isSelected: Bool, id: Int, onClick: @escaping () -> Void
    ) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        return Button(action: onClick) {
            VStack(spacing: 8) {
                dayText(date: dateToString(for: date), isToday: isToday, isSelected: isSelected)
                dateCircle(date: date, isToday: isToday, isSelected: isSelected)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.effectiveAccentBackground : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .id(id)
    }

    private func dayText(date: String, isToday: Bool, isSelected: Bool) -> some View {
        Text(date)
            .font(.caption)
            .foregroundColor(isSelected ? .white : Color(white: 0.65))
    }

    private func dateCircle(date: Date, isToday: Bool, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isToday ? Color.effectiveAccent : .clear)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0)
                )
            Text("\(date.date)")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : Color(white: isToday ? 0.9 : 0.65))
        }
    }

    func handleScrollChange(newValue: Int?, config: Config) {
        guard let newIndex = newValue else { return }
        let spacerNum = config.offset
        let dateCount = totalDateItems()
        guard (spacerNum..<(spacerNum + dateCount)).contains(newIndex) else { return }
        let date = dateForItemIndex(index: newIndex, spacerNum: spacerNum)
        if !Calendar.current.isDate(date, inSameDayAs: selectedDate) {
            selectedDate = date
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }
    }

    private func scrollToToday(config: Config) {
        let today = Date()
        byClick = true
        scrollPosition = indexForDate(today)
        selectedDate = today
    }

    // MARK: - Index/Date mapping with steps and spacers
    private func indexForDate(_ date: Date) -> Int {
        let spacerNum = config.offset
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let startDate = cal.startOfDay(for: cal.date(byAdding: .day, value: -config.past, to: today) ?? today)
        let target = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: startDate, to: target).day ?? 0
        let stepIndex = max(0, min(days / max(config.steps, 1), totalDateItems() - 1))
        return spacerNum + stepIndex
    }

    private func dateForItemIndex(index: Int, spacerNum: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let startDate = cal.date(byAdding: .day, value: -config.past, to: today) ?? today
        let stepIndex = index - spacerNum
        return cal.date(byAdding: .day, value: stepIndex * max(config.steps, 1), to: startDate) ?? today
    }

    private func totalDateItems() -> Int {
        let range = config.past + config.future
        let step = max(config.steps, 1)
        return Int(ceil(Double(range) / Double(step))) + 1
    }

    private func dateToString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

let calendarAccent = Color(red: 1, green: 69 / 255, blue: 58 / 255)

struct CalendarView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.hideCompletedReminders) private var hideCompletedReminders
    @Default(.hideAllDayEvents) private var hideAllDayEvents
    @State private var selectedDate = Date()
    @State private var hiddenReminderIDs: Set<String> = []
    @State private var undoInProgress = false
    @State private var showUndoError = false
    @State private var isCalendarHovered = false

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 12) {
                daySummary
                    .frame(width: geometry.size.width * 0.38, alignment: .leading)

                MonthGrid(
                    selectedDate: $selectedDate,
                    markedDays: markedDays,
                    isControlsHighlighted: isCalendarHovered
                )
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .listRowBackground(Color.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.16)) {
                isCalendarHovered = hovering
                vm.isHoveringCalendar = hovering
            }
        }
        .onChange(of: selectedDate) {
            Task {
                await calendarManager.updateCurrentDate(selectedDate)
            }
        }
        .onChange(of: calendarManager.reminderUndo?.id) { previous, current in
            if let previous, previous != current {
                hiddenReminderIDs.remove(previous)
            }
        }
        .onChange(of: vm.notchState) { _, state in
            guard state == .open else { return }
            selectedDate = Date.now
            Task {
                await calendarManager.updateCurrentDate(selectedDate)
            }
        }
        .onAppear {
            Task {
                await calendarManager.refreshAuthorizationStatuses()
                await calendarManager.updateCurrentDate(selectedDate)
            }
        }
        .onDisappear {
            vm.isHoveringCalendar = false
        }
        .alert("Could not undo reminder", isPresented: $showUndoError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please check your Reminders access and try again.")
        }
    }

    private var markedDays: Set<Date> {
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: selectedDate) else { return [] }
        var days: Set<Date> = []
        for event in calendarManager.monthEvents {
            if case .reminder(let completed) = event.type, completed && hideCompletedReminders { continue }
            if event.isAllDay && !event.type.isReminder && hideAllDayEvents { continue }

            var day = calendar.startOfDay(for: max(event.start, month.start))
            let end = event.type.isReminder ? event.start : event.end
            while day < month.end && (day < end || calendar.isDate(day, inSameDayAs: event.start)) {
                days.insert(day)
                guard !event.type.isReminder, let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return days
    }

    private var daySummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(selectedDate.formatted(.dateTime.weekday(.wide)).uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(calendarAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .offset(y: -3)

            Text("\(Calendar.current.component(.day, from: selectedDate))")
                .font(.system(size: 40, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(Calendar.current.component(.day, from: selectedDate))))
                .padding(.top, -4)

            let events = EventListView.filteredEvents(events: calendarManager.events)
            if events.isEmpty && calendarManager.reminderUndo == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Calendar.current.isDateInToday(selectedDate) ? "No events today" : "No events this day")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("Your day is clear")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.28))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.top, 14)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    if !events.isEmpty {
                        CompactCalendarEventsView(hiddenReminderIDs: $hiddenReminderIDs, events: events)
                            .frame(height: calendarManager.reminderUndo == nil ? 68 : 47)
                            .transition(.opacity)
                    }
                    if let undo = calendarManager.reminderUndo {
                        HStack(spacing: 4) {
                            Text("Completed")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Button("Undo") {
                                undoInProgress = true
                                Task {
                                    let saved = await calendarManager.undoReminderCompletion()
                                    undoInProgress = false
                                    if saved {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            _ = hiddenReminderIDs.remove(undo.id)
                                        }
                                    } else {
                                        showUndoError = true
                                    }
                                }
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(calendarAccent)
                            .buttonStyle(.plain)
                            .disabled(undoInProgress)
                            .accessibilityLabel("Undo completion of \(undo.title)")
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, 6)
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: calendarManager.events)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: calendarManager.reminderUndo?.id)
    }

}

private struct CompactCalendarEventsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.autoScrollToNextEvent) private var autoScrollToNextEvent
    @Binding var hiddenReminderIDs: Set<String>
    @State private var showSaveError = false
    let events: [EventModel]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 2) {
                    ForEach(events.filter { !hiddenReminderIDs.contains($0.id) }) { event in
                        eventRow(event)
                            .id(event.id)
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .scale(scale: 0.8, anchor: .leading).combined(with: .opacity)
                            ))
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentShape(Rectangle())
            .onAppear { scrollToNextEvent(proxy) }
            .onChange(of: events) { _, _ in scrollToNextEvent(proxy) }
        }
        .alert("Could not update reminder", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please check your Reminders access and try again.")
        }
    }

    private func scrollToNextEvent(_ proxy: ScrollViewProxy) {
        guard autoScrollToNextEvent,
              let event = events.first(where: { !$0.isAllDay && $0.end > Date() }) else { return }
        proxy.scrollTo(event.id, anchor: .top)
    }

    private func eventRow(_ event: EventModel) -> some View {
        let color = Color(nsColor: event.calendar.color)
        let completed: Bool = {
            if case .reminder(let isCompleted) = event.type { return isCompleted }
            return false
        }()

        return Group {
            if !event.type.isReminder && !event.type.isBirthday && !event.isAllDay {
                timedEventRow(event, color: color)
            } else {
                compactEventRow(event, color: color, completed: completed)
            }
        }
    }

    private func compactEventRow(_ event: EventModel, color: Color, completed: Bool) -> some View {
        HStack(alignment: .top, spacing: 4) {
            if event.type.isReminder {
                Button {
                    if !completed {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            _ = hiddenReminderIDs.insert(event.id)
                        }
                    }
                    Task {
                        let saved = await calendarManager.setReminderCompleted(
                            reminderID: event.id, completed: !completed
                        )
                        if !saved {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                _ = hiddenReminderIDs.remove(event.id)
                            }
                            showSaveError = true
                        }
                    }
                } label: {
                    Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(completed ? "Mark as incomplete" : "Mark as complete")
            } else {
                Image(systemName: event.type.isBirthday ? "gift.fill" : "calendar")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.black.opacity(0.8))
                    .frame(width: 14, height: 14)
                    .background(color, in: Circle())
                    .accessibilityHidden(true)
            }

            Button {
                if let url = event.calendarAppURL() { openURL(url) }
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    eventTitle(event, color: color)
                    if event.type.isReminder && !event.isAllDay {
                        Text(event.start, style: .time)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(color.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 2)
        .padding(.trailing, 6)
        .padding(.vertical, 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
        .opacity(completed ? 0.55 : 1)
    }

    private func timedEventRow(_ event: EventModel, color: Color) -> some View {
        Button {
            if let url = event.calendarAppURL() { openURL(url) }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                eventTitle(event, color: color)
                if let provider = event.meetingProvider {
                    Label(provider, systemImage: "video.fill")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .lineLimit(1)
                }
                Text("\(event.start.formatted(date: .omitted, time: .shortened))–\(event.end.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(color.opacity(0.85))
            .padding(.leading, 13)
            .padding(.trailing, 5)
            .padding(.vertical, 2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3)
                    .padding(.leading, 5)
                    .padding(.vertical, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func eventTitle(_ event: EventModel, color: Color) -> some View {
        Text(event.title)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MonthGrid: View {
    @Binding var selectedDate: Date
    let markedDays: Set<Date>
    let isControlsHighlighted: Bool

    private enum MonthNavigationDirection {
        case forward
        case backward
    }

    @State private var navigationDirection: MonthNavigationDirection = .forward

    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        return calendar
    }

    private var monthDays: [Date?] {
        let calendar = monthCalendar
        guard let interval = calendar.dateInterval(of: .month, for: selectedDate),
              let dayRange = calendar.range(of: .day, in: .month, for: selectedDate) else {
            return []
        }

        let weekdayOffset = calendar.component(.weekday, from: interval.start) - 1
        var days = Array(repeating: Optional<Date>.none, count: weekdayOffset)
        days += dayRange.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 0), count: 7)
    }

    private var monthKey: Date {
        monthCalendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
    }

    private var gridTransition: AnyTransition {
        switch navigationDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                monthNavigationButton(icon: "chevron.left", label: "Previous month") {
                    changeMonth(by: -1)
                }
                monthNavigationButton(icon: "chevron.right", label: "Next month") {
                    changeMonth(by: 1)
                }
                Text(selectedDate.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(calendarAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .offset(y: -3)

            ZStack {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(weekdaySymbols.indices, id: \.self) { index in
                        Text(weekdaySymbols[index])
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(index == 0 || index == 6 ? .white.opacity(0.4) : .white)
                            .frame(height: 14)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(monthDays.indices, id: \.self) { index in
                        if let date = monthDays[index] {
                            dayButton(for: date)
                        } else {
                            Color.clear.frame(height: 17)
                        }
                    }
                }
                .id(monthKey)
                .transition(gridTransition)
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: monthKey)
        }
    }

    private func dayButton(for date: Date) -> some View {
        let isSelected = monthCalendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = monthCalendar.isDateInToday(date)
        let weekday = monthCalendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7

        return Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedDate = date
            }
        } label: {
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isSelected ? .white : (isToday ? calendarAccent : (isWeekend ? .white.opacity(0.38) : .white)))
                .frame(width: 17, height: 17)
                .background {
                    Circle().fill(isSelected ? calendarAccent : .clear)
                }
                .overlay(alignment: .bottom) {
                    if !isSelected && markedDays.contains(monthCalendar.startOfDay(for: date)) {
                        Circle()
                            .fill(calendarAccent)
                            .frame(width: 3, height: 3)
                            .offset(y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
    }

    private func monthNavigationButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 20, height: 20)
                .background(.white.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
        .opacity(isControlsHighlighted ? 1 : 0)
        .allowsHitTesting(isControlsHighlighted)
        .accessibilityLabel(label)
    }

    private func changeMonth(by value: Int) {
        guard let targetMonth = monthCalendar.date(byAdding: .month, value: value, to: selectedDate) else { return }
        navigationDirection = value >= 0 ? .forward : .backward
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            selectedDate = targetMonth
        }
    }
}

struct EmptyEventsView: View {
    let selectedDate: Date
    
    var body: some View {
        VStack {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title)
                .foregroundColor(Color(white: 0.65))
            Text(Calendar.current.isDateInToday(selectedDate) ? "No events today" : "No events")
                .font(.subheadline)
                .foregroundColor(.white)
            Text("Enjoy your free time!")
                .font(.caption)
                .foregroundColor(Color(white: 0.65))
        }
    }
}

struct EventListView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject private var calendarManager = CalendarManager.shared
    let events: [EventModel]
    @Default(.autoScrollToNextEvent) private var autoScrollToNextEvent
    @Default(.showFullEventTitles) private var showFullEventTitles


    static func filteredEvents(events: [EventModel]) -> [EventModel] {
        events.filter { event in
            if event.type.isReminder {
                if case .reminder(let completed) = event.type {
                    return !completed || !Defaults[.hideCompletedReminders]
                }
            }
            // Filter out all-day events if setting is enabled
            if event.isAllDay && !event.type.isReminder && Defaults[.hideAllDayEvents] {
                return false
            }
            return true
        }
    }

    private var filteredEvents: [EventModel] {
        Self.filteredEvents(events: events)
    }

    private func scrollToRelevantEvent(proxy: ScrollViewProxy) {
        let now = Date()
        // Determine a single target using preferred search order:
        // 1) first non-all-day upcoming/in-progress event
        // 2) first all-day event
        // 3) last event (fallback)
        let nonAllDayUpcoming = filteredEvents.first(where: { !$0.isAllDay && $0.end > now })
        let firstAllDay = filteredEvents.first(where: { $0.isAllDay })
        let lastEvent = filteredEvents.last
        guard let target = nonAllDayUpcoming ?? firstAllDay ?? lastEvent else { return }

        Task { @MainActor in
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(target.id, anchor: .top)
            }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredEvents) { event in
                    Button(action: {
                        if let url = event.calendarAppURL() {
                            openURL(url)
                        }
                    }) {
                        eventRow(event)
                    }
                    .id(event.id)
                    .padding(.leading, -5)
                    .buttonStyle(PlainButtonStyle())
                    .listRowSeparator(.automatic)
                    .listRowSeparatorTint(.gray.opacity(0.2))
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.never)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .onAppear {
                scrollToRelevantEvent(proxy: proxy)
            }
            .onChange(of: filteredEvents) { _, _ in
                scrollToRelevantEvent(proxy: proxy)
            }
        }
        Spacer(minLength: 0)
    }

    private func eventRow(_ event: EventModel) -> some View {
        if event.type.isReminder {
            let isCompleted: Bool
            if case .reminder(let completed) = event.type {
                isCompleted = completed
            } else {
                isCompleted = false
            }
            return AnyView(
                HStack(spacing: 8) {
                    ReminderToggle(
                        isOn: Binding(
                            get: { isCompleted },
                            set: { newValue in
                                Task {
                                    await calendarManager.setReminderCompleted(
                                        reminderID: event.id, completed: newValue
                                    )
                                }
                            }
                        ),
                        color: Color(event.calendar.color)
                    )
                    .opacity(1.0)  // Ensure the toggle is always fully opaque
                    HStack {
                        Text(event.title)
                            .font(.callout)
                            .foregroundColor(.white)
                            .lineLimit(showFullEventTitles ? nil : 1)
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 4) {
                            if event.isAllDay {
                                Text("All-day")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            } else {
                                Text(event.start, style: .time)
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                    }
                    .opacity(
                        isCompleted
                            ? 0.4
                            : event.start < Date.now && Calendar.current.isDateInToday(event.start)
                                ? 0.6 : 1.0
                    )
                }
                .padding(.vertical, 4)
            )
        } else {
            return AnyView(
                HStack(alignment: .top, spacing: 4) {
                    Rectangle()
                        .fill(Color(event.calendar.color))
                        .frame(width: 3)
                        .cornerRadius(1.5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(showFullEventTitles ? nil : 2)

                        if let location = event.location, !location.isEmpty {
                            Text(location)
                                .font(.caption)
                                .foregroundColor(Color(white: 0.65))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        if event.isAllDay {
                            Text("All-day")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        } else {
                            Text(event.start, style: .time)
                                .foregroundColor(.white)
                            Text(event.end, style: .time)
                                .foregroundColor(Color(white: 0.65))
                        }
                    }
                    .font(.caption)
                    .frame(minWidth: 44, alignment: .trailing)
                }
                .opacity(
                    event.eventStatus == .ended && Calendar.current.isDateInToday(event.start)
                        ? 0.6 : 1.0)
            )
        }
    }
}

struct ReminderToggle: View {
    @Binding var isOn: Bool
    var color: Color

    var body: some View {
        Button(action: {
            isOn.toggle()
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: 14, height: 14)
                // Inner fill
                if isOn {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Circle()
                    .fill(Color.black.opacity(0.001))
                    .frame(width: 14, height: 14)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(0)
        .accessibilityLabel(isOn ? "Mark as incomplete" : "Mark as complete")
    }
}

#Preview {
    CalendarView()
        .frame(width: 640, height: 350)
        .background(.black)
        .environmentObject(BoringViewModel())
}
