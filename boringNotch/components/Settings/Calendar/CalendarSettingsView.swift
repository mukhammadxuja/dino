import AppKit
import Defaults
import EventKit
import SwiftUI

struct CalendarSettings: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.showCalendar) var showCalendar: Bool
    @Default(.hideCompletedReminders) var hideCompletedReminders
    @Default(.hideAllDayEvents) var hideAllDayEvents
    @Default(.autoScrollToNextEvent) var autoScrollToNextEvent

    var body: some View {
        Form {
            calendarTogglesSection
            calendarsSection
            remindersSection
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Calendar")
        .onAppear {
            Task {
                await calendarManager.checkCalendarAuthorization()
                await calendarManager.checkReminderAuthorization()
            }
        }
    }

    @ViewBuilder
    private var calendarTogglesSection: some View {
        HStack(alignment: .center) {
            Text("Show calendar")
            Spacer()
            KbdShortcutBadge(keys: ["⌘", "⇧", "C"])
            Toggle("", isOn: $showCalendar)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.effectiveAccent)
                .onChange(of: showCalendar) { _, enabled in
                    if !enabled {
                        if Defaults[.activeModule] == .calendar {
                            Defaults[.activeModule] = .none
                        }
                        if DinoCoordinator.shared.activeSlot == .calendar {
                            DinoCoordinator.shared.activateSlotDirectly(DinoCoordinator.shared.backgroundSlot)
                        }
                    }
                }
        }
        Defaults.Toggle(key: .hideCompletedReminders) {
            Text("Hide completed reminders")
        }
        Defaults.Toggle(key: .hideAllDayEvents) {
            Text("Hide all-day events")
        }
        Defaults.Toggle(key: .autoScrollToNextEvent) {
            Text("Auto-scroll to next event")
        }
    }

    @ViewBuilder
    private var calendarsSection: some View {
        Section(header: Text("Calendars")) {
            if calendarManager.calendarAuthorizationStatus != .fullAccess {
                Text("Calendar access is denied. Please enable it in System Settings.")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Open Calendar Settings") {
                    if let settingsURL = URL(
                        string:
                            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
                    ) {
                        NSWorkspace.shared.open(settingsURL)
                    }
                }
            } else {
                List {
                    ForEach(calendarManager.eventCalendars, id: \.id) { calendar in
                        Toggle(
                            isOn: Binding(
                                get: { calendarManager.getCalendarSelected(calendar) },
                                set: { isSelected in
                                    Task {
                                        await calendarManager.setCalendarSelected(
                                            calendar, isSelected: isSelected)
                                    }
                                }
                            )
                        ) {
                            Text(calendar.title)
                        }
                        .accentColor(lighterColor(from: calendar.color))
                        .disabled(!showCalendar)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var remindersSection: some View {
        Section(header: Text("Reminders")) {
            if calendarManager.reminderAuthorizationStatus != .fullAccess {
                Text("Reminder access is denied. Please enable it in System Settings.")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Open Reminder Settings") {
                    if let settingsURL = URL(
                        string:
                            "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
                    ) {
                        NSWorkspace.shared.open(settingsURL)
                    }
                }
            } else {
                List {
                    ForEach(calendarManager.reminderLists, id: \.id) { calendar in
                        Toggle(
                            isOn: Binding(
                                get: { calendarManager.getCalendarSelected(calendar) },
                                set: { isSelected in
                                    Task {
                                        await calendarManager.setCalendarSelected(
                                            calendar, isSelected: isSelected)
                                    }
                                }
                            )
                        ) {
                            Text(calendar.title)
                        }
                        .accentColor(lighterColor(from: calendar.color))
                        .disabled(!showCalendar)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await calendarManager.checkCalendarAuthorization()
                await calendarManager.checkReminderAuthorization()
            }
        }
    }
}

func lighterColor(from nsColor: NSColor, amount: CGFloat = 0.14) -> Color {
    let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
    var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0,0,0,0)
    srgb.getRed(&r, green: &g, blue: &b, alpha: &a)

    func lighten(_ c: CGFloat) -> CGFloat {
        let increased = c + (1.0 - c) * amount
        return min(max(increased, 0), 1)
    }

    let nr = lighten(r)
    let ng = lighten(g)
    let nb = lighten(b)

    return Color(red: Double(nr), green: Double(ng), blue: Double(nb), opacity: Double(a))
}

