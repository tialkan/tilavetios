//
//  Tilavet_AppApp.swift
//  Tilavet App
//
//  Created by Tarık ALKAN on 7.03.2026.
//

import SwiftUI

@main
struct Tilavet_AppApp: App {
    @StateObject private var settingsStore: AppSettingsStore
    @StateObject private var viewModel: TrackerViewModel

    init() {
        AppFontRegistrar.registerBundledFonts()
        let settingsStore = AppSettingsStore()
        let quranStore = AppBootstrap.makeQuranStore()
        let sessionStore = SessionStore()
        let audioService = AudioStreamingService()
        let engine = WhisperRecitationEngine()

        _settingsStore = StateObject(wrappedValue: settingsStore)
        _viewModel = StateObject(
            wrappedValue: TrackerViewModel(
                quranStore: quranStore,
                sessionStore: sessionStore,
                audioService: audioService,
                recitationEngine: engine,
                settingsStore: settingsStore
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
