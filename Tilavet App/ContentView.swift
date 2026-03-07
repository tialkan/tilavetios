import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TrackerViewModel
    @State private var showingStartPointPicker = false

    var body: some View {
        TabView {
            NavigationStack {
                TrackerDashboardView(
                    viewModel: viewModel,
                    showingStartPointPicker: $showingStartPointPicker
                )
            }
            .tabItem {
                Label("Takip", systemImage: "waveform.badge.mic")
            }

            NavigationStack {
                HistoryView(viewModel: viewModel)
            }
            .tabItem {
                Label("Oturumlar", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }

            NavigationStack {
                SettingsView(viewModel: viewModel, settingsStore: viewModel.settingsStore)
            }
            .tabItem {
                Label("Ayarlar", systemImage: "slider.horizontal.3")
            }
        }
        .tint(Color("AccentColor"))
        .sheet(isPresented: $showingStartPointPicker) {
            StartPointPickerView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }
}

private struct TrackerDashboardView: View {
    @ObservedObject var viewModel: TrackerViewModel
    @Binding var showingStartPointPicker: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.93, blue: 0.86), Color(red: 0.90, green: 0.82, blue: 0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusCard
                    teleprompterCard
                    controlsCard
                    if viewModel.settingsStore.showDebugPanel {
                        debugCard
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tilavet")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.85))

            Text("Ayet ve kelime takibini cihaz icinde surdurur.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.65))
        }
    }

    private var statusCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    StatusChip(title: "Mic", value: microphoneLabel, color: microphoneColor)
                    StatusChip(title: "Model", value: viewModel.modelState.label, color: modelColor)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Baslangic noktasi")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.6))

                    Text(startPointTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.85))
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.58, green: 0.14, blue: 0.09))
                }

                HStack(spacing: 12) {
                    Button("Sure/Ayet Sec") {
                        showingStartPointPicker = true
                    }
                    .buttonStyle(TilavetSecondaryButtonStyle())

                    Button(viewModel.isTracking ? "Durdur" : "Baslat") {
                        if viewModel.isTracking {
                            viewModel.stopTracking()
                        } else {
                            Task {
                                await viewModel.startTracking()
                            }
                        }
                    }
                    .buttonStyle(TilavetPrimaryButtonStyle())
                }
            }
        }
    }

    private var teleprompterCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.statusMessage)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.72))
                        Text("Son transcript: \(viewModel.lastTranscript.isEmpty ? "bekleniyor" : viewModel.lastTranscript)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.54))
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(confidenceLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.7), in: Capsule())
                }

                VStack(alignment: .trailing, spacing: 14) {
                    if let previousVerse = viewModel.previousVerse {
                        VerseBlock(text: attributedVerse(for: previousVerse, highlightedWord: nil, emphasis: .low))
                    }

                    if let currentVerse = viewModel.currentVerse {
                        VerseBlock(text: attributedVerse(for: currentVerse, highlightedWord: viewModel.trackingState.wordIndex, emphasis: .high))
                    } else {
                        Text("Mushaf verisi yuklenemedi.")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.72))
                    }

                    if let nextVerse = viewModel.nextVerse {
                        VerseBlock(text: attributedVerse(for: nextVerse, highlightedWord: nil, emphasis: .medium))
                    }
                }
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }

    private var controlsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Hizli kontrol")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.85))

                HStack(spacing: 12) {
                    Button("Onceki Ayet") {
                        viewModel.jumpToPreviousAyah()
                    }
                    .buttonStyle(TilavetSecondaryButtonStyle())

                    Button("Ayet Basina Don") {
                        viewModel.jumpToSelectedStartPoint()
                    }
                    .buttonStyle(TilavetSecondaryButtonStyle())

                    Button("Sonraki Ayet") {
                        viewModel.jumpToNextAyah()
                    }
                    .buttonStyle(TilavetSecondaryButtonStyle())
                }
            }
        }
    }

    private var debugCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Gelistirici paneli")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.85))

                debugRow(title: "Model yolu", value: viewModel.debugSnapshot.modelLocation)
                debugRow(title: "Gecikme", value: "\(Int(viewModel.debugSnapshot.lastLatency * 1000)) ms")
                debugRow(title: "Pencere", value: viewModel.debugSnapshot.rollingWindowSeconds.formatted(.number.precision(.fractionLength(1))) + " sn")
                debugRow(title: "Durum", value: viewModel.trackingState.driftState.rawValue)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Aday ayetler")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    ForEach(viewModel.debugSnapshot.candidateSummary, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.72))
                    }
                    if viewModel.debugSnapshot.candidateSummary.isEmpty {
                        Text("Aday gelmedi.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.55))
                    }
                }
            }
        }
    }

    private func debugRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.82))
        }
    }

    private var startPointTitle: String {
        guard let verse = viewModel.currentVerse else {
            return "Sure \(viewModel.selectedSurahID), Ayet \(viewModel.selectedAyahID)"
        }
        return "\(verse.transliteration) • \(verse.ayahID)"
    }

    private var microphoneLabel: String {
        switch viewModel.permissionState {
        case .unknown:
            return "Unknown"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        }
    }

    private var microphoneColor: Color {
        switch viewModel.permissionState {
        case .unknown:
            return .gray
        case .granted:
            return .green
        case .denied:
            return .red
        }
    }

    private var modelColor: Color {
        switch viewModel.modelState {
        case .ready:
            return .green
        case .loading:
            return .orange
        case .idle:
            return .gray
        case .unavailable, .failed:
            return .red
        }
    }

    private var confidenceLabel: String {
        let percent = Int(viewModel.trackingState.confidence * 100)
        return "Guven \(percent)%"
    }

    private func attributedVerse(for verse: QuranVerse, highlightedWord: Int?, emphasis: VerseEmphasis) -> AttributedString {
        var result = AttributedString()

        for word in verse.words {
            var fragment = AttributedString(word.uthmani)
            fragment.font = emphasis.font
            fragment.foregroundColor = emphasis.foregroundColor

            if let highlightedWord, highlightedWord == word.wordIndex {
                fragment.foregroundColor = Color(red: 0.35, green: 0.14, blue: 0.04)
                fragment.backgroundColor = Color(red: 0.99, green: 0.84, blue: 0.44)
            }

            result += fragment

            if word.wordIndex < verse.words.count - 1 {
                var spacer = AttributedString(" ")
                spacer.font = emphasis.font
                spacer.foregroundColor = emphasis.foregroundColor
                result += spacer
            }
        }

        return result
    }
}

