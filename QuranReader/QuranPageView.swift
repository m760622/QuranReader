//
//  QuranPageView.swift
//  QuranReader
//

import Combine
import CoreText
import SwiftUI
import UIKit
import os

let bundledReaderFontFiles: [String] = [
    "ElgharibA591.otf",
    "ElgharibA597.otf",
    "ElgharibA598.otf",
    "HAFSUthmanicV22.otf",
    "MCSAlshamalAm9li9.otf",
    "NeiriziAm9li9.otf",
    "QuranSaleemAm9li9.otf",
    "RalewayMediumAm9li9.otf",
    "RalewayRegularAm9li9.otf",
    "SulusLettersAm9li9.otf",
    "UthmanTahaBold.otf",
    "UthmanTahaReqular.otf",
]

func buildReaderCustomFontOptions() -> [ReaderCustomFontOption] {
    var options: [ReaderCustomFontOption] = []
    var seenPostScriptNames = Set<String>()

    for fileName in bundledReaderFontFiles {
        let resource = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        let bundledFontURL =
            Bundle.main.url(
                forResource: resource,
                withExtension: ext,
                subdirectory: "Fonts"
            )
            ?? Bundle.main.url(forResource: resource, withExtension: ext)

        guard let url = bundledFontURL else {
            continue
        }

        // Register the font dynamically so the system can render it
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)

        guard
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL)
                as? [CTFontDescriptor]
        else {
            continue
        }

        for descriptor in descriptors {
            guard
                let postScriptName = CTFontDescriptorCopyAttribute(
                    descriptor,
                    kCTFontNameAttribute
                ) as? String,
                !postScriptName.isEmpty
            else {
                continue
            }

            guard seenPostScriptNames.insert(postScriptName).inserted else {
                continue
            }

            options.append(
                ReaderCustomFontOption(
                    postScriptName: postScriptName,
                    displayName: resource
                )
            )
        }
    }

    return options
}

let readerCustomFontOptions: [ReaderCustomFontOption] = buildReaderCustomFontOptions()

func readerCustomFontCategoryTitle(for displayName: String) -> String {
    let lowered = displayName.lowercased()
    if lowered.contains("raleway") {
        return "خطوط لاتينية"
    }
    if lowered.contains("surah name") {
        return "عناوين السور"
    }
    return "خطوط عربية ومصحفية"
}

func buildReaderCustomFontSections() -> [ReaderCustomFontSection] {
    let orderedTitles = ["خطوط عربية ومصحفية", "عناوين السور", "خطوط لاتينية"]
    var buckets: [String: [ReaderCustomFontOption]] = [:]

    for option in readerCustomFontOptions {
        let title = readerCustomFontCategoryTitle(for: option.displayName)
        buckets[title, default: []].append(option)
    }

    return orderedTitles.compactMap { title in
        guard let fonts = buckets[title], !fonts.isEmpty else { return nil }
        return ReaderCustomFontSection(title: title, fonts: fonts)
    }
}

let readerCustomFontSections: [ReaderCustomFontSection] = buildReaderCustomFontSections()

let quranFontCandidates: [String] =
    [
        "KFGQPC Uthmanic Script HAFS",
        "KFGQPC Uthman Taha Naskh",
        "UthmanicHafs",
        "Uthmanic Hafs",
        "Amiri Quran",
        "AmiriQuran-Regular",
        "ScheherazadeNew-Regular",
        "Scheherazade",
    ] + readerCustomFontOptions.map(\.postScriptName)

let readerDiagnosticsLogger = Logger(
    subsystem: "QuranReader", category: "ReaderDiagnostics")

struct ReaderScrollOriginYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SafeAreaInsetsPreferenceKey: PreferenceKey {
    static var defaultValue: EdgeInsets = .init()

    static func reduce(value: inout EdgeInsets, nextValue: () -> EdgeInsets) {
        value = nextValue()
    }
}

struct SafeAreaInsetsReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: SafeAreaInsetsPreferenceKey.self, value: proxy.safeAreaInsets)
        }
    }
}

