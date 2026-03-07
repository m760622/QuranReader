//
//  QuranPageView+Helpers.swift
//  QuranReader
//
//  Navigation helpers and view modifiers extracted from QuranPageView.
//

import SwiftUI

extension QuranPageView {
    // MARK: - Navigation Helpers
    func verseAnchorID(_ verseId: Int) -> String {
        "VERSE_\(verseId)"
    }

    func setActiveVerseHighlight(_ highlight: ReaderVerseHighlightPayload?) {
        readerNavigationState.highlight = highlight
    }

    func setPendingMushafNavigationTarget(surahId: Int?, verseId: Int?) {
        readerNavigationState.targetSurahId = surahId
        readerNavigationState.targetVerseId = verseId
    }

    func buildVerseNavigationRequest(
        surahIndex: Int,
        verseId: Int,
        highlight: ReaderVerseHighlightPayload? = nil
    ) -> ReaderVerseNavigationRequest? {
        guard let surah = viewModel.surahs[safe: surahIndex] else { return nil }
        return ReaderVerseNavigationRequest(
            surahIndex: surahIndex,
            surahId: surah.id,
            verseId: verseId,
            highlight: highlight
        )
    }

    func performVerseNavigation(_ request: ReaderVerseNavigationRequest) {
        lastInteractiveTapAt = Date()
        if isMushafPageMode {
            goToMushafVerse(surahIndex: request.surahIndex, verseId: request.verseId)
        } else {
            jumpToSurahSafely(index: request.surahIndex, verseId: request.verseId)
        }
        setActiveVerseHighlight(request.highlight)
    }

    // MARK: - View Modifiers (Refactored to avoid "Expression too complex")

