//
//  QuranPageView+Rendering.swift
//  QuranReader
//
//  Rendering components and sub-views extracted from QuranPageView.
//

import SwiftUI
import os

extension QuranPageView {
    // MARK: - Components

    @ViewBuilder
    func verseInsightsPanel(surah: Surah) -> some View {
        EmptyView()  // Replaced by TafsirBottomSheet
    }

    /// Replaced inline verseInsightsPanel with a standalone view to be used in `.sheet`
    struct TafsirBottomSheet: View {
        let verse: Verse
        let surah: Surah
        let primaryGreen: Color
        let textColor: Color
        let fontSize: CGFloat
        let lineSpacing: CGFloat
        @Binding var verseDetailsTab: VerseDetailsTab
        let getTafsirText: (VerseDetailsTab, Surah, Verse) -> String?
        let getTabs: (Verse, Surah) -> [VerseDetailsTab]
        let isNightMode: Bool
        let cardColor: Color
        let secondaryTextColor: Color

        var body: some View {
            let tabs = getTabs(verse, surah)
            let selectedTab =
                tabs.contains(verseDetailsTab) ? verseDetailsTab : (tabs.first ?? .tafsir)
            let detailText = getTafsirText(selectedTab, surah, verse)

            VStack(spacing: 16) {
                // Header (Ayah Number, Location info)
                HStack(spacing: 12) {
                    AyahMarker(number: verse.id, color: primaryGreen)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(surah.name) - آية \(verse.id)")
                            .font(.headline)
                            .foregroundColor(textColor)

                        HStack(spacing: 6) {
                            if let page = verse.page {
                                pill(text: "صفحة \(page)", tint: primaryGreen)
                            }
                            if let juz = verse.juz?.number {
                                pill(text: "ج \(juz)", tint: .orange)
                            }
                        }
                    }
                    Spacer()
                }
                .environment(\.layoutDirection, .rightToLeft)

                // Original Verse Text
                Text(verse.text)
                    .font(.system(size: max(18, fontSize * 0.72), weight: .regular, design: .serif))
                    .lineSpacing(max(8, lineSpacing * 0.45))
                    .multilineTextAlignment(.leading)  // right to left
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .environment(\.layoutDirection, .rightToLeft)
                    .padding(.bottom, 8)

                // Tabs
                if tabs.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tabs) { tab in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        verseDetailsTab = tab
                                    }
                                } label: {
                                    Text(tab.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(tab == selectedTab ? .white : textColor)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            tab == selectedTab
                                                ? primaryGreen
                                                : Color.gray.opacity(isNightMode ? 0.25 : 0.15)
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .environment(\.layoutDirection, .rightToLeft)
                    }
                }