struct QuranPageView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.scenePhase) var scenePhase
    @StateObject var viewModel = QuranPageViewModel()

    // Auto-Scroll States
    @State var isAutoScrolling = false
    @AppStorage("autoScrollMinutesPerPage") var autoScrollMinutesPerPage: Double = 2.0

    @AppStorage("readerFontSize") var fontSize: Double = 28
    @State var baseFontSizeForGesture: Double? = nil
    @AppStorage("readerLineSpacing") var lineSpacing: Double = 25
    @AppStorage("readerFontSelection") var readerFontSelection: String = "auto"
    @AppStorage("readerFontWeight") var readerFontWeightRawValue: String =
        ReaderFontWeightOption.regular.rawValue
    @AppStorage("readerDayTextColor") var dayTextColorData: Data = Data()
    @AppStorage("readerNightTextColor") var nightTextColorData: Data = Data()
    @AppStorage("readerDayBackgroundColor") var dayBackgroundColorData: Data = Data()
    @AppStorage("readerNightBackgroundColor") var nightBackgroundColorData: Data = Data()
    @AppStorage("readerDayHighlightColor") var dayHighlightColorData: Data = Data()
    @AppStorage("readerNightHighlightColor") var nightHighlightColorData: Data = Data()
    @AppStorage("readerPrimaryColor") var primaryColorData: Data = Data()
    @AppStorage("readerSecondaryColor") var secondaryColorData: Data = Data()
    @AppStorage("readerDayPrimaryColor") var dayPrimaryColorData: Data = Data()
    @AppStorage("readerNightPrimaryColor") var nightPrimaryColorData: Data = Data()
    @AppStorage("readerDaySecondaryColor") var daySecondaryColorData: Data = Data()
    @AppStorage("readerNightSecondaryColor") var nightSecondaryColorData: Data = Data()
    @AppStorage("readerDaySurfaceColor") var daySurfaceColorData: Data = Data()
    @AppStorage("readerNightSurfaceColor") var nightSurfaceColorData: Data = Data()

    @AppStorage("showTranslation") var showTranslation: Bool = false
    @AppStorage("readerMode") var readerModeRawValue: String = ReaderMode.mushafPage.rawValue
    @AppStorage("mushafPageNumber") var storedMushafPageNumber: Int = 1
    @AppStorage("surahChromeCollapsedStates") var surahChromeCollapsedStatesData: Data =
        Data()
    @AppStorage("quickNavigatorMiniTab") var storedQuickNavigatorMiniTabRawValue =
        QuickNavigatorMiniTab.control.rawValue

    @State var showSurahList = false
    @State var showSearch = false
    @State var showVerseBookmarksList = false
    @State var searchText = ""
    @State var searchScope: QuranPageViewModel.SearchScope = .quran
    @State var arabicSearchMatchMode: QuranPageViewModel.ArabicSearchMatchMode = .normalized
    @State var searchResults: [QuranSearchResult] = []
    @State var searchDebounceTask: Task<Void, Never>?
    @State var mushafSearchRange: MushafSearchRange = .all
    @State var readerNavigationState = ReaderNavigationState()
    @State var mushafPreciseScrollRequestID = 0
    @AppStorage("searchHistory") var searchHistoryData: Data = Data()
    @State var searchHistory: [String] = []
    @State var showClearSearchHistoryConfirmation = false
    @State var showQuickNavigator = false
    @State var isFocusMode = false
    @State var autoScrollTask: Task<Void, Never>?
    @State var autoScrollAdvancingSurah = false
    @State var autoScrollCarry: CGFloat = 0
    @State var resolvedScrollView: UIScrollView?
    @State var verseDetailsTab: VerseDetailsTab = .tafsir
    @State var isTopChromeCollapsed = false
    @State var lastTrackedScrollOffset: Double = 0
    @State var pendingScrollHandlingTask: Task<Void, Never>?
    @State var initialRestoreTask: Task<Void, Never>?
    @State var isFloatingMenuHiddenByScroll = false
    @State var floatingMenuRevealTask: Task<Void, Never>?
    @State var topChromeCollapsedBySurah: [String: Bool] = [:]
    @State var hasLoadedPresentationState = false
    @State var checkpointRestoreSurahIndex: Int?
    @State var checkpointRestoreVerseId: Int?
    @State var suppressVerseTracking = false
    @State var resumeVerseTrackingTask: Task<Void, Never>?
    @State var resolvedUthmaniFontName: String?
    @State var hasAttemptedUthmaniFontResolution = false

    @State var surahListQuery = ""
    @State var surahListFilter: SurahListFilter = .all
    @State var showClearFavoritesConfirmation = false
    @State var showClearRecentsConfirmation = false
    @AppStorage("useHaptics") var useHaptics: Bool = true
    @AppStorage("enableReaderDiagnostics") var enableReaderDiagnostics: Bool = false
    @State var jumpSliderValue: Double = 0
    @State var quickNavigatorMiniTab: QuickNavigatorMiniTab = .control
    @State var showSettingsSheet = false
    @AppStorage("showClock") var showClock: Bool = true
    @AppStorage("showBattery") var showBattery: Bool = true
    @State var safeAreaTopInset: CGFloat = 0

    @State var showFloatingActions = false
    @State var toastMessage = ""
    @State var isShowingToast = false
    @State var currentStandardPage: Int? = nil
    @State var mushafPageAnchorYByPage: [Int: CGFloat] = [:]
    @State var mushafIndexByPage: [Int: [MushafSurahSection]] = [:]
    @State var juzPageBoundsByNumber: [Int: (min: Int, max: Int)] = [:]
    @State var pendingMushafScrollTargetPage: Int?
    @State var pendingMushafScrollTargetChunkId: String?
    @State var animatePendingMushafJump: Bool = true
    @State var suppressVerseContextMenusUntil: Date = .distantPast
    @State var lastInteractiveTapAt: Date = .distantPast
    @State var suppressChromeScrollUntil: Date = .distantPast
    @State var lastMushafJumpAt: CFAbsoluteTime = 0
    @State var lastAutoScrollPersistAt: CFAbsoluteTime = 0
    @State var lastMushafScrollThrottledAt: CFAbsoluteTime = 0
    @State var lastMushafVisiblePageSyncAt: CFAbsoluteTime = 0
    @State var lastReaderScrollDelta: Double = 0
    @State var startupMushafRestorePage: Int?
    @State var hasAppliedLaunchRestoreNavigation = false
    @State var hasPerformedInitialMushafScroll = false
    @State var pendingMushafTargetResetTask: Task<Void, Never>?
    @State var fastScrollSettleTask: Task<Void, Never>?
    @State var pendingFastScrollPage: Int?
    @State var pendingMushafPageSyncTask: Task<Void, Never>?
    @State var toastHideTask: Task<Void, Never>?

    // Specific selection for Tafsir sheet to avoid race conditions with scroll tracking
    @State var selectedSurahForInsight: Surah? = nil
    @State var selectedVerseForInsight: Verse? = nil

    // Coordinate space for scroll tracking
    let scrollSpace = "QuranScroll"

    var readerMode: ReaderMode {
        ReaderMode(rawValue: readerModeRawValue) ?? .surah
    }

    var isMushafPageMode: Bool {
        true
    }

    var verseBookmarkRows: [VerseBookmarkRow] {
        viewModel.bookmarkedVerseKeys.compactMap { key in
            let parts = key.split(separator: ":")
            guard parts.count == 2,
                let surahId = Int(parts[0]),
                let verseId = Int(parts[1]),
                let surahIndex = viewModel.surahs.firstIndex(where: { $0.id == surahId })
            else { return nil }

            let surah = viewModel.surahs[surahIndex]
            guard let verse = surah.verses.first(where: { $0.id == verseId }) else { return nil }
            return VerseBookmarkRow(key: key, surahIndex: surahIndex, surah: surah, verse: verse)
        }
        .sorted {
            if $0.surah.id == $1.surah.id {
                return $0.verse.id < $1.verse.id
            }
            return $0.surah.id < $1.surah.id
        }
    }

    func rebuildMushafIndexIfNeeded() {
        guard !viewModel.surahs.isEmpty else {
            mushafIndexByPage = [:]
            juzPageBoundsByNumber = [:]
            return
        }
        var map: [Int: [MushafSurahSection]] = [:]
        var juzPages: [Int: (min: Int, max: Int)] = [:]

        for surah in viewModel.surahs {
            var currentPage: Int? = nil
            var currentGroup: [Verse] = []

            func flush() {
                guard let page = currentPage, !currentGroup.isEmpty else { return }
                map[page, default: []].append(
                    MushafSurahSection(surah: surah, verses: currentGroup))
            }

            for verse in surah.verses {
                if let juzNumber = verse.juz?.number, let page = verse.page {
                    if let existing = juzPages[juzNumber] {
                        juzPages[juzNumber] = (min(existing.min, page), max(existing.max, page))
                    } else {
                        juzPages[juzNumber] = (page, page)
                    }
                }
                guard let page = verse.page else { continue }
                if page != currentPage {
                    flush()
                    currentPage = page
                    currentGroup = [verse]
                } else {
                    currentGroup.append(verse)
                }
            }
            flush()
        }

        mushafIndexByPage = map
        juzPageBoundsByNumber = juzPages
    }

    // Aesthetic Colors
    var backgroundColor: Color {
        let fallbackDay = Color(red: 0.97, green: 0.95, blue: 0.91)
        let fallbackNight = Color(red: 0.1, green: 0.12, blue: 0.15)
        return viewModel.isNightMode
            ? storedColor(from: nightBackgroundColorData, fallback: fallbackNight)
            : storedColor(from: dayBackgroundColorData, fallback: fallbackDay)
    }

    var cardColor: Color {
        let fallbackDay = Color.white.opacity(0.72)
        let fallbackNight = Color.white.opacity(0.06)
        return viewModel.isNightMode
            ? storedColor(from: nightSurfaceColorData, fallback: fallbackNight)
            : storedColor(from: daySurfaceColorData, fallback: fallbackDay)
    }

    var panelStrokeColor: Color {
        (viewModel.isNightMode ? Color.white : primaryGreen).opacity(
            viewModel.isNightMode ? 0.08 : 0.14)
    }

    var panelShadowColor: Color {
        Color.black.opacity(viewModel.isNightMode ? 0.18 : 0.06)
    }

    var textColor: Color {
        let fallbackDay = Color.black
        let fallbackNight = Color(red: 0.9, green: 0.9, blue: 0.9)
        return viewModel.isNightMode
            ? storedColor(from: nightTextColorData, fallback: fallbackNight)
            : storedColor(from: dayTextColorData, fallback: fallbackDay)
    }

    var secondaryTextColor: Color {
        viewModel.isNightMode ? Color.white.opacity(0.65) : Color.black.opacity(0.55)
    }

    var verseHighlightColor: Color {
        let fallbackDay = Color.yellow.opacity(0.34)
        let fallbackNight = Color.orange.opacity(0.34)
        return viewModel.isNightMode
            ? storedColor(from: nightHighlightColorData, fallback: fallbackNight)
            : storedColor(from: dayHighlightColorData, fallback: fallbackDay)
    }

    var primaryGreen: Color {
        let fallback = QuranDesign.primaryGreen
        return viewModel.isNightMode
            ? storedColor(from: nightPrimaryColorData, fallback: fallback)
            : storedColor(from: dayPrimaryColorData, fallback: fallback)
    }

    var secondaryAccentColor: Color {
        let legacy = storedColor(
            from: secondaryColorData, fallback: QuranDesign.secondaryAccentColor)
        return viewModel.isNightMode
            ? storedColor(from: nightSecondaryColorData, fallback: legacy)
            : storedColor(from: daySecondaryColorData, fallback: legacy)
    }

    var readerFontWeight: ReaderFontWeightOption {
        ReaderFontWeightOption(rawValue: readerFontWeightRawValue) ?? .regular
    }

    var readerSystemFontDesign: Font.Design {
        switch readerFontSelection {
        case "system-default":
            return .default
        case "system-rounded":
            return .rounded
        default:
            return .serif
        }
    }

    func resolveCustomFontName() -> String? {
        if readerFontSelection == "auto" {
            for candidate in quranFontCandidates {
                if UIFont(name: candidate, size: CGFloat(fontSize)) != nil {
                    return candidate
                }
            }
            return nil
        }

        if readerFontSelection.hasPrefix("custom:") {
            let name = String(readerFontSelection.dropFirst("custom:".count))
            guard !name.isEmpty else { return nil }
            return UIFont(name: name, size: CGFloat(fontSize)) != nil ? name : nil
        }

        return nil
    }

    var readerVerseFont: Font {
        if let custom = resolveCustomFontName() {
            return .custom(custom, size: fontSize)
        }
        return .system(
            size: fontSize, weight: readerFontWeight.fontWeight, design: readerSystemFontDesign)
    }

    var currentSurahTitle: String {
        // Use the current page to look up the surah name from the mushaf index
        let page = currentStandardPage ?? storedMushafPageNumber
        let sections = mushafSurahSections(for: page)
        var orderedNames: [String] = []
        var seenSurahIDs = Set<Int>()
        for section in sections {
            if seenSurahIDs.insert(section.surah.id).inserted {
                let name = section.surah.name
                    .replacingOccurrences(of: "سورة ", with: "")
                orderedNames.append(name)
            }
        }
        if let firstName = orderedNames.first {
            if orderedNames.count == 1 { return firstName }
            return "\(firstName) +\(orderedNames.count - 1)"
        }
        let fallback = viewModel.currentSurah?.name ?? "..."
        return fallback.replacingOccurrences(of: "سورة ", with: "")
    }

    var progressLabel: String {
        let maxPage = max(viewModel.maxMushafPage, 1)
        let page = min(max(currentStandardPage ?? 1, 1), maxPage)
        return "\(page) / \(maxPage)"
    }

    var currentSurahSubtitle: String {
        let page = currentStandardPage ?? storedMushafPageNumber
        let sections = mushafSurahSections(for: page)
        let ayahCount = sections.reduce(0) { $0 + $1.verses.count }
        guard ayahCount > 0 else {
            // Fallback to viewModel for cases where mushafIndex isn't built yet
            if let surah = viewModel.currentSurah {
                return "\(surah.verses.count) آية"
            }
            return ""
        }
        if sections.count == 1, sections.first != nil {
            return "\(ayahCount) آية بالصفحة"
        }
        return "\(ayahCount) آية • \(sections.count) سور"
    }

    var currentVerseForReadingChrome: Verse? {
        guard let surah = viewModel.currentSurah else { return nil }
        return surah.verses.first(where: { $0.id == viewModel.lastReadVerseId })
            ?? surah.verses.first
    }

    var currentJuzLabel: String {
        if let juz = currentVerseForReadingChrome?.juz?.number {
            return "الجزء \(juz)"
        }
        if let juz = viewModel.currentSurah?.juzNumbers?.first {
            return "الجزء \(juz)"
        }
        return "الجزء -"
    }

    var currentHizbLabel: String {
        guard
            let verse = currentVerseForReadingChrome,
            let juzNumber = verse.juz?.number
        else {
            return "الحزب -"
        }

        guard let rowId = verse.rowId, let bounds = viewModel.juzRowIdBoundsByNumber[juzNumber]
        else {
            return "الحزب \((juzNumber - 1) * 2 + 1)"
        }

        let isSecondHalf = rowId > bounds.mid
        let hizbNumber = (juzNumber - 1) * 2 + (isSecondHalf ? 2 : 1)
        return "الحزب \(hizbNumber)"
        //     return "حزب \(hizbNumber)"

    }

    func formatRemainingTime(seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    var estimatedTimeToFinishCurrentJuzLabel: String {
        guard
            isAutoScrolling,
            let verse = currentVerseForReadingChrome,
            let juzNumber = verse.juz?.number,
            let pageBounds = juzPageBoundsByNumber[juzNumber],
            let currentPage = currentStandardPage ?? verse.page
        else {
            return ""
        }

        let remainingPages = max(0, pageBounds.max - currentPage)
        guard remainingPages > 0 else { return "0:00" }

        // Each page takes `autoScrollMinutesPerPage` minutes — simple and accurate.
        let totalSeconds = Double(remainingPages) * autoScrollMinutesPerPage * 60.0
        return formatRemainingTime(seconds: totalSeconds)
    }

    var topNotchSpacing: CGFloat {
        // Extra offset above the custom top chrome so it clears the notch / Dynamic Island area.
        UIDevice.current.userInterfaceIdiom == .phone ? 6 : 0  // 16
    }

    // A helper to make the iOS sheet background map to Night Mode appropriately natively in older iOS versions
    struct ThemeAwareSheetBackground: ViewModifier {
        let isNightMode: Bool
        func body(content: Content) -> some View {
            if #available(iOS 16.4, *) {
                content.presentationBackground(isNightMode ? Color(white: 0.1) : Color(white: 0.95))
            } else {
                content.background(isNightMode ? Color(white: 0.1) : Color(white: 0.95))
            }
        }
    }

    var hiddenChromeReaderTopInset: CGFloat {
        // The ScrollView already respects the safe area; extra padding here can create a large gap.
        0
    }

    @MainActor
    func refreshSafeAreaTopInset() {
        let topInset: CGFloat = {
            let scenes = UIApplication.shared.connectedScenes
            let windowScenes = scenes.compactMap { $0 as? UIWindowScene }
            let windows = windowScenes.flatMap(\.windows)
            let keyWindow = windows.first(where: { $0.isKeyWindow }) ?? windows.first
            return keyWindow?.safeAreaInsets.top ?? 0
        }()

        if abs(safeAreaTopInset - topInset) > 0.5 {
            safeAreaTopInset = topInset
        }
    }

    func panelSurfaceBackground(cornerRadius: CGFloat = 16) -> some View {
        let startColor =
            viewModel.isNightMode ? Color.white.opacity(0.07) : Color.white.opacity(0.90)
        let endColor = viewModel.isNightMode ? Color.white.opacity(0.03) : cardColor
        let gradient = LinearGradient(
            colors: [startColor, endColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(gradient)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(panelStrokeColor, lineWidth: 1)
            )
            .shadow(color: panelShadowColor, radius: 12, x: 0, y: 6)
    }

    func formattedAyahNumber(_ number: Int) -> String {
        " ﴿\(number)﴾ "
    }

    func verseAttributedString(verse: Verse, isCurrentVerse: Bool) -> AttributedString {
        var combined = AttributedString(verse.text)
        combined.font = .system(size: fontSize, weight: .regular, design: .serif)
        combined.foregroundColor = isCurrentVerse ? primaryGreen : textColor

        var nText = AttributedString(" " + formattedAyahNumber(verse.id) + " ")
        nText.font = .system(size: fontSize * 0.8, weight: .bold, design: .rounded)
        nText.foregroundColor = primaryGreen.opacity(isCurrentVerse ? 1.0 : 0.7)

        combined.append(nText)
        return combined
    }

    var body: some View {
        mainZStack
            .modifier(ReaderBackgroundModifier())
            .modifier(
                ReaderSheetsModifier(
                    showSearch: $showSearch,
                    showSurahList: $showSurahList,
                    showVerseBookmarksList: $showVerseBookmarksList,
                    searchView: AnyView(searchView),
                    surahListView: AnyView(surahListView),
                    verseBookmarksView: AnyView(verseBookmarksView)
                )
            )
            .modifier(
                ReaderLifecycleModifier(
                    viewModel: viewModel,
                    isMushafPageMode: isMushafPageMode,
                    storedMushafPageNumber: $storedMushafPageNumber,
                    jumpSliderValue: $jumpSliderValue,
                    safeAreaTopInset: $safeAreaTopInset,
                    hasPerformedInitialMushafScroll: $hasPerformedInitialMushafScroll,
                    startupMushafRestorePage: $startupMushafRestorePage,
                    currentStandardPage: $currentStandardPage,
                    pendingMushafScrollTargetPage: $pendingMushafScrollTargetPage,
                    topChromeCollapsedBySurah: $topChromeCollapsedBySurah,
                    surahChromeCollapsedStatesData: $surahChromeCollapsedStatesData,
                    quickNavigatorMiniTab: $quickNavigatorMiniTab,
                    storedQuickNavigatorMiniTabRawValue: $storedQuickNavigatorMiniTabRawValue,
                    hasLoadedPresentationState: $hasLoadedPresentationState,
                    rebuildMushafIndex: { rebuildMushafIndexIfNeeded() },
                    captureLaunchCheckpoint: { captureLaunchCheckpointIfNeeded() },
                    applyLaunchRestoreNavigation: { applyLaunchRestoreNavigationIfNeeded() },
                    applyPresentationState: { index in applyPresentationState(forSurahIndex: index)
                    },
                    handleReaderModeDidChange: { handleReaderModeDidChange() }
                )
            )
            .modifier(
                ReaderStateChangeModifier(
                    viewModel: viewModel,
                    isMushafPageMode: isMushafPageMode,
                    storedMushafPageNumber: $storedMushafPageNumber,
                    jumpSliderValue: $jumpSliderValue,
                    currentStandardPage: $currentStandardPage,
                    isTopChromeCollapsed: $isTopChromeCollapsed,
                    showQuickNavigator: $showQuickNavigator,
                    showSearch: $showSearch,
                    showSurahList: $showSurahList,
                    showVerseBookmarksList: $showVerseBookmarksList,
                    quickNavigatorMiniTab: $quickNavigatorMiniTab,
                    hasLoadedPresentationState: hasLoadedPresentationState,
                    saveTopChromeCollapsedState: { val, idx in
                        saveTopChromeCollapsedState(val, forSurahIndex: idx)
                    },
                    handleReaderModeDidChange: { handleReaderModeDidChange() },
                    applyPresentationState: { index in applyPresentationState(forSurahIndex: index)
                    },
                    clearStaleAnchors: { mushafPageAnchorYByPage.removeAll() }
                )
            )
            .modifier(
                ReaderInsightModifier(
                    selectedVerseForInsight: $selectedVerseForInsight,
                    selectedSurahForInsight: $selectedSurahForInsight,
                    isNightMode: viewModel.isNightMode,
                    fontSize: fontSize,
                    lineSpacing: lineSpacing,
                    primaryGreen: primaryGreen,
                    textColor: textColor,
                    secondaryTextColor: secondaryTextColor,
                    cardColor: cardColor,
                    verseDetailsTab: $verseDetailsTab,
                    verseDetailsText: { tab, s, v in verseDetailsText(for: tab, verse: v, in: s) },
                    availableVerseDetailsTabs: { v, s in availableVerseDetailsTabs(for: v, in: s) }
                )
            )
            .modifier(
                ReaderSettingsModifier(
                    showSettingsSheet: $showSettingsSheet,
                    jumpSliderValue: $jumpSliderValue,
                    autoScrollMinutesPerPage: $autoScrollMinutesPerPage,
                    viewModel: viewModel
                )
            )
            .statusBarHidden(!showClock)
    }

    // MARK: - Main Reader

    @ViewBuilder
    func readerContent(for surah: Surah) -> some View {
        ScrollViewReader { proxy in
            mainScrollView(for: surah, proxy: proxy)
        }
    }

    @ViewBuilder
    func mainScrollView(for surah: Surah, proxy: ScrollViewProxy) -> some View {
        ScrollView {
            ScrollViewResolver { scrollView in
                if resolvedScrollView !== scrollView {
                    resolvedScrollView = scrollView
                }
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)

            LazyVStack(spacing: 22) {
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ReaderScrollOriginYPreferenceKey.self,
                            value: geo.frame(in: .named(scrollSpace)).origin.y
                        )
                        .onAppear {
                            captureLaunchCheckpointIfNeeded()
                            initialRestoreTask?.cancel()
                            initialRestoreTask = Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 100_000_000)
                                guard !Task.isCancelled else { return }
                                performInitialMushafScrollIfNeeded(proxy: proxy)
                            }
                        }
                }
                .frame(height: 0)

                Color.clear.frame(height: 1).id("TOP")

                if isMushafPageMode {
                    let maxPage = max(viewModel.maxMushafPage, 1)

                    ForEach(1...maxPage, id: \.self) { page in
                        PageDividerView(
                            surahId: 0,
                            pageNumber: page,
                            primaryGreen: primaryGreen,
                            isNightMode: viewModel.isNightMode,
                            isFirstPage: page == 1,
                            isHidden: false
                        )
                        .id("MUSHAF_PAGE_\(page)")
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        registerMushafPageAnchor(
                                            page: page,
                                            minYInScrollSpace: geo.frame(
                                                in: .named(scrollSpace)
                                            ).minY
                                        )
                                    }
                            }
                        )
                        .onAppear {
                            syncVisibleMushafPage(page)
                        }

                        if let sections = mushafIndexByPage[page], !sections.isEmpty {
                            VStack(alignment: .center, spacing: 12) {
                                ForEach(sections) { section in
                                    if section.verses.first?.id == 1 {
                                        SurahHeaderOrnament(
                                            name: section.surah.name,
                                            color: primaryGreen
                                        )
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.top, 6)
                                    } else {
                                        Text(section.surah.name)
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(secondaryTextColor)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.top, 2)
                                    }

                                    connectedVersesBody(
                                        surah: section.surah,
                                        verses: section.verses,
                                        currentVerseId: (viewModel.currentSurah?.id
                                            == section.surah.id)
                                            ? viewModel.lastReadVerseId
                                            : nil,
                                        horizontalPadding: 0
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(panelSurfaceBackground(cornerRadius: 20))
                            .environment(\.layoutDirection, .rightToLeft)
                        }
                    }
                } else {
                    SurahHeaderOrnament(name: surah.name, color: primaryGreen)
                        .padding(.top, isFocusMode ? 18 : 6)

                    quranTextBox(surah: surah)
                }

                Color.clear.frame(height: 1).id("BOTTOM")
                Spacer(minLength: 260)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        suppressChromeScrollUntil = Date().addingTimeInterval(0.55)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isTopChromeCollapsed.toggle()
                        }
                    }
            )
        }

        .padding(.top, hiddenChromeReaderTopInset)
        .coordinateSpace(name: scrollSpace)
        .onPreferenceChange(ReaderScrollOriginYPreferenceKey.self) { newY in
            handleScrollOffsetGeometryChange(newY)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onChange(of: pendingMushafScrollTargetPage) { _, page in
            guard isMushafPageMode, let page else { return }

            // Record jump time for synchronization timeout
            lastMushafJumpAt = CFAbsoluteTimeGetCurrent()

            let fromPage = currentStandardPage ?? storedMushafPageNumber
            let shouldAnimateJump = abs(fromPage - page) <= 6
            animatePendingMushafJump = shouldAnimateJump
            if shouldAnimateJump {
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo("MUSHAF_PAGE_\(page)", anchor: .top)
                }
            } else {
                proxy.scrollTo("MUSHAF_PAGE_\(page)", anchor: .top)
            }
            pendingMushafTargetResetTask?.cancel()
            pendingMushafTargetResetTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_300_000_000)
                guard !Task.isCancelled else { return }
                if pendingMushafScrollTargetPage == page {
                    pendingMushafScrollTargetPage = nil
                }
            }
        }
        .onChange(of: pendingMushafScrollTargetChunkId) { _, chunkId in
            guard isMushafPageMode, let chunkId else { return }
            Task { @MainActor in
                // Wait a bit for the target page content to layout, then fine-tune scroll.
                try? await Task.sleep(nanoseconds: 240_000_000)
                if animatePendingMushafJump {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        proxy.scrollTo(chunkId, anchor: .top)
                    }
                } else {
                    proxy.scrollTo(chunkId, anchor: .top)
                }
                try? await Task.sleep(nanoseconds: 120_000_000)
                mushafPreciseScrollRequestID &+= 1
                pendingMushafScrollTargetChunkId = nil
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    if baseFontSizeForGesture == nil {
                        baseFontSizeForGesture = fontSize
                    }
                    if let base = baseFontSizeForGesture {
                        // Reduce the sensitivity of the pinch gesture by 50%
                        let dampedValue = 1.0 + (value - 1.0) * 0.5
                        let newSize = base * dampedValue
                        fontSize = min(max(newSize, 18), 50)
                    }
                }
                .onEnded { _ in
                    baseFontSizeForGesture = nil
                }
        )
        .simultaneousGesture(horizontalPageSwipeGesture)
        /*
        .onTapGesture {
            if Date().timeIntervalSince(lastInteractiveTapAt) < 0.25 { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                if showFloatingActions {
                    showFloatingActions = false
                } else {
                    isFocusMode.toggle()
                }
            }
        }
        */
        .onChange(of: isFocusMode) { _, _ in
            DispatchQueue.main.async {
                refreshSafeAreaTopInset()
            }
        }
        .onChange(of: isAutoScrolling) { _, active in
            handleAutoScrollToggle(active: active, proxy: proxy)
        }
        .onChange(of: autoScrollMinutesPerPage) { _, _ in
            // speed changes handled inside the autoScrollTask loop dynamically.
        }
        .onChange(of: fontSize) { _, newSize in
            showToast("حجم الخط: \(Int(newSize))")
        }

    }

    @ViewBuilder
    var mainZStack: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            decorativeBackground

            if let surah = viewModel.currentSurah {
                mainReaderAndChrome(surah: surah)
            } else if let errorMessage = viewModel.dataLoadErrorMessage {
                mainErrorView(message: errorMessage)
            } else {
                mainLoadingView()
            }

            if isShowingToast {
                toastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if isFocusMode {
                focusModeQuickActions
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    var focusModeQuickActions: some View {
        HStack(spacing: 12) {
            // Surah Info Group - Now on the RIGHT (First in RTL HStack)
            VStack(alignment: .leading, spacing: 2) {
                Button {
                    showSurahList = true
                    lightHaptic()
                } label: {
                    HStack(spacing: 4) {
                        Text(currentSurahTitle)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(primaryGreen)
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    // Page Info
                    HStack(spacing: 2) {
                        Text("\(storedMushafPageNumber)")
                            .foregroundColor(secondaryTextColor)
                        Text("ص")
                            .foregroundColor(secondaryTextColor)
                    }

                    Text("•")
                        .foregroundColor(secondaryTextColor.opacity(0.3))

                    // Juz Info
                    HStack(spacing: 2) {
                        let juzLabel = currentJuzLabel.replacingOccurrences(
                            of: "الجزء", with: "جزء")
                        let components = juzLabel.components(separatedBy: " ")
                        if components.count >= 2 {
                            Text(components[components.count - 1])
                                .foregroundColor(primaryGreen)
                            Text(components[0])
                                .foregroundColor(secondaryTextColor)
                        } else {
                            Text(juzLabel)
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
                .font(.system(size: 9, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                if isAutoScrolling && !estimatedTimeToFinishCurrentJuzLabel.isEmpty {
                    Text("\(estimatedTimeToFinishCurrentJuzLabel) د ")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 3)
            .layoutPriority(1)

            Spacer()

            // Action Buttons Group (Close + Quick Actions) - Now on the LEFT (Last in RTL HStack)
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Button {
                        if isAutoScrolling {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAutoScrolling = false
                            }
                        } else {
                            activateReadingModeForAutoScrollIfNeeded(starting: true)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAutoScrolling = true
                            }
                        }
                        lightHaptic()
                    } label: {
                        toolbarIcon(
                            isAutoScrolling ? "pause.fill" : "play.fill", tint: primaryGreen)
                    }

                    Image(systemName: "hare.fill")
                        .foregroundColor(textColor.opacity(0.6))
                        .font(.caption)

                    Slider(value: $autoScrollMinutesPerPage, in: 0.1...3, step: 0.3)
                        .tint(.orange)
                        .frame(width: 90)

                    Image(systemName: "tortoise.fill")
                        .foregroundColor(textColor.opacity(0.6))
                        .font(.caption)
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, viewModel.isNightMode ? .dark : .light)
                        .overlay(
                            Capsule().stroke(primaryGreen.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                )

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isFocusMode = false
                        isTopChromeCollapsed = false
                    }
                    lightHaptic()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(textColor)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, viewModel.isNightMode ? .dark : .light)
                        )
                        .overlay(
                            Circle()
                                .stroke(primaryGreen.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(backgroundColor.opacity(0.95))
        .overlay(Divider().opacity(0.10), alignment: .bottom)
    }

    @ViewBuilder
    func mainReaderAndChrome(surah: Surah) -> some View {
        VStack(spacing: 0) {
            // High-Performance Toolbar Area
            VStack(spacing: 0) {
                if !isFocusMode {
                    ZStack(alignment: .top) {
                        if isTopChromeCollapsed {
                            collapsedTopHandle
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            VStack(spacing: 0) {
                                topNavigationBar

                                if showQuickNavigator {
                                    quickNavigatorPanel
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .zIndex(1)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isTopChromeCollapsed)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showQuickNavigator)

            readerContent(for: surah)
        }
    }

    @ViewBuilder
    func mainErrorView(message: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange.gradient)
                    .symbolEffect(.bounce, value: message)

                Text("عذراً، حدث خطأ ما")
                    .font(.title3.bold())
                    .foregroundColor(textColor)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    lightHaptic()
                    viewModel.reloadData()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("إعادة المحاولة")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(primaryGreen.gradient)
                    .clipShape(Capsule())
                    .shadow(color: primaryGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    func mainLoadingView() -> some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(primaryGreen)

                Text("جارٍ تحميل القرآن...")
                    .font(.headline)
                    .foregroundColor(textColor)

                Text(
                    viewModel.coreLoadStage.userMessage == "جاهز"
                        ? "يرجى الانتظار قليلاً" : viewModel.coreLoadStage.userMessage
                )
                .font(.caption)
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            }
            Spacer()
        }
    }

    var decorativeBackground: some View {
        ZStack {
            VStack {
                Circle()
                    .fill(primaryGreen.opacity(viewModel.isNightMode ? 0.12 : 0.08))
                    .frame(width: 240, height: 240)
                    .blur(radius: 18)
                    .offset(x: -120, y: -80)
                Spacer()
                Circle()
                    .fill(Color.orange.opacity(viewModel.isNightMode ? 0.06 : 0.08))
                    .frame(width: 200, height: 200)
                    .blur(radius: 12)
                    .offset(x: 130, y: 80)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    func decodeBoolMap(_ data: Data) -> [String: Bool] {
        (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    func encodeBoolMap(_ map: [String: Bool]) -> Data {
        (try? JSONEncoder().encode(map)) ?? Data()
    }

    func surahStateKey(for index: Int) -> String {
        String(index)
    }

    func applyPresentationState(forSurahIndex index: Int) {
        guard hasLoadedPresentationState else { return }
        let key = surahStateKey(for: index)
        let desiredTopChromeCollapsed = topChromeCollapsedBySurah[key] ?? false

        animateChrome(.easeInOut(duration: 0.16)) {
            isTopChromeCollapsed = desiredTopChromeCollapsed
        }
    }

    func saveTopChromeCollapsedState(_ value: Bool, forSurahIndex index: Int) {
        var map = topChromeCollapsedBySurah
        map[surahStateKey(for: index)] = value
        topChromeCollapsedBySurah = map
        surahChromeCollapsedStatesData = encodeBoolMap(map)
    }

    func animateChrome(_ animation: Animation?, _ updates: @escaping () -> Void) {
        withAnimation(reduceMotion ? nil : animation, updates)
    }

    func animateFloating(_ animation: Animation?, _ updates: @escaping () -> Void) {
        withAnimation(reduceMotion ? nil : animation, updates)
    }

    var canNavigatePrevious: Bool {
        return (currentStandardPage ?? storedMushafPageNumber) > 1
    }

    var canNavigateNext: Bool {
        return (currentStandardPage ?? storedMushafPageNumber) < max(viewModel.maxMushafPage, 1)
    }

    var pagerCenterLabel: String {
        "\(currentStandardPage ?? 1)"
    }

    func syncMushafPageFromCurrentSelection() {
        let page = viewModel.currentMushafPage
        let maxPage = max(viewModel.maxMushafPage, 1)
        let clamped = min(max(page, 1), maxPage)
        if storedMushafPageNumber != clamped {
            storedMushafPageNumber = clamped
        }
    }

    func goToMushafPage(_ page: Int) {
        let maxPage = max(viewModel.maxMushafPage, 1)
        let clamped = min(max(page, 1), maxPage)
        suppressVerseContextMenusTemporarily()
        storedMushafPageNumber = clamped
        currentStandardPage = clamped
        jumpSliderValue = Double(clamped)
        pendingMushafScrollTargetPage = clamped
        viewModel.jumpToMushafPage(clamped)
    }

    func jumpToSurahSafely(
        index: Int,
        verseId: Int? = nil,
        preferSavedVerse: Bool = false
    ) {
        suppressVerseContextMenusTemporarily()
        viewModel.jumpToSurah(
            index: index,
            verseId: verseId,
            preferSavedVerse: preferSavedVerse
        )
    }

    func mushafPageForSurahStart(surahIndex: Int) -> Int? {
        guard let surah = viewModel.surahs[safe: surahIndex] else { return nil }
        return surah.verses.first?.page
    }

    func mushafPageForVerse(surahIndex: Int, verseId: Int) -> Int? {
        guard let surah = viewModel.surahs[safe: surahIndex] else { return nil }
        return surah.verses.first(where: { $0.id == verseId })?.page ?? surah.verses.first?.page
    }

    func mushafPageForVerse(surahId: Int, verseId: Int) -> Int? {
        guard let surahIndex = viewModel.surahs.firstIndex(where: { $0.id == surahId }) else {
            return nil
        }
        return mushafPageForVerse(surahIndex: surahIndex, verseId: verseId)
    }

    func connectedVerseChunkSize() -> Int {
        50
    }

    func mushafChunkIdForVerse(surahId: Int, page: Int, verseId: Int) -> String? {
        guard let sections = mushafIndexByPage[page] else { return nil }
        guard let section = sections.first(where: { $0.surah.id == surahId }) else { return nil }
        let verses = section.verses
        guard let idx = verses.firstIndex(where: { $0.id == verseId }) else { return nil }
        let chunkSize = connectedVerseChunkSize()
        let start = (idx / chunkSize) * chunkSize
        guard verses.indices.contains(start) else { return nil }
        let chunkFirstVerseId = verses[start].id
        return "CHUNK_S\(surahId)_V\(chunkFirstVerseId)"
    }

    func goToMushafVerse(surahIndex: Int, verseId: Int) {
        guard let surah = viewModel.surahs[safe: surahIndex] else { return }
        let surahId = surah.id
        guard let page = mushafPageForVerse(surahIndex: surahIndex, verseId: verseId) else {
            return
        }
        suppressVerseContextMenusTemporarily()
        setPendingMushafNavigationTarget(surahId: surahId, verseId: verseId)
        mushafPreciseScrollRequestID &+= 1
        viewModel.updateLastReadVerse(verseId)
        pendingMushafScrollTargetChunkId = mushafChunkIdForVerse(
            surahId: surahId,
            page: page,
            verseId: verseId
        )
        pendingMushafScrollTargetPage = page
    }

    func goToMushafVerse(surahId: Int, verseId: Int) {
        guard let surahIndex = viewModel.surahs.firstIndex(where: { $0.id == surahId }) else {
            return
        }
        goToMushafVerse(surahIndex: surahIndex, verseId: verseId)
    }

    var verseContextMenusEnabled: Bool {
        Date() >= suppressVerseContextMenusUntil
    }

    func suppressVerseContextMenusTemporarily(duration: TimeInterval = 0.8) {
        suppressVerseContextMenusUntil = Date().addingTimeInterval(duration)
    }

    func handleReaderModeDidChange() {
        if isMushafPageMode {
            mushafPageAnchorYByPage.removeAll()
            pendingFastScrollPage = nil
            fastScrollSettleTask?.cancel()
            rebuildMushafIndexIfNeeded()
            currentStandardPage = storedMushafPageNumber
            jumpSliderValue = Double(storedMushafPageNumber)
            pendingMushafScrollTargetPage = storedMushafPageNumber
        } else {
            currentStandardPage = viewModel.currentMushafPage
            jumpSliderValue = Double(viewModel.currentMushafPage)
        }
    }

    func navigateNext() {
        let currentPage = currentStandardPage ?? storedMushafPageNumber
        goToMushafPage(currentPage + 1)
    }

    func navigatePrevious() {
        let currentPage = currentStandardPage ?? storedMushafPageNumber
        goToMushafPage(currentPage - 1)
    }

}

#Preview {
    QuranPageView()
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
