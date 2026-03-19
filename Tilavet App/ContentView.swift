import SwiftUI

private enum TilavetSheet: String, Identifiable {
    case history
    case settings
    case startPoint

    var id: String { rawValue }
}

struct ContentView: View {
    @ObservedObject var viewModel: TrackerViewModel
    @State private var activeSheet: TilavetSheet?

    var body: some View {
        NavigationStack {
            TrackerDashboardView(viewModel: viewModel, activeSheet: $activeSheet)
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: TilavetSheet) -> some View {
        switch sheet {
        case .history:
            NavigationStack {
                HistoryView(viewModel: viewModel)
            }
            .presentationDetents([.medium, .large])
        case .settings:
            NavigationStack {
                SettingsView(viewModel: viewModel, settingsStore: viewModel.settingsStore)
            }
            .presentationDetents([.medium, .large])
        case .startPoint:
            StartPointPickerView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }
}

private struct TrackerDashboardView: View {
    @ObservedObject var viewModel: TrackerViewModel
    @Binding var activeSheet: TilavetSheet?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.95, blue: 0.90), Color(red: 0.89, green: 0.83, blue: 0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                header
                verseStage
                actionStage

                if viewModel.settingsStore.showDebugPanel {
                    debugCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Ayet sec") {
                        activeSheet = .startPoint
                    }

                    Button("Oturumlar") {
                        activeSheet = .history
                    }

                    Button("Ayarlar") {
                        activeSheet = .settings
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.74))
                }
                .accessibilityIdentifier("Tilavet.MoreMenu")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tilavet")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.84))
                .accessibilityIdentifier("Tilavet.Header")

            HStack(spacing: 10) {
                StatusPill(
                    title: listeningTitle,
                    icon: viewModel.isTracking ? "waveform" : "mic",
                    color: listeningColor
                )

                StatusPill(
                    title: "Konum \(viewModel.trackingState.surahID):\(viewModel.trackingState.ayahID)",
                    icon: "bookmark",
                    color: Color.black.opacity(0.08)
                )

                if viewModel.settingsStore.useSimulatedRecitation {
                    StatusPill(
                        title: "Simulasyon",
                        icon: "sparkles",
                        color: Color.orange.opacity(0.18)
                    )
                }
            }

