//
//  BeerChillerWidgetBundle.swift
//  BeerCHILLERWidget
//
//  The extension's deployment target is iOS 16.0, so the Live Activity — which
//  needs 16.1 — is added through the result builder's limited-availability path.
//

import SwiftUI
import WidgetKit

@main
struct BeerChillerWidgetBundle: WidgetBundle {

    var body: some Widget {
        ChillTimerWidget()

        if #available(iOS 16.1, *) {
            ChillLiveActivity()
        }
    }
}