                // Detail Content
                if let detailText, !detailText.isEmpty {
                    ScrollView {
                        Text(detailText)
                            .font(selectedTab == .tafsir ? .system(size: 15) : .system(size: 14))
                            .foregroundColor(
                                selectedTab == .tafsir ? textColor : secondaryTextColor
                            )
                            .lineSpacing(6)
                            // In RTL, `.leading` aligns to the visual right edge.
                            .multilineTextAlignment(.leading)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .textSelection(.enabled)
                            .padding(.vertical, 8)
                    }
                    .environment(
                        \.layoutDirection,
                        selectedTab == .tafsir ? .rightToLeft : .leftToRight
                    )
                } else {
                    Text("جاري تحميل التفاصيل...")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            }
            .padding()
            .padding(.top, 12)
        }

        func pill(text: String, tint: Color) -> some View {
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(tint)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(tint.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    func currentVerse(in surah: Surah) -> Verse? {
        surah.verses.first(where: { $0.id == viewModel.lastReadVerseId }) ?? surah.verses.first
    }

    func availableVerseDetailsTabs(for verse: Verse, in surah: Surah) -> [VerseDetailsTab] {
        var tabs: [VerseDetailsTab] = []
        if let t = viewModel.tafsirText(for: surah.id, verseId: verse.id, fallback: verse),
            !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            tabs.append(.tafsir)
        }
        if let t = viewModel.englishTranslationText(
            for: surah.id, verseId: verse.id, fallback: verse),
            !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            tabs.append(.english)
        }
        if let t = viewModel.swedishTranslationText(
            for: surah.id, verseId: verse.id, fallback: verse),
            !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            tabs.append(.swedish)
        }
        return tabs.isEmpty ? [.tafsir] : tabs
    }

    func verseDetailsText(for tab: VerseDetailsTab, verse: Verse, in surah: Surah)
        -> String?
    {
        switch tab {
        case .tafsir:
            return viewModel.tafsirText(for: surah.id, verseId: verse.id, fallback: verse)
        case .english:
            return viewModel.englishTranslationText(
                for: surah.id, verseId: verse.id, fallback: verse)
        case .swedish:
            return viewModel.swedishTranslationText(
                for: surah.id, verseId: verse.id, fallback: verse)
        }
    }

    func activateReadingModeForAutoScrollIfNeeded(starting: Bool) {
        guard starting else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            showQuickNavigator = false
            showFloatingActions = false
            isFocusMode = true
            isTopChromeCollapsed = true
        }
    }

    func quickNavigatorMenuPill<Content: View>(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder menuContent: () -> Content
    ) -> some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(tint.opacity(viewModel.isNightMode ? 0.18 : 0.10))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.22), lineWidth: 1)
                    )
            )
        }
    }

    func quickNavigatorTabChip(_ tab: QuickNavigatorMiniTab) -> some View {
        let isActive = quickNavigatorMiniTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                quickNavigatorMiniTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(tab.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(isActive ? .white : textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(
                        isActive
                            ? primaryGreen : Color.gray.opacity(viewModel.isNightMode ? 0.18 : 0.10)
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                (isActive ? primaryGreen : panelStrokeColor).opacity(0.8),
                                lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    var quickNavigatorPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Text("تنقّل سريع")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(textColor)
                Spacer()
                if let surah = viewModel.currentSurah {
                    HStack(spacing: 6) {
                        Text("سورة \(surah.id) - \(surah.name)")
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(1)
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(QuickNavigatorMiniTab.allCases) { tab in
                    quickNavigatorTabChip(tab)
                }
            }
            .padding(.horizontal, 4)

            if quickNavigatorMiniTab == .control {
                VStack(spacing: 8) {
                    HStack {
                        Text("لوحة تحكم مصغّرة")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(textColor)
                        Spacer()
                        Text("إجراءات سريعة")
                            .font(.caption2)
                            .foregroundColor(secondaryTextColor)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8),
                        ],
                        spacing: 8
                    ) {
                        quickNavigatorActionPill(
                            title: viewModel.isNightMode ? "الوضع الليلي" : "الوضع النهاري",
                            systemImage: viewModel.isNightMode ? "moon.fill" : "sun.max.fill",
                            tint: viewModel.isNightMode ? .yellow : .orange,
                            isActive: viewModel.isNightMode
                        ) {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                viewModel.isNightMode.toggle()
                            }
                            lightHaptic()
                        }

                        quickNavigatorActionPill(
                            title: isAutoScrolling ? "إيقاف التمرير" : "تمرير تلقائي",
                            systemImage: isAutoScrolling ? "pause.fill" : "play.fill",
                            tint: isAutoScrolling ? .orange : primaryGreen,
                            isActive: isAutoScrolling
                        ) {
                            let willStart = !isAutoScrolling
                            activateReadingModeForAutoScrollIfNeeded(starting: willStart)
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isAutoScrolling.toggle()
                            }
                            lightHaptic()
                        }

                        quickNavigatorActionPill(
                            title: "مفضلة السور",
                            systemImage: "heart.fill",
                            tint: .red
                        ) {
                            surahListFilter = .favorites
                            showSurahList = true
                        }

                        quickNavigatorMenuPill(
                            title: "الأخيرة",
                            systemImage: "clock.arrow.circlepath",
                            tint: primaryGreen
                        ) {
                            ForEach(viewModel.recentSurahs(), id: \.id) { surah in
                                Button("\(surah.id) - \(surah.name)") {
                                    if let index = viewModel.surahs.firstIndex(where: {
                                        $0.id == surah.id
                                    }) {
                                        let targetVerseId =
                                            viewModel.preferredVerseIdForSurahIndex(index) ?? 1
                                        if let request = buildVerseNavigationRequest(
                                            surahIndex: index,
                                            verseId: targetVerseId
                                        ) {
                                            performVerseNavigation(request)
                                        }
                                        lightHaptic()
                                    }
                                }
                            }
                            if viewModel.recentSurahs().isEmpty {
                                Text("لا توجد سور أخيرة بعد")
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            viewModel.isNightMode
                                ? Color.white.opacity(0.04) : Color.white.opacity(0.42)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(panelStrokeColor.opacity(0.7), lineWidth: 1)
                        )
                )
                .environment(\.layoutDirection, .rightToLeft)
            }

            if quickNavigatorMiniTab == .control {
                VStack(spacing: 8) {
                    HStack {
                        Text(
                            isMushafPageMode
                                ? "صفحة \(storedMushafPageNumber)"
                                : "سورة \(viewModel.currentSurah?.id ?? (viewModel.currentSurahIndex + 1))"
                        )
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                        Spacer()
                        Text(
                            isMushafPageMode
                                ? "صفحة \(max(viewModel.maxMushafPage, 1))"
                                : "سورة \(max(viewModel.surahs.count, 1))"
                        )
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                    }
                    .environment(\.layoutDirection, .leftToRight)

                    HStack(spacing: 10) {
                        Text("1")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(secondaryTextColor)
                        Slider(
                            value: $jumpSliderValue,
                            in: isMushafPageMode
                                ? 1...Double(max(viewModel.maxMushafPage, 1))
                                : 0...Double(max(viewModel.surahs.count - 1, 0)),
                            step: 1,
                            onEditingChanged: { editing in
                                if !editing {
                                    if isMushafPageMode {
                                        goToMushafPage(Int(jumpSliderValue))
                                    } else {
                                        jumpToSurahSafely(index: Int(jumpSliderValue))
                                    }
                                    lightHaptic()
                                }
                            }
                        )
                        .tint(primaryGreen)
                        .disabled(viewModel.surahs.isEmpty)

                        Text(
                            isMushafPageMode
                                ? "\(max(viewModel.maxMushafPage, 1))"
                                : "\(viewModel.surahs.count)"
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundColor(secondaryTextColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            viewModel.isNightMode
                                ? Color.white.opacity(0.04) : Color.white.opacity(0.45)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(panelStrokeColor.opacity(0.7), lineWidth: 1)
                        )
                )
            }

            if quickNavigatorMiniTab == .reading {
                VStack(spacing: 10) {
                    HStack {
                        Text("إعدادات القراءة")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(textColor)
                        Spacer()
                        Button {
                            fontSize = 28
                            lineSpacing = 25
                            showTranslation = false
                            lightHaptic()
                        } label: {
                            Text("إعادة")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(primaryGreen)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(primaryGreen.opacity(0.10))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 12) {
                        VStack(spacing: 8) {
                            HStack {
                                Text("حجم الخط")
                                    .font(.caption)
                                    .foregroundColor(secondaryTextColor)
                                Spacer()
                                Text("\(Int(fontSize))")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundColor(textColor)
                            }
                            Slider(value: $fontSize, in: 18...50, step: 1)
                                .tint(primaryGreen)
                        }

                        VStack(spacing: 8) {
                            HStack {
                                Text("تباعد")
                                    .font(.caption)
                                    .foregroundColor(secondaryTextColor)
                                Spacer()
                                Text("\(Int(lineSpacing))")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundColor(textColor)
                            }
                            Slider(value: $lineSpacing, in: 10...35, step: 1)
                                .tint(primaryGreen)
                        }

                        Toggle(isOn: $showTranslation) {
                            Label("إظهار الترجمة", systemImage: "captions.bubble")
                                .font(.caption.weight(.semibold))
                        }
                        .tint(primaryGreen)
                        .foregroundColor(textColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                viewModel.isNightMode
                                    ? Color.white.opacity(0.04) : Color.white.opacity(0.45)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(panelStrokeColor.opacity(0.7), lineWidth: 1)
                            )
                    )

                    Button {
                        showSettingsSheet = true
                        lightHaptic()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                            Text("المزيد من الإعدادات")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.gray.opacity(viewModel.isNightMode ? 0.18 : 0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(panelStrokeColor.opacity(0.6), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(panelSurfaceBackground(cornerRadius: 16))
        .environment(\.layoutDirection, .rightToLeft)
    }

    func quranTextBox(surah: Surah, verses: [Verse]? = nil) -> some View {
        let versesToShow = verses ?? surah.verses
        let currentVerseIdForSurah: Int? =
            (viewModel.currentSurah?.id == surah.id) ? viewModel.lastReadVerseId : nil
        return ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    viewModel.isNightMode
                        ? Color(red: 0.15, green: 0.17, blue: 0.20) : Color.white.opacity(0.62)
                )
                .shadow(
                    color: Color.black.opacity(viewModel.isNightMode ? 0.12 : 0.05), radius: 10,
                    x: 0, y: 5)

            VStack(spacing: 0) {
                // --- CONTINUOUS TEXT VIEW FOR STANDARD MODE ---
                connectedVersesBody(
                    surah: surah,
                    verses: versesToShow,
                    currentVerseId: currentVerseIdForSurah,
                    showsPageDividers: true,
                    onPageChange: { page in
                        if currentStandardPage != page {
                            currentStandardPage = page
                            syncVisibleMushafPage(page)
                        }
                    }
                )
                .padding(.horizontal, 12)
                .padding(.top, topNotchSpacing)
                .padding(.bottom, 12)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    func connectedVersesBody(
        surah: Surah,
        verses: [Verse],
        currentVerseId: Int?,
        showsPageDividers: Bool = false,
        horizontalPadding: CGFloat = 16,
        onPageChange: ((Int) -> Void)? = nil
    ) -> some View {
        func resolvedSurahIndex(fallbackSurahId: Int) -> Int? {
            return viewModel.surahs.firstIndex(where: { $0.id == fallbackSurahId })
        }

        let customFontName = resolveCustomFontName()
        let chunkSize = connectedVerseChunkSize()

        return ConnectedVersesView(
            surahId: surah.id,
            verses: verses,
            currentVerseId: currentVerseId,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            showTranslation: showTranslation,
            primaryGreen: primaryGreen,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
            isNightMode: viewModel.isNightMode,
            verseHighlightColor: verseHighlightColor,
            searchHighlightQuery: readerNavigationState.highlight?.query ?? "",
            searchHighlightSurahId: readerNavigationState.highlight?.surahId,
            searchHighlightMode: readerNavigationState.highlight?.matchMode ?? .normalized,
            searchHighlightVerseId: readerNavigationState.highlight?.verseId,
            preciseScrollSurahId: readerNavigationState.targetSurahId,
            preciseScrollVerseId: readerNavigationState.targetVerseId,
            preciseScrollRequestID: mushafPreciseScrollRequestID,
            customFontName: customFontName,
            systemDesign: readerSystemFontDesign,
            fontWeight: readerFontWeight,
            chunkSize: chunkSize,
            contextMenuEnabled: verseContextMenusEnabled,
            showsPageDividers: showsPageDividers,
            isFocusMode: isFocusMode,
            horizontalPadding: horizontalPadding,
            onVerseTap: { _ in
                lastInteractiveTapAt = Date()

                // In focus mode, tap toggles auto-scroll play/pause.
                if isFocusMode {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAutoScrolling.toggle()
                    }
                    return
                }

                // Single tap toggles top chrome between expanded/collapsed states.
                suppressChromeScrollUntil = Date().addingTimeInterval(0.55)
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTopChromeCollapsed.toggle()
                }
            },
            onShowTafsir: { verse in
                lastInteractiveTapAt = Date()
                // Pause auto-scroll while showing tafsir.
                isAutoScrolling = false
                viewModel.ensureSupplementalDataLoaded()

                if let idx = resolvedSurahIndex(fallbackSurahId: surah.id) {
                    viewModel.currentSurahIndex = idx
                    selectedSurahForInsight = viewModel.surahs[idx]
                } else {
                    selectedSurahForInsight = surah
                }
                viewModel.updateLastReadVerse(verse.id)

                selectedVerseForInsight = verse
                lightHaptic()
            },
            isSurahFavorite: {
                viewModel.isFavorite(surahId: surah.id)
            },
            onToggleSurahFavorite: {
                viewModel.toggleFavorite(surahId: surah.id)
                let nowFavorite = viewModel.isFavorite(surahId: surah.id)
                showToast(nowFavorite ? "تمت إضافة السورة للمفضلة" : "تمت إزالة السورة من المفضلة")
                lightHaptic()
            },
            isVerseBookmarked: { verseId in
                viewModel.isVerseBookmarked(surahId: surah.id, verseId: verseId)
            },
            onToggleBookmark: { verse in
                let resolvedSurahId: Int = {
                    if let idx = resolvedSurahIndex(fallbackSurahId: surah.id) {
                        viewModel.currentSurahIndex = idx
                        return viewModel.surahs[idx].id
                    }
                    return surah.id
                }()
                viewModel.updateLastReadVerse(verse.id)
                viewModel.toggleVerseBookmark(surahId: resolvedSurahId, verseId: verse.id)
                let isNowBookmarked =
                    viewModel.isVerseBookmarked(surahId: resolvedSurahId, verseId: verse.id)
                showToast(
                    isNowBookmarked
                        ? "تمت إضافة الآية \(verse.id) من سورة \(surah.name) للمفضلة"
                        : "تمت إزالة الآية \(verse.id) من سورة \(surah.name) من المفضلة"
                )
                lightHaptic()
            },
            onCopyVerse: { verse in
                copyVerseText(verse: verse, in: surah)
            },
            onShareVerse: { verse in
                shareVerse(verse: verse, in: surah)
            },
            onPageChange: onPageChange,
            scrollSpace: scrollSpace,
            onRegisterAnchor: registerMushafPageAnchor,
            onPreciseScrollCompleted: { surahId, verseId in
                guard readerNavigationState.targetSurahId == surahId,
                    readerNavigationState.targetVerseId == verseId
                else { return }
                setPendingMushafNavigationTarget(surahId: nil, verseId: nil)
            }
        )
    }

    struct MushafSurahSection: Identifiable {
        let surah: Surah
        let verses: [Verse]
        var id: Int { surah.id }
    }

    func mushafSurahSections(for pageNumber: Int) -> [MushafSurahSection] {
        mushafIndexByPage[pageNumber] ?? []
    }

    func resetPerSurahPresentationStates() {
        topChromeCollapsedBySurah = [:]
        surahChromeCollapsedStatesData = encodeBoolMap([:])

        applyPresentationState(forSurahIndex: viewModel.currentSurahIndex)
        showToast("تمت إعادة ضبط أوضاع السور إلى الوضع الافتراضي")
        lightHaptic()
    }

    var toastView: some View {
        VStack {
            Text(toastMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(viewModel.isNightMode ? .white : .black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            viewModel.isNightMode
                                ? Color.black.opacity(0.82) : Color.white.opacity(0.92)
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    (viewModel.isNightMode ? Color.white : Color.black).opacity(
                                        0.10), lineWidth: 1)
                        )
                )
                .shadow(color: panelShadowColor.opacity(0.8), radius: 10, x: 0, y: 4)
                .padding(.top, 60)  // Avoid dynamic island

            Spacer()
        }
        .allowsHitTesting(false)
    }

    func shareCurrentAyah() {
        guard let surah = viewModel.currentSurah else { return }
        let activeVerse =
            surah.verses.first(where: { $0.id == viewModel.lastReadVerseId }) ?? surah.verses.first
        let textToShare = activeVerse?.text ?? viewModel.surahText(for: surah)
        if let image = ShareHelper.generateShareableImage(
            ayahText: textToShare,
            surahName: surah.name,
            ayahNumber: activeVerse?.id ?? 1,
            isDarkMode: viewModel.isNightMode
        ) {
            ShareHelper.shareImage(image)
            lightHaptic()
        }
    }

    func shareVerse(verse: Verse, in surah: Surah) {
        let textToShare = verse.text
        if let image = ShareHelper.generateShareableImage(
            ayahText: textToShare,
            surahName: surah.name,
            ayahNumber: verse.id,
            isDarkMode: viewModel.isNightMode
        ) {
            ShareHelper.shareImage(image)
            lightHaptic()
        }
    }

    func copyCurrentSurahText() {
        guard let surah = viewModel.currentSurah else { return }
        UIPasteboard.general.string = viewModel.surahText(for: surah)
        showToast("تم نسخ نص السورة")
        lightHaptic()
    }

    func copyVerseText(verse: Verse, in surah: Surah) {
        let header = "سورة \(surah.name) (\(surah.id)) - آية \(verse.id)"
        UIPasteboard.general.string = "\(header)\n\(verse.text)"
        showToast("تم نسخ الآية")
        lightHaptic()
    }

    func showToast(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isShowingToast = true
        }

        toastHideTask?.cancel()
        toastHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                isShowingToast = false
            }
        }
    }

    func lightHaptic() {
        guard useHaptics else { return }
        #if targetEnvironment(simulator)
            return
        #else
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    func readerDebug(_ message: String) {
        #if DEBUG
            guard enableReaderDiagnostics else { return }
            readerDiagnosticsLogger.debug("\(message, privacy: .public)")
        #endif
    }

    struct ScrollViewResolver: UIViewRepresentable {
        let onResolve: (UIScrollView) -> Void
        let onScroll: (Double) -> Void

        func makeCoordinator() -> Coordinator {
            Coordinator(onScroll: onScroll)
        }

        func makeUIView(context: Context) -> UIView {
            let view = UIView(frame: .zero)
            view.isUserInteractionEnabled = false
            DispatchQueue.main.async { [weak view] in
                guard let view else { return }
                if let scrollView = findScrollView(from: view) {
                    context.coordinator.attach(to: scrollView)
                    onResolve(scrollView)
                }
            }
            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {
            DispatchQueue.main.async { [weak uiView] in
                guard let uiView else { return }
                if let scrollView = findScrollView(from: uiView) {
                    context.coordinator.attach(to: scrollView)
                    onResolve(scrollView)
                }
            }
        }

        func findScrollView(from view: UIView) -> UIScrollView? {
            var node: UIView? = view
            while let current = node {
                if let scroll = current as? UIScrollView { return scroll }
                node = current.superview
            }
            return nil
        }

        final class Coordinator: NSObject {
            private let onScroll: (Double) -> Void
            private weak var observedScrollView: UIScrollView?

            init(onScroll: @escaping (Double) -> Void) {
                self.onScroll = onScroll
            }

            func attach(to scrollView: UIScrollView) {
                guard observedScrollView !== scrollView else { return }
                observedScrollView?.removeObserver(self, forKeyPath: #keyPath(UIScrollView.contentOffset))
                observedScrollView = scrollView
                scrollView.addObserver(
                    self,
                    forKeyPath: #keyPath(UIScrollView.contentOffset),
                    options: [.new],
                    context: nil
                )
            }

            deinit {
                observedScrollView?.removeObserver(self, forKeyPath: #keyPath(UIScrollView.contentOffset))
            }

            override func observeValue(
                forKeyPath keyPath: String?,
                of object: Any?,
                change: [NSKeyValueChangeKey: Any]?,
                context: UnsafeMutableRawPointer?
            ) {
                guard keyPath == #keyPath(UIScrollView.contentOffset),
                    let scrollView = object as? UIScrollView
                else {
                    return
                }
                let offset = Double(max(0, scrollView.contentOffset.y + scrollView.adjustedContentInset.top))
                DispatchQueue.main.async { [onScroll] in
                    onScroll(offset)
                }
            }
        }
    }

}
