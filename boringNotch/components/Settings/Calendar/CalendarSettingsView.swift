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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection("Calendar") {
                    MediaSettingsRow(
                        icon: "calendar", iconColor: .red,
                        title: "Show calendar", subtitle: "Show upcoming events in the notch"
                    ) {
                        HStack(spacing: 8) {
                            KbdShortcutBadge(keys: ["⌘", "⇧", "C"])
                            Toggle("Show calendar", isOn: $showCalendar)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .tint(.effectiveAccent)
                                .onChange(of: showCalendar) { _, enabled in
                                    handleCalendarVisibilityChange(enabled)
                                    guard enabled else { return }
                                    Task {
                                        await calendarManager.requestCalendarAndReminderAccess()
                                    }
                                }
                        }
                    }
                    MediaSettingsDivider()
                    settingsToggleRow(
                        icon: "checkmark.circle.fill", iconColor: .green,
                        title: "Hide completed reminders", subtitle: "Keep finished reminders out of the calendar list",
                        binding: $hideCompletedReminders
                    )
                    MediaSettingsDivider()
                    settingsToggleRow(
                        icon: "calendar.badge.minus", iconColor: .orange,
                        title: "Hide all-day events", subtitle: "Only show events with a scheduled time",
                        binding: $hideAllDayEvents
                    )
                    MediaSettingsDivider()
                    settingsToggleRow(
                        icon: "arrow.down.to.line.compact", iconColor: .blue,
                        title: "Auto-scroll to next event", subtitle: "Keep the upcoming event in view",
                        binding: $autoScrollToNextEvent
                    )
                }

                settingsSection("Calendars") {
                    if calendarManager.calendarAuthorizationStatus != .fullAccess {
                        permissionRow(
                            title: "Calendar access is needed",
                            subtitle: "Allow Calendar access in System Settings to choose which events appear in Dino.",
                            buttonTitle: "Open Settings",
                            privacyPath: "Privacy_Calendars"
                        )
                    } else if calendarManager.eventCalendars.isEmpty {
                        emptyRow(title: "No calendars found", subtitle: "Add a calendar in the Calendar app to show it here.")
                    } else {
                        ForEach(Array(calendarManager.eventCalendars.enumerated()), id: \.element.id) { index, calendar in
                            calendarSelectionRow(calendar, isReminderList: false)
                            if index < calendarManager.eventCalendars.count - 1 {
                                MediaSettingsDivider()
                            }
                        }
                    }
                }

                settingsSection("Reminders") {
                    if calendarManager.reminderAuthorizationStatus != .fullAccess {
                        permissionRow(
                            title: "Reminder access is needed",
                            subtitle: "Allow Reminders access in System Settings to choose which lists appear in Dino.",
                            buttonTitle: "Open Settings",
                            privacyPath: "Privacy_Reminders"
                        )
                    } else if calendarManager.reminderLists.isEmpty {
                        emptyRow(title: "No reminder lists found", subtitle: "Add a list in Reminders to show it here.")
                    } else {
                        ForEach(Array(calendarManager.reminderLists.enumerated()), id: \.element.id) { index, calendar in
                            calendarSelectionRow(calendar, isReminderList: true)
                            if index < calendarManager.reminderLists.count - 1 {
                                MediaSettingsDivider()
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Calendar")
        .onAppear {
            Task {
                await calendarManager.refreshAuthorizationStatuses()
            }
        }
    }

    private func handleCalendarVisibilityChange(_ enabled: Bool) {
        guard !enabled else { return }
        if Defaults[.activeModule] == .calendar {
            Defaults[.activeModule] = .none
        }
        if DinoCoordinator.shared.activeSlot == .calendar {
            DinoCoordinator.shared.activateSlotDirectly(DinoCoordinator.shared.backgroundSlot)
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
            VStack(spacing: 0, content: content)
                .hudSettingsCard()
        }
    }

    private func settingsToggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        binding: Binding<Bool>
    ) -> some View {
        MediaSettingsRow(icon: icon, iconColor: iconColor, title: title, subtitle: subtitle) {
            Toggle(title, isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.effectiveAccent)
        }
    }

    private func calendarSelectionRow(_ calendar: CalendarModel, isReminderList: Bool) -> some View {
        MediaSettingsRow(
            icon: isReminderList ? "checklist" : "calendar",
            iconColor: lighterColor(from: calendar.color),
            title: calendar.title,
            subtitle: isReminderList ? "Show reminders from this list" : "Show events from this calendar"
        ) {
            Toggle(calendar.title, isOn: Binding(
                get: { calendarManager.getCalendarSelected(calendar) },
                set: { isSelected in
                    Task {
                        await calendarManager.setCalendarSelected(calendar, isSelected: isSelected)
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(lighterColor(from: calendar.color))
            .disabled(!showCalendar)
        }
    }

    private func permissionRow(
        title: String,
        subtitle: String,
        buttonTitle: String,
        privacyPath: String
    ) -> some View {
        MediaSettingsRow(icon: "lock.shield.fill", iconColor: .orange, title: title, subtitle: subtitle) {
            Button(buttonTitle) {
                if let settingsURL = URL(
                    string: "x-apple.systempreferences:com.apple.preference.security?\(privacyPath)"
                ) {
                    NSWorkspace.shared.open(settingsURL)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func emptyRow(title: String, subtitle: String) -> some View {
        MediaSettingsRow(icon: "calendar.badge.exclamationmark", iconColor: .secondary, title: title, subtitle: subtitle) {
            EmptyView()
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