            Text(viewModel.statusMessage)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.62))
                .accessibilityIdentifier("Tilavet.StatusMessage")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verseStage: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentLocationTitle)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.82))

                        Text("Ortam sesini dinler, aktif ayeti ve kelimeyi otomatik bulur.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.50))
                    }

                    Spacer()

                    Text(confidenceLabel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.80), in: Capsule())
                }

                VStack(alignment: .trailing, spacing: 18) {
                    if let previousVerse = viewModel.previousVerse {
                        VerseBlock(
                            text: attributedVerse(
                                for: previousVerse,
                                highlightedWord: nil,
                                emphasis: .low
                            )
                        )
                    }

                    if let currentVerse = viewModel.currentVerse {
                        VerseBlock(
                            text: attributedVerse(
                                for: currentVerse,
                                highlightedWord: viewModel.trackingState.wordIndex,
                                emphasis: .high
                            )
                        )
                    } else {
                        Text("Mushaf verisi yuklenemedi.")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.72))
                    }

                    if let nextVerse = viewModel.nextVerse {
                        VerseBlock(
                            text: attributedVerse(
                                for: nextVerse,
                                highlightedWord: nil,
                                emphasis: .medium
                            )
                        )
                    }
                }
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }

    private var actionStage: some View {
        VStack(spacing: 14) {
            Button {
                if viewModel.isTracking {
                    viewModel.stopTracking()
                } else {
                    Task {
                        await viewModel.startTracking()
                    }
                }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: viewModel.isTracking ? "stop.fill" : "mic.fill")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 52, height: 52)
                        .background(Color.white.opacity(0.18), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.isTracking ? "Dinlemeyi durdur" : "Ortami dinle")
                            .font(.system(size: 18, weight: .bold, design: .rounded))

                        Text(viewModel.isTracking ? "Aktif ayet ve kelimeyi canli izliyor." : "Mikrofondan dinleyip ayeti otomatik bulur.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.84))
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
            .buttonStyle(TilavetListenButtonStyle(isActive: viewModel.isTracking))
            .accessibilityIdentifier("Tilavet.StartStopButton")

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.58, green: 0.14, blue: 0.09))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Menu {
                Button {
                    viewModel.jumpToPreviousAyah()
                } label: {
                    Label("Bir onceki ayete git", systemImage: "backward.fill")
                }
                .disabled(viewModel.previousVerse == nil)

                Button {
                    viewModel.jumpToSelectedStartPoint()
                } label: {
                    Label("Baslangic noktasina don", systemImage: "arrow.counterclockwise")
                }

                Button {
                    viewModel.jumpToNextAyah()
                } label: {
                    Label("Bir sonraki ayete git", systemImage: "forward.fill")
                }
                .disabled(viewModel.nextVerse == nil)
            } label: {
                Label("Yeniden senkron", systemImage: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TilavetTransportButtonStyle())
            .accessibilityIdentifier("Tilavet.ResyncMenu")
        }
    }

    private var debugCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Gelistirici paneli")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.82))

                debugRow(title: "Model yolu", value: viewModel.debugSnapshot.modelLocation)
                debugRow(title: "Gecikme", value: "\(Int(viewModel.debugSnapshot.lastLatency * 1000)) ms")
                debugRow(title: "Pencere", value: viewModel.debugSnapshot.rollingWindowSeconds.formatted(.number.precision(.fractionLength(1))) + " sn")
                debugRow(title: "Son transcript", value: viewModel.lastTranscript.isEmpty ? "yok" : viewModel.lastTranscript)

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
        .accessibilityIdentifier("Tilavet.DebugPanel")
    }

    private func debugRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.55))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.82))
                .multilineTextAlignment(.trailing)
        }
    }

    private var currentLocationTitle: String {
        guard let verse = viewModel.currentVerse else {
            return "Sure \(viewModel.selectedSurahID), Ayet \(viewModel.selectedAyahID)"
        }

        return "\(verse.transliteration) • Ayet \(verse.ayahID)"
    }

    private var confidenceLabel: String {
        let percent = Int(viewModel.trackingState.confidence * 100)
        return "Guven \(percent)%"
    }

    private var listeningTitle: String {
        if viewModel.isTracking {
            return "Dinliyor"
        }
        if case .loading = viewModel.modelState {
            return "Hazirlaniyor"
        }
        return "Hazir"
    }

    private var listeningColor: Color {
        if viewModel.isTracking {
            return Color.green.opacity(0.20)
        }
        if case .loading = viewModel.modelState {
            return Color.orange.opacity(0.22)
        }
        return Color.black.opacity(0.08)
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
    @State private var showDeveloperTools = false

    var body: some View {
        Form {
            Section("Takip") {
                LabeledContent("Model durumu", value: viewModel.modelState.label)

                Text("Tilavet varsayilan olarak dogrudan ortam sesini dinler. Ayet secimi ve yeniden senkron yardimci ozellik olarak kalir.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }

            Section("Tipografi") {
                Text("Arapca ayetler icin Amiri Quran kullaniyoruz. Bu, yaygin ve lisansi uygun bir mushaf tipi secimi.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }

            Section("Cevrimdisi") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Gercek takip icin donusturulmus whisper-turbo-quran model klasorunu bu yola koyun. Tum ses isleme cihaz uzerinde yapilir, internet gerekmez.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))

                    Text("Tilavet App/Resources/Models/whisper-turbo-quran")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text("Hazir klasor baska bir yerdeyse: Scripts/stage_quran_model.sh /mutlak/model/yolu/whisper-turbo-quran")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text(appVersionLine)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 5) {
                        showDeveloperTools = true
                    }
            }
        }
        .navigationTitle("Ayarlar")
        .sheet(isPresented: $showDeveloperTools) {
            NavigationStack {
                DeveloperToolsView(viewModel: viewModel, settingsStore: settingsStore)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var appVersionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Tilavet \(version) (\(build))"
    }
}

private struct DeveloperToolsView: View {
    @ObservedObject var viewModel: TrackerViewModel
    @ObservedObject var settingsStore: AppSettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Gelistirici") {
                Toggle("Debug panelini goster", isOn: $settingsStore.showDebugPanel)
                Toggle("Simulasyon modu", isOn: $settingsStore.useSimulatedRecitation)
            }

            Section("Motor") {
                LabeledContent("Model durumu", value: viewModel.modelState.label)
                LabeledContent("Model yolu", value: viewModel.debugSnapshot.modelLocation)
            }
        }
        .navigationTitle("Gelistirici araclari")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Kapat") {
                    dismiss()
                }
            }
        }
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
                Section {
                    Text("Varsayilan akista uygulama dogrudan dinler. Burasi ise istege bagli baslangic noktasi secimi icin.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.68))
                }

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
                        .accessibilityIdentifier("Tilavet.StartPointCloseButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uygula") {
                        viewModel.updateSelectedSurah(selectedSurahID)
                        viewModel.updateSelectedAyah(selectedAyahID)
                        dismiss()
                    }
                    .accessibilityIdentifier("Tilavet.StartPointApplyButton")
                }
            }
            .onChange(of: selectedSurahID) { _, newValue in
                let maxAyah = viewModel.surahs.first(where: { $0.id == newValue })?.totalVerses ?? 1
                selectedAyahID = min(selectedAyahID, maxAyah)
            }
        }
        .accessibilityIdentifier("Tilavet.StartPointSheet")
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
        .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
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
            .lineSpacing(16)
    }
}

private struct StatusPill: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(Color.black.opacity(0.78))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color, in: Capsule())
    }
}

private struct TilavetListenButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .background(
                (isActive ? Color(red: 0.45, green: 0.17, blue: 0.10) : Color(red: 0.18, green: 0.28, blue: 0.17)),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 12)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private struct TilavetTransportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.33, green: 0.18, blue: 0.07))
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.86), in: Capsule())
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

private enum VerseEmphasis {
    case low
    case medium
    case high

    var font: Font {
        switch self {
        case .low:
            return .tilavetQuran(size: 28)
        case .medium:
            return .tilavetQuran(size: 34)
        case .high:
            return .tilavetQuran(size: 46)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .low:
            return Color.black.opacity(0.36)
        case .medium:
            return Color.black.opacity(0.58)
        case .high:
            return Color.black.opacity(0.90)
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
