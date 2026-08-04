//
//  SettingsView.swift
//  BeerCHILLER
//
//  Native grouped form. Language is deliberately *not* offered here: on iOS the
//  per-app language lives in Settings → BeerCHILLER → Language, and duplicating
//  it in-app would fight the system. A row deep-links there instead.
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $settings.visualStyle) {
                        ForEach(VisualStyle.allCases, id: \.self) { style in
                            Text(LocalizedStringKey(style.titleKey)).tag(style)
                        }
                    } label: {
                        Text(LocalizedStringKey("visual_style_title"))
                    }

                    Picker(selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(LocalizedStringKey(mode.titleKey)).tag(mode)
                        }
                    } label: {
                        Text(LocalizedStringKey("appearance_title"))
                    }
                }

                Section {
                    Picker(selection: $settings.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                            Text(LocalizedStringKey(unit.titleKey)).tag(unit)
                        }
                    } label: {
                        Text(LocalizedStringKey("temperature_unit_title"))
                    }
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text(LocalizedStringKey("language_title"))
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(LocalizedStringKey("language_footer"))
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(InfoView.versionLine)
                        Text(LocalizedStringKey("tagline"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text(LocalizedStringKey("info_title"))
                }
            }
            .navigationTitle(Text(LocalizedStringKey("settings_title")))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("close"))
                    }
                }
            }
        }
    }

}
