//
//  InfoView.swift
//  BeerCHILLER
//
//  The "about" screen. The Android original shows version plus tagline in a
//  dialog; the iOS equivalent is a small sheet, which also gives the tagline a
//  home — it was translated into all ten languages but previously unused.
//

import SwiftUI

struct InfoView: View {

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var markHeight: CGFloat = 76

    var onOpenHelp: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    BrandMark(bottleColor: palette.markBottle,
                              frostColor: palette.markFrost)
                        .frame(height: markHeight)
                        .padding(.top, 24)

                    (Text(verbatim: "Beer").foregroundColor(palette.accent)
                        + Text(verbatim: "CHILLER").foregroundColor(palette.brandSecondary))
                        .font(.largeTitle.weight(.bold))
                        .accessibilityLabel(Text(verbatim: "BeerCHILLER"))

                    Text(Self.versionLine)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)

                    Text(LocalizedStringKey("tagline"))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.primaryText)
                        .padding(.horizontal, 28)
                        .padding(.top, 4)

                    Button {
                        dismiss()
                        onOpenHelp()
                    } label: {
                        Label(LocalizedStringKey("menu_calculation_model"),
                              systemImage: "function")
                            .font(.body.weight(.medium))
                    }
                    .padding(.top, 8)

                    Spacer(minLength: 24)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(Text(LocalizedStringKey("info_title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Text(LocalizedStringKey("close"))
                    }
                }
            }
        }
    }

    /// "BeerCHILLER Version 1.0 (1)"
    static var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return String(format: Formatting.localized("version_display"),
                      "\(version) (\(build))")
    }
}