    struct ReaderBackgroundModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .background(SafeAreaInsetsReader())
        }
    }

    struct ReaderSheetsModifier: ViewModifier {
        @Binding var showSearch: Bool
        @Binding var showSurahList: Bool
        @Binding var showVerseBookmarksList: Bool
        let searchView: AnyView
        let surahListView: AnyView
        let verseBookmarksView: AnyView

        func body(content: Content) -> some View {
            content
                .background(EmptyView().sheet(isPresented: $showSearch) { searchView })
                .background(EmptyView().sheet(isPresented: $showSurahList) { surahListView })
                .background(
                    EmptyView().sheet(isPresented: $showVerseBookmarksList) { verseBookmarksView })
        }
    }

    struct ReaderLifecycleModifier: ViewModifier {
        @ObservedObject var viewModel: QuranPageViewModel
        let isMushafPageMode: Bool
        @Binding var storedMushafPageNumber: Int
        @Binding var jumpSliderValue: Double
        @Binding var safeAreaTopInset: CGFloat
        @Binding var hasPerformedInitialMushafScroll: Bool
        @Binding var startupMushafRestorePage: Int?
        @Binding var currentStandardPage: Int?
        @Binding var pendingMushafScrollTargetPage: Int?
        @Binding var topChromeCollapsedBySurah: [String: Bool]
        @Binding var surahChromeCollapsedStatesData: Data
        @Binding var quickNavigatorMiniTab: QuickNavigatorMiniTab
        @Binding var storedQuickNavigatorMiniTabRawValue: String
        @Binding var hasLoadedPresentationState: Bool

        let rebuildMushafIndex: () -> Void
        let captureLaunchCheckpoint: () -> Void
        let applyLaunchRestoreNavigation: () -> Void
        let applyPresentationState: (Int) -> Void
        let handleReaderModeDidChange: () -> Void

        @Environment(\.scenePhase) var scenePhase

        func body(content: Content) -> some View {
            content
                .onPreferenceChange(SafeAreaInsetsPreferenceKey.self) { insets in
                    if insets.top > 0.5 { safeAreaTopInset = insets.top }
                }
                .onAppear {
                    viewModel.ensureDataLoaded()
                    rebuildMushafIndex()
                    captureLaunchCheckpoint()
                    hasPerformedInitialMushafScroll = false
                    if isMushafPageMode {
                        startupMushafRestorePage = storedMushafPageNumber
                        currentStandardPage = storedMushafPageNumber
                        jumpSliderValue = Double(storedMushafPageNumber)
                        pendingMushafScrollTargetPage = storedMushafPageNumber
                    } else {
                        let page = viewModel.currentMushafPage
                        currentStandardPage = page
                        storedMushafPageNumber = page
                        jumpSliderValue = Double(page)
                    }
                    applyLaunchRestoreNavigation()
                    topChromeCollapsedBySurah =
                        (try? JSONDecoder().decode(
                            [String: Bool].self, from: surahChromeCollapsedStatesData)) ?? [:]
                    quickNavigatorMiniTab =
                        QuickNavigatorMiniTab(rawValue: storedQuickNavigatorMiniTabRawValue)
                        ?? .control
                    hasLoadedPresentationState = true
                    applyPresentationState(viewModel.currentSurahIndex)
                }
                .onChange(of: viewModel.coreLoadStage) { _, newStage in
                    guard newStage == .loaded else { return }
                    rebuildMushafIndex()
                    if isMushafPageMode {
                        handleReaderModeDidChange()
                    } else {
                        currentStandardPage = viewModel.currentMushafPage
                        jumpSliderValue = Double(viewModel.currentMushafPage)
                    }
                    applyLaunchRestoreNavigation()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .inactive || newPhase == .background {
                        viewModel.persistReadingCheckpoint()
                    }
                }
        }
    }

    struct ReaderStateChangeModifier: ViewModifier {
        @ObservedObject var viewModel: QuranPageViewModel
        let isMushafPageMode: Bool
        @Binding var storedMushafPageNumber: Int
        @Binding var jumpSliderValue: Double
        @Binding var currentStandardPage: Int?
        @Binding var isTopChromeCollapsed: Bool
        @Binding var showQuickNavigator: Bool
        @Binding var showSearch: Bool
        @Binding var showSurahList: Bool
        @Binding var showVerseBookmarksList: Bool
        @Binding var quickNavigatorMiniTab: QuickNavigatorMiniTab
        let hasLoadedPresentationState: Bool

        let saveTopChromeCollapsedState: (Bool, Int) -> Void
        let handleReaderModeDidChange: () -> Void
        let applyPresentationState: (Int) -> Void
        let clearStaleAnchors: () -> Void

        func body(content: Content) -> some View {
            content
                .onChange(of: viewModel.currentSurahIndex) { _, newValue in
                    applyPresentationState(newValue)
                }
                .onChange(of: storedMushafPageNumber) { _, newValue in
                    jumpSliderValue = Double(newValue)
                }
                .onChange(of: isTopChromeCollapsed) { _, newValue in
                    guard hasLoadedPresentationState else { return }
                    saveTopChromeCollapsedState(newValue, viewModel.currentSurahIndex)
                }
                .onChange(of: showQuickNavigator) { _, newValue in
                    if newValue && showSurahList { showSurahList = false }
                }
                .onChange(of: showSearch) { _, newValue in
                    if newValue && showSurahList { showSurahList = false }
                }
                .onChange(of: showSurahList) { _, newValue in
                    if newValue {
                        showQuickNavigator = false
                        showSearch = false
                        showVerseBookmarksList = false
                    }
                }
                .onChange(of: quickNavigatorMiniTab) { _, newValue in
                    // (Stored via Binding in parent or directly inside modifier if needed)
                }
        }
    }

    struct ReaderInsightModifier: ViewModifier {
        @Binding var selectedVerseForInsight: Verse?
        @Binding var selectedSurahForInsight: Surah?
        let isNightMode: Bool
        let fontSize: Double
        let lineSpacing: Double
        let primaryGreen: Color
        let textColor: Color
        let secondaryTextColor: Color
        let cardColor: Color
        @Binding var verseDetailsTab: VerseDetailsTab

        let verseDetailsText: (VerseDetailsTab, Surah, Verse) -> String?
        let availableVerseDetailsTabs: (Verse, Surah) -> [VerseDetailsTab]

        func body(content: Content) -> some View {
            content
                .sheet(item: $selectedVerseForInsight) { verse in
                    if let surah = selectedSurahForInsight {
                        TafsirBottomSheet(
                            verse: verse,
                            surah: surah,
                            primaryGreen: primaryGreen,
                            textColor: textColor,
                            fontSize: CGFloat(fontSize),
                            lineSpacing: CGFloat(lineSpacing),
                            verseDetailsTab: $verseDetailsTab,
                            getTafsirText: verseDetailsText,
                            getTabs: availableVerseDetailsTabs,
                            isNightMode: isNightMode,
                            cardColor: cardColor,
                            secondaryTextColor: secondaryTextColor
                        )
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .modifier(ThemeAwareSheetBackground(isNightMode: isNightMode))
                    }
                }
        }
    }

    struct ReaderSettingsModifier: ViewModifier {
        @Binding var showSettingsSheet: Bool
        @Binding var jumpSliderValue: Double
        @Binding var autoScrollMinutesPerPage: Double
        @ObservedObject var viewModel: QuranPageViewModel

        func body(content: Content) -> some View {
            content
                .fullScreenCover(isPresented: $showSettingsSheet) {
                    SettingsSheetView(
                        jumpSliderValue: $jumpSliderValue,
                        autoScrollMinutesPerPage: $autoScrollMinutesPerPage
                    )
                    .environmentObject(viewModel)
                }
        }
    }
}
