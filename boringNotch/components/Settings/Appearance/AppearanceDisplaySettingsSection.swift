import Defaults
import SwiftUI

struct AppearanceDisplaySettingsSection: View {
    @Default(.displaySelection) private var displaySelection
    @Default(.builtinFormFactor) private var builtinFormFactor
    @Default(.externalFormFactor) private var externalFormFactor
    @Default(.islandStyle) private var islandStyle
    @Default(.islandVisibility) private var islandVisibility
    @Default(.displayShowOn) private var displayShowOn

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
                // MARK: - 2. Displays Top Selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("Displays")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        ForEach(DisplaySelection.allCases) { type in
                            DisplaySelectionCard(type: type, selection: $displaySelection)
                        }
                    }
                }

                // MARK: - 3. Dynamic Configuration Based on Selection
                if displaySelection == .builtin {
                    // BUILT-IN DISPLAY SETTINGS
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            FormFactorCard(factor: .notch, selection: $builtinFormFactor)
                            FormFactorCard(factor: .island, selection: $builtinFormFactor)
                        }

                        if builtinFormFactor == .island {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Island")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.top, 4)

                                Text("Style")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 12) {
                                    IslandStyleCard(style: .dark, selection: $islandStyle)
                                    IslandStyleCard(style: .glass, selection: $islandStyle)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Text("Visibility")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        HStack(spacing: 8) {
                            IslandVisibilityCard(visibility: .onHover, selection: $islandVisibility)
                            IslandVisibilityCard(visibility: .onClick, selection: $islandVisibility)
                            if builtinFormFactor == .island {
                                IslandVisibilityCard(visibility: .alwaysVisible, selection: $islandVisibility)
                            }
                        }
                    }
                } else if displaySelection == .external {
                    // EXTERNAL DISPLAY SETTINGS
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            FormFactorCard(factor: .notch, selection: $externalFormFactor)
                            FormFactorCard(factor: .island, selection: $externalFormFactor)
                        }

                        if externalFormFactor == .island {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Island")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)

                                Text("Style")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 12) {
                                    IslandStyleCard(style: .dark, selection: $islandStyle)
                                    IslandStyleCard(style: .glass, selection: $islandStyle)
                                }

                                if displaySelection == .external {
                                    Text("Visibility")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)

                                    HStack(spacing: 8) {
                                        IslandVisibilityCard(visibility: .onHover, selection: $islandVisibility)
                                        IslandVisibilityCard(visibility: .onClick, selection: $islandVisibility)
                                        IslandVisibilityCard(visibility: .alwaysVisible, selection: $islandVisibility)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Show On Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Show on")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)

                            HStack(spacing: 12) {
                                ForEach(DisplayShowOn.allCases) { target in
                                    DisplayShowOnCard(target: target, selection: $displayShowOn)
                                }
                            }

                            Text(displayShowOn.subtitle)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                } else {
                    // BOTH DISPLAYS SETTINGS
                    VStack(alignment: .leading, spacing: 16) {
                        // Built-in group
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "laptopcomputer")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Text("Built-in")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 12) {
                                FormFactorCard(factor: .notch, selection: $builtinFormFactor)
                                FormFactorCard(factor: .island, selection: $builtinFormFactor)
                            }
                        }

                        // External group
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "display")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Text("External")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 12) {
                                FormFactorCard(factor: .notch, selection: $externalFormFactor)
                                FormFactorCard(factor: .island, selection: $externalFormFactor)
                            }
                        }

                        // Island Sub-options if either uses Island
                        if builtinFormFactor == .island || externalFormFactor == .island {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Island")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)

                                Text("Style")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 12) {
                                    IslandStyleCard(style: .dark, selection: $islandStyle)
                                    IslandStyleCard(style: .glass, selection: $islandStyle)
                                }

                                if externalFormFactor == .island {
                                    Text("Visibility")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)

                                    HStack(spacing: 8) {
                                        IslandVisibilityCard(visibility: .onHover, selection: $islandVisibility)
                                        IslandVisibilityCard(visibility: .onClick, selection: $islandVisibility)
                                        IslandVisibilityCard(visibility: .alwaysVisible, selection: $islandVisibility)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Show On Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Show on")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)

                            HStack(spacing: 12) {
                                ForEach(DisplayShowOn.allCases) { target in
                                    DisplayShowOnCard(target: target, selection: $displayShowOn)
                                }
                            }

                            Text(displayShowOn.subtitle)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                }
        }
        .onChange(of: displaySelection) {
            NotificationCenter.default.post(name: .displaySettingsChanged, object: nil)
        }
        .onChange(of: builtinFormFactor) {
            NotificationCenter.default.post(name: .formFactorChanged, object: nil)
        }
        .onChange(of: externalFormFactor) {
            NotificationCenter.default.post(name: .formFactorChanged, object: nil)
        }
        .onChange(of: islandVisibility) {
            NotificationCenter.default.post(name: .displaySettingsChanged, object: nil)
        }
        .onChange(of: displayShowOn) {
            NotificationCenter.default.post(name: .displaySettingsChanged, object: nil)
        }
    }
}
