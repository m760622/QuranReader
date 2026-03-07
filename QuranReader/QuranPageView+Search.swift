//
//  QuranPageView+Search.swift
//  QuranReader
//
//  Search, Surah list, and bookmarks views extracted from QuranPageView.
//

import SwiftUI

// MARK: - Search, Surah List & Bookmarks
extension QuranPageView {
    // MARK: - Search (Debounced + Indexed)

    var searchView: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("ابحث في القرآن/التفسير/الترجمات...", text: $searchText)
                        .textFieldStyle(.plain)
                        .environment(\.layoutDirection, .rightToLeft)
                        .onAppear {
                            viewModel.ensureSearchIndexLoaded()
                        }
                        .onDisappear {
                            // Optional: viewModel.unloadSearchIndex()
                        }
                        .submitLabel(.search)
                        .onSubmit {
                            recordSearchHistory(query: searchText)
                            scheduleSearch(immediate: true)
                        }
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding()

                Picker("نطاق البحث", selection: $searchScope) {
                    ForEach(QuranPageViewModel.SearchScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if isMushafPageMode {
                    Picker("تصفية النتائج (المصحف)", selection: $mushafSearchRange) {
                        ForEach(MushafSearchRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Text(
                        mushafSearchRange == .currentPage
                            ? "سيتم إظهار النتائج الموجودة في صفحة \(storedMushafPageNumber) فقط."
                            : "سيتم إظهار النتائج من المصحف كله."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)
                    .padding(.top, 4)
                }

                HStack(spacing: 10) {
                    Text("مطابقة العربية")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Picker("مطابقة العربية", selection: $arabicSearchMatchMode) {
                        ForEach(QuranPageViewModel.ArabicSearchMatchMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.horizontal)
                .padding(.top, 4)

                if viewModel.isSearchIndexLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("جاري تجهيز فهرس البحث...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                if let page = mushafPageNumber(from: searchText) {
                    Button {
                        recordSearchHistory(query: searchText)
                        goToMushafPage(page)
                        setActiveVerseHighlight(nil)
                        setPendingMushafNavigationTarget(surahId: nil, verseId: nil)
                        showSearch = false
                        searchText = ""
                        searchResults = []
                        lightHaptic()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(primaryGreen)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("الانتقال إلى صفحة \(page)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text("بحث في المصحف برقم الصفحة")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.left.circle.fill")
                                .foregroundColor(primaryGreen.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(primaryGreen.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)
                        .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                }

                if searchText.count < 2 {
                    if searchHistory.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "text.magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.gray)
                            Text("اكتب حرفين على الأقل للبحث")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        List {
                            Section {
                                ForEach(searchHistory, id: \.self) { entry in
                                    Button {
                                        searchText = entry
                                        scheduleSearch(immediate: true)
                                        lightHaptic()
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .foregroundColor(.secondary)
                                            Text(entry)
                                                .foregroundColor(.primary)
                                                .multilineTextAlignment(.trailing)
                                            Spacer()
                                            Image(systemName: "arrow.up.left")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.vertical, 2)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            removeSearchHistoryEntry(entry)
                                        } label: {
                                            Label("حذف", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("سجل البحث")
                                    Spacer()
                                    Button("مسح") {
                                        showClearSearchHistoryConfirmation = true
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.red)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                } else if searchResults.isEmpty {
                    Spacer()
                    if viewModel.isSearchIndexLoading {
                        Text("جاري تجهيز البحث، انتظر لحظة...")
                            .foregroundColor(.gray)
                    } else {
                        Text("لا توجد نتائج مطابقة")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List(searchResults) { result in
                        Button {
                            let submittedQuery = searchText.trimmingCharacters(
                                in: .whitespacesAndNewlines)
                            recordSearchHistory(query: searchText)
                            let highlight = ReaderVerseHighlightPayload(
                                surahId: result.surahId,
                                verseId: result.verseId,
                                query: submittedQuery,
                                matchMode: arabicSearchMatchMode
                            )
                            if let request = buildVerseNavigationRequest(
                                surahIndex: result.surahIndex,
                                verseId: result.verseId,
                                highlight: highlight
                            ) {
                                performVerseNavigation(request)
                            }
                            showSearch = false
                            searchText = ""
                            searchResults = []
                            lightHaptic()
                        } label: {
                            VStack(alignment: .trailing, spacing: 6) {
                                let showingExternalPreview = result.previewText != nil
                                let preview = result.previewText ?? result.verseText
                                let previewIsLTR =
                                    result.matchSource == .english || result.matchSource == .swedish

                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text(result.surahName)
                                        .font(.headline)
                                        .foregroundColor(primaryGreen)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    Spacer(minLength: 8)

                                    HStack(spacing: 8) {
                                        Text("آية \(result.verseId)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Text("•")
                                            .font(.caption)
                                            .foregroundColor(.secondary.opacity(0.6))

                                        Text(result.matchSource.label)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundColor(
                                                result.matchSource == .tafsir
                                                    ? .orange : primaryGreen
                                            )
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(
                                                (result.matchSource == .tafsir
                                                    ? Color.orange : primaryGreen).opacity(0.12)
                                            )
                                            .clipShape(Capsule())
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .environment(\.layoutDirection, .rightToLeft)
                                Text(highlightedSearchText(preview, query: searchText))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(showingExternalPreview ? 3 : 2)
                                    .multilineTextAlignment(previewIsLTR ? .leading : .trailing)

                                if showingExternalPreview {
                                    Text("الآية: \(result.verseText)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.vertical, 4)
                            .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("البحث")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إغلاق") {
                        searchDebounceTask?.cancel()
                        showSearch = false
                        searchText = ""
                        searchResults = []
                    }
                }
            }
            .confirmationDialog(
                "مسح سجل البحث؟",
                isPresented: $showClearSearchHistoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("مسح الكل", role: .destructive) {
                    clearSearchHistory()
                    lightHaptic()
                }
                Button("إلغاء", role: .cancel) {}
            }
            .onAppear {
                searchScope = .quran
                viewModel.prepareSearchIndexIfNeeded(preferredScope: .all)
                loadSearchHistoryIfNeeded(force: true)
            }
            .onChange(of: searchText) { _, _ in
                scheduleSearch()
            }
            .onChange(of: searchScope) { _, _ in
                viewModel.prepareSearchIndexIfNeeded(preferredScope: searchScope)
                scheduleSearch()
            }
            .onChange(of: arabicSearchMatchMode) { _, _ in
                scheduleSearch()
            }
            .onChange(of: viewModel.searchIndexRevision) { _, _ in
                scheduleSearch()
            }
            .onDisappear {
                searchDebounceTask?.cancel()
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    func loadSearchHistoryIfNeeded(force: Bool = false) {
        guard force || searchHistory.isEmpty else { return }
        if let decoded = try? JSONDecoder().decode([String].self, from: searchHistoryData) {
            searchHistory = decoded
        } else {
            searchHistory = []
        }
    }

    func saveSearchHistory() {
        if let encoded = try? JSONEncoder().encode(searchHistory) {
            searchHistoryData = encoded
        }
    }

    func recordSearchHistory(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        loadSearchHistoryIfNeeded()

        let normalized = trimmed.lowercased()
        searchHistory.removeAll {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
        searchHistory.insert(trimmed, at: 0)
        if searchHistory.count > 24 {
            searchHistory = Array(searchHistory.prefix(24))
        }
        saveSearchHistory()
    }

    func removeSearchHistoryEntry(_ entry: String) {
        loadSearchHistoryIfNeeded()
        let normalized = entry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        searchHistory.removeAll {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
        saveSearchHistory()
    }

    func clearSearchHistory() {
        searchHistory = []
        searchHistoryData = Data()
    }

    func scheduleSearch(immediate: Bool = false) {
        searchDebounceTask?.cancel()
        let query = searchText
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        searchDebounceTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 220_000_000)
            }
            guard !Task.isCancelled else { return }
            let scope = searchScope
            let arabicMode = arabicSearchMatchMode
            let results = viewModel.search(query: query, scope: scope, arabicMatchMode: arabicMode)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if self.searchText == query, self.searchScope == scope,
                    self.arabicSearchMatchMode == arabicMode
                {
                    if self.isMushafPageMode, self.mushafSearchRange == .currentPage {
                        let currentPage = self.storedMushafPageNumber
                        self.searchResults = results.filter { item in
                            self.mushafPageForVerse(surahId: item.surahId, verseId: item.verseId)
                                == currentPage
                        }
                    } else {
                        self.searchResults = results
                    }
                }
            }
        }
    }

    func highlightedSearchText(_ text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { return attributed }

        var searchStart = attributed.startIndex
        while searchStart < attributed.endIndex,
            let range = attributed[searchStart...].range(
                of: trimmedQuery,
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        {
            attributed[range].backgroundColor = .yellow.opacity(0.35)
            attributed[range].foregroundColor = viewModel.isNightMode ? .white : .black
            searchStart = range.upperBound
        }

        return attributed
    }

    func mushafPageNumber(from query: String) -> Int? {
        guard isMushafPageMode else { return nil }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.allSatisfy({ $0.isNumber }) else { return nil }
        guard let number = Int(trimmed) else { return nil }
        let maxPage = max(viewModel.maxMushafPage, 1)
        guard (1...maxPage).contains(number) else { return nil }
        return number
    }

    func normalizedSurahLookupText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var normalized = viewModel.normalizeArabic(trimmed)
        normalized = normalized.replacingOccurrences(of: "سوره", with: "")
        normalized = normalized.replacingOccurrences(of: "سورة", with: "")
        normalized = normalized.replacingOccurrences(of: " ", with: "")
        normalized = normalized.replacingOccurrences(of: "ـ", with: "")
        return normalized
    }

    // MARK: - Surah List (All / Favorites / Recent)

    var filteredSurahRows: [(index: Int, surah: Surah)] {
        let baseRows: [(Int, Surah)]
        switch surahListFilter {
        case .all:
            baseRows = Array(viewModel.surahs.enumerated())
        case .favorites:
            baseRows = Array(viewModel.surahs.enumerated()).filter {
                viewModel.isFavorite(surahId: $0.element.id)
            }
        case .recent:
            baseRows = viewModel.recentSurahIndices.compactMap { index in
                guard viewModel.surahs.indices.contains(index) else { return nil }
                return (index, viewModel.surahs[index])
            }
        }

        let trimmedQuery = surahListQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return baseRows.map { (index: $0.0, surah: $0.1) }
        }

        let normalizedQuery = normalizedSurahLookupText(trimmedQuery)
        let rawDigits = trimmedQuery.filter(\.isNumber)

        return
            baseRows
            .filter { _, surah in
                let normalizedName = normalizedSurahLookupText(surah.name)
                let normalizedNumber = String(surah.id)
                return (!normalizedQuery.isEmpty && normalizedName.contains(normalizedQuery))
                    || (!rawDigits.isEmpty && normalizedNumber.contains(rawDigits))
                    || surah.name.localizedCaseInsensitiveContains(trimmedQuery)
            }
            .map { (index: $0.0, surah: $0.1) }
    }

    var surahListView: some View {
        NavigationView {
            VStack(spacing: 12) {
                VStack(spacing: 10) {
                    Picker("التصفية", selection: $surahListFilter) {
                        ForEach(SurahListFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("ابحث باسم السورة أو رقمها", text: $surahListQuery)
                            .textFieldStyle(.plain)
                            .environment(\.layoutDirection, .rightToLeft)
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        let resumeVerseId =
                            viewModel.preferredVerseIdForSurahIndex(viewModel.currentSurahIndex)
                            ?? viewModel.lastReadVerseId
                        if let request = buildVerseNavigationRequest(
                            surahIndex: viewModel.currentSurahIndex,
                            verseId: resumeVerseId
                        ) {
                            performVerseNavigation(request)
                        }
                        showSurahList = false
                    } label: {
                        HStack {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(primaryGreen)
                            Text("متابعة القراءة: \(currentSurahTitle)")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(progressLabel)
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(primaryGreen.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                List(filteredSurahRows, id: \.index) { row in
                    let index = row.index
                    let surah = row.surah
                    Button {
                        let shouldResumeSavedVerse = (surahListFilter != .all)
                        let targetVerseId =
                            shouldResumeSavedVerse
                            ? (viewModel.preferredVerseIdForSurahIndex(index) ?? 1) : 1
                        let highlight: ReaderVerseHighlightPayload? =
                            shouldResumeSavedVerse
                            ? ReaderVerseHighlightPayload(
                                surahId: surah.id,
                                verseId: targetVerseId,
                                query: "",
                                matchMode: .normalized
                            ) : nil
                        if let request = buildVerseNavigationRequest(
                            surahIndex: index,
                            verseId: targetVerseId,
                            highlight: highlight
                        ) {
                            performVerseNavigation(request)
                        }
                        showSurahList = false
                        lightHaptic()
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(surah.id)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(primaryGreen)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(surah.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("\(surah.verses.count) آية")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if viewModel.isFavorite(surahId: surah.id) {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                            }
                            if viewModel.recentSurahIndices.prefix(5).contains(index) {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if surahListFilter == .favorites, viewModel.isFavorite(surahId: surah.id) {
                            Button(role: .destructive) {
                                viewModel.removeFavorite(surahId: surah.id)
                                lightHaptic()
                            } label: {
                                Label("إزالة", systemImage: "heart.slash")
                            }
                        } else if surahListFilter == .recent {
                            Button(role: .destructive) {
                                viewModel.removeRecentSurahIndex(index)
                                lightHaptic()
                            } label: {
                                Label("حذف", systemImage: "trash")
                            }
                        } else {
                            Button {
                                viewModel.toggleFavorite(surahId: surah.id)
                                lightHaptic()
                            } label: {
                                Label(
                                    viewModel.isFavorite(surahId: surah.id)
                                        ? "إزالة من مفضلة السور" : "إضافة السورة للمفضلة",
                                    systemImage: viewModel.isFavorite(surahId: surah.id)
                                        ? "heart.slash" : "heart"
                                )
                            }
                            .tint(.red)
                        }
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if filteredSurahRows.isEmpty {
                        ContentUnavailableView(
                            "لا توجد نتائج", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .navigationTitle("فهرس السور")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إغلاق") { showSurahList = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            showClearFavoritesConfirmation = true
                        } label: {
                            Label("مسح مفضلة السور", systemImage: "heart.slash")
                        }
                        .disabled(viewModel.favoriteIDs.isEmpty)

                        Button(role: .destructive) {
                            showClearRecentsConfirmation = true
                        } label: {
                            Label("مسح الأخيرة", systemImage: "trash")
                        }
                        .disabled(viewModel.recentSurahIndices.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog(
                "مسح مفضلة السور؟",
                isPresented: $showClearFavoritesConfirmation,
                titleVisibility: .visible
            ) {
                Button("مسح مفضلة السور", role: .destructive) {
                    viewModel.clearFavorites()
                    showToast("تم مسح مفضلة السور")
                    lightHaptic()
                }
                Button("إلغاء", role: .cancel) {}
            }
            .confirmationDialog(
                "مسح الأخيرة؟",
                isPresented: $showClearRecentsConfirmation,
                titleVisibility: .visible
            ) {
                Button("مسح الأخيرة", role: .destructive) {
                    viewModel.clearRecentSurahs()
                    showToast("تم مسح الأخيرة")
                    lightHaptic()
                }
                Button("إلغاء", role: .cancel) {}
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    var verseBookmarksView: some View {
        NavigationView {
            List(verseBookmarkRows) { row in
                Button {
                    let highlight = ReaderVerseHighlightPayload(
                        surahId: row.surah.id,
                        verseId: row.verse.id,
                        query: row.verse.text,
                        matchMode: .exact
                    )
                    if let request = buildVerseNavigationRequest(
                        surahIndex: row.surahIndex,
                        verseId: row.verse.id,
                        highlight: highlight
                    ) {
                        performVerseNavigation(request)
                    }
                    showVerseBookmarksList = false
                    lightHaptic()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(row.surah.name)
                                .font(.headline)
                                .foregroundColor(primaryGreen)
                            Spacer()
                            Text("آية \(row.verse.id)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        Text(row.verse.text)
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.toggleVerseBookmark(surahId: row.surah.id, verseId: row.verse.id)
                        lightHaptic()
                    } label: {
                        Label("إزالة الآية", systemImage: "bookmark.slash")
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if verseBookmarkRows.isEmpty {
                    ContentUnavailableView("لا توجد آيات مفضلة", systemImage: "bookmark")
                }
            }
            .navigationTitle("مفضلة الآيات")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إغلاق") { showVerseBookmarksList = false }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