private struct HistoryView: View {
    @ObservedObject var viewModel: TrackerViewModel

    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.94, blue: 0.90)
                .ignoresSafeArea()

            if viewModel.sessions.isEmpty {
                ContentUnavailableView(
                    "Oturum kaydi yok",
                    systemImage: "tray",
                    description: Text("Ilk takip seansindan sonra oturum ozeti burada gozukur.")
                )
            } else {
                List(viewModel.sessions) { session in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sure \(session.startedFrom.surahID) • Ayet \(session.startedFrom.ayahID) -> \(session.endedAtPoint.surahID):\(session.endedAtPoint.ayahID)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))

                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("Guven: \(Int(session.averageConfidence * 100))%")
                            Spacer()
                            Text("Drift: \(session.driftEvents)")
                            Spacer()
                            Text(session.mode == .live ? "Canli" : "Simulasyon")
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.white.opacity(0.72))
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Oturumlar")
    }
}

private struct SettingsView: View {
    @ObservedObject var viewModel: TrackerViewModel
    @ObservedObject var settingsStore: AppSettingsStore

    var body: some View {
        Form {
            Section("Calisma modu") {
                Toggle("Debug panelini goster", isOn: $settingsStore.showDebugPanel)
                Toggle("Simulasyon modu", isOn: $settingsStore.useSimulatedRecitation)
            }

            Section("Motor") {
                LabeledContent("Model durumu", value: viewModel.modelState.label)
                LabeledContent("Model yolu", value: viewModel.debugSnapshot.modelLocation)
            }

            Section("Not") {
                Text("Gercek takip icin donusturulmus whisper-turbo-quran model klasorunu app bundle icine ekleyin. Model yoksa simulasyon modu ile UI ve hizalama test edilebilir.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
        }
        .navigationTitle("Ayarlar")
    }
}

private struct StartPointPickerView: View {
    @ObservedObject var viewModel: TrackerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSurahID: Int
    @State private var selectedAyahID: Int

    init(viewModel: TrackerViewModel) {
        self.viewModel = viewModel
        _selectedSurahID = State(initialValue: viewModel.selectedSurahID)
        _selectedAyahID = State(initialValue: viewModel.selectedAyahID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sure") {
                    Picker("Sure", selection: $selectedSurahID) {
                        ForEach(viewModel.surahs) { surah in
                            Text("\(surah.id). \(surah.transliteration)").tag(surah.id)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 160)
                }

                Section("Ayet") {
                    Picker("Ayet", selection: $selectedAyahID) {
                        ForEach(availableAyahs, id: \.self) { ayah in
                            Text("Ayet \(ayah)").tag(ayah)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 160)
                }
            }
            .navigationTitle("Baslangic noktasi")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uygula") {
                        viewModel.updateSelectedSurah(selectedSurahID)
                        viewModel.updateSelectedAyah(selectedAyahID)
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedSurahID) { _, newValue in
                let maxAyah = viewModel.surahs.first(where: { $0.id == newValue })?.totalVerses ?? 1
                selectedAyahID = min(selectedAyahID, maxAyah)
            }
        }
    }

    private var availableAyahs: [Int] {
        let total = viewModel.surahs.first(where: { $0.id == selectedSurahID })?.totalVerses ?? 1
        return Array(1...total)
    }
}

private struct SurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(18)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct VerseBlock: View {
    let text: AttributedString

    var body: some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .multilineTextAlignment(.trailing)
            .lineSpacing(10)
    }
}

private struct StatusChip: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.45))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.82))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.14), in: Capsule())
    }
}

private struct TilavetPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color(red: 0.33, green: 0.18, blue: 0.07), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct TilavetSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.33, green: 0.18, blue: 0.07))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.85), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private enum VerseEmphasis {
    case low
    case medium
    case high

    var font: Font {
        switch self {
        case .low:
            return .system(size: 22, weight: .medium, design: .rounded)
        case .medium:
            return .system(size: 24, weight: .semibold, design: .rounded)
        case .high:
            return .system(size: 32, weight: .bold, design: .rounded)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .low:
            return Color.black.opacity(0.42)
        case .medium:
            return Color.black.opacity(0.58)
        case .high:
            return Color.black.opacity(0.88)
        }
    }
}

#Preview {
    let settings = AppSettingsStore()
    let store = AppBootstrap.makeQuranStore()
    ContentView(
        viewModel: TrackerViewModel(
            quranStore: store,
            sessionStore: SessionStore(),
            audioService: AudioStreamingService(),
            recitationEngine: WhisperRecitationEngine(),
            settingsStore: settings
        )
    )
}
