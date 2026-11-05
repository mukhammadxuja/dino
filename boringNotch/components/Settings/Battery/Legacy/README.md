# Preserved Battery pages

These sources retain the previous General, Alerts, Charging, App Usage and history interfaces.
They appear in the Xcode project for reference but are deliberately excluded from the app target's Sources build phase.

The release app uses BatterySettingsView, BatteryMetricsModel/Reader, and BatteryNotificationSettingsView.
Restoring a legacy page requires explicitly restoring target membership and a Settings route.
