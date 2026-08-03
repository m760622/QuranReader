import Combine
import GRDB
import OSLog
import SwiftUI

struct QuranSearchResult: Hashable, Identifiable {
    enum MatchSource: String, Codable, Hashable {
        case verseText
        case surahName
        case tafsir
        case english
        case swedish

        var label: String {
            switch self {
            case .verseText: return "نص الآية"
            case .surahName: return "اسم السورة"
            case .tafsir: return "التفسير"
            case .english: return "EN"
            case .swedish: return "SV"
            }
        }
    }

    let surahIndex: Int
    let surahId: Int
    let surahName: String
    let verseId: Int
    let verseText: String
    let matchSource: MatchSource
    let previewText: String?

    var id: String { "\(surahId):\(verseId)" }
}

final class QuranPageViewModel: ObservableObject {
    private static let logger = Logger(
        subsystem: "nmds.se.QuranReader", category: "QuranPageViewModel")
    enum CoreLoadStage: String {
        case idle
        case locating
        case reading
        case decoding
        case buildingCoreCache
        case applyingCoreData
        case loadingSupplementals
        case loaded
        case failed

        var userMessage: String {
            switch self {
            case .idle: return "جاهز"
            case .locating: return "جاري البحث عن ملفات البيانات..."
            case .reading: return "جاري قراءة ملف القرآن..."
            case .decoding: return "جاري فك بيانات القرآن..."
            case .buildingCoreCache: return "جاري تجهيز بيانات القراءة..."
            case .applyingCoreData: return "جاري عرض النص..."
            case .loadingSupplementals: return "جاري تحميل التفسير والترجمات..."
            case .loaded: return "اكتمل التحميل"
            case .failed: return "تعذر إكمال التحميل"
            }
        }
    }

    enum SearchScope: String, CaseIterable, Identifiable {
        case quran
        case tafsir
        case translations
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .quran: return "القرآن"
            case .all: return "الكل"
            case .tafsir: return "التفسير"
            case .translations: return "الترجمة"
            }
        }
    }

    enum ArabicSearchMatchMode: String, CaseIterable, Identifiable {
        case exact
        case noDiacritics
        case normalized

        var id: String { rawValue }

        var title: String {
            switch self {
            case .exact: return "دقيقة"
            case .noDiacritics: return "بدون تشكيل"
            case .normalized: return "مرنة"
            }
        }
    }

    struct IndexedVerse: Codable {
        let surahIndex: Int
        let surahId: Int
        let surahName: String
        let verseId: Int
        let verseText: String
        let verseTextArabicBare: String
        let verseTextArabic: String
        let surahNameArabicBare: String
        let surahNameArabic: String
        let tafsirArabicBare: String
        let tafsirArabic: String
        let englishFolded: String
        let swedishFolded: String
        let tafsirText: String
        let tafsirPreviewText: String?
        let englishText: String
        let swedishText: String
    }

    struct SearchIndexFile: Decodable {
        let entries: [IndexedVerse]
    }

    enum SearchIndexSegment: String, CaseIterable, Hashable {
        case mushaf
        case tafsir
        case translations

        var prebuiltBaseName: String {
            switch self {
            case .mushaf: return "search_index_mushaf"
            case .tafsir: return "search_index_tafsir"
            case .translations: return "search_index_translations"
            }
        }
    }

    struct CacheBundle {
        let searchIndex: [IndexedVerse]?
        let surahTextCache: [Int: String]
    }

    struct SupplementalTextFile: Decodable {
        let byVerseKey: [String: String]
    }

    struct SupplementalTexts {
        var tafsirByVerseKey: [String: String] = [:]
        var englishByVerseKey: [String: String] = [:]
        var swedishByVerseKey: [String: String] = [:]

        static let empty = SupplementalTexts()

        var hasAnyData: Bool {
            !tafsirByVerseKey.isEmpty || !englishByVerseKey.isEmpty || !swedishByVerseKey.isEmpty
        }
    }

    @Published var surahs: [Surah] = []

    // Persistent Storage
    @Published var currentSurahIndex: Int = UserDefaults.standard.integer(
        forKey: "lastReadSurahIndex")
    {
        didSet {
            UserDefaults.standard.set(currentSurahIndex, forKey: "lastReadSurahIndex")
        }
    }
    @AppStorage("favoriteSurahs") var favoriteSurahsData: Data = Data()
    @AppStorage("recentSurahIndices") var recentSurahsData: Data = Data()
    @AppStorage("bookmarkedVerseKeys") var bookmarkedVerseKeysData: Data = Data()
    @AppStorage("lastReadVerseBySurahIndex") var lastReadVerseBySurahIndexData: Data =
        Data()
    @AppStorage("isNightMode") var isNightMode: Bool = false
    @AppStorage("lastScrollOffset") var lastScrollOffset: Double = 0.0
    @Published var lastReadVerseId: Int =
        UserDefaults.standard.integer(forKey: "lastReadVerseId") == 0
        ? 1 : UserDefaults.standard.integer(forKey: "lastReadVerseId")
    {
        didSet {
            UserDefaults.standard.set(lastReadVerseId, forKey: "lastReadVerseId")
        }
    }

    @AppStorage("surahSortOption") var surahSortOptionData: String = SurahSortOption.standard
        .rawValue
    @Published var surahSortOption: SurahSortOption = .standard {
        didSet {
            surahSortOptionData = surahSortOption.rawValue
        }
    }

    @Published var favoriteIDs: Set<Int> = []
    @Published private(set) var recentSurahIndices: [Int] = []
    @Published private(set) var bookmarkedVerseKeys: Set<String> = []
    @Published private(set) var dataLoadErrorMessage: String?
    @Published private(set) var isCoreDataLoading = false
    @Published private(set) var coreLoadStage: CoreLoadStage = .idle
    @Published private(set) var debugCoreLoadAttempt: Int = 0
    @Published private(set) var debugCoreDataSourcePath: String?
    @Published private(set) var debugCoreLoadDurationMs: Int?
    @Published private(set) var isSupplementalDataLoading = false
    @Published private(set) var hasLoadedSupplementalData = false
    @Published private(set) var isSearchIndexLoading = false
    @Published private(set) var isSearchIndexReady = false
    @Published private(set) var searchIndexRevision: Int = 0
    @Published var pendingScrollSurahIndex: Int?
    @Published var pendingScrollVerseId: Int?
    @Published private(set) var launchRestoreSurahIndex: Int?
    @Published private(set) var launchRestoreVerseId: Int?
    @Published private(set) var maxMushafPage: Int = 604
    @Published private(set) var juzRowIdBoundsByNumber: [Int: JuzRowIdBounds] = [:]

    private let revelationOrderMap: [Int: Int] = [
        96: 1, 68: 2, 73: 3, 74: 4, 1: 5, 111: 6, 81: 7, 87: 8, 92: 9, 89: 10,
        93: 11, 94: 12, 103: 13, 100: 14, 108: 15, 102: 16, 107: 17, 109: 18, 105: 19, 106: 20,
        90: 21, 86: 22, 85: 23, 88: 24, 91: 25, 95: 26, 104: 27, 101: 28, 75: 29, 77: 30,
        50: 31, 67: 32, 53: 33, 84: 34, 79: 35, 82: 36, 78: 37, 56: 38, 80: 39, 29: 40,
        2: 41, 3: 42, 4: 43, 5: 44, 6: 45, 7: 46, 8: 47, 9: 48, 10: 49, 11: 50,
        12: 51, 13: 52, 14: 53, 15: 54, 16: 55, 17: 56, 18: 57, 19: 58, 20: 59, 21: 60,
        22: 61, 23: 62, 24: 63, 25: 64, 26: 65, 27: 66, 28: 67, 30: 68, 31: 69, 32: 70,
        33: 71, 34: 72, 35: 73, 36: 74, 37: 75, 38: 76, 39: 77, 40: 78, 41: 79, 42: 80,
        43: 81, 44: 82, 45: 83, 46: 84, 47: 85, 48: 86, 49: 87, 51: 88, 52: 89, 54: 90,
        55: 91, 57: 92, 58: 93, 59: 94, 60: 95, 61: 96, 62: 97, 63: 98, 64: 99, 65: 100,
        66: 101, 69: 102, 70: 103, 71: 104, 72: 105, 76: 106, 83: 107, 97: 108, 98: 109, 99: 110,
        110: 111, 112: 112, 113: 113, 114: 114,
    ]

    func revelationOrder(for surahId: Int) -> Int {
        revelationOrderMap[surahId] ?? surahId
    }

    var searchIndex: [IndexedVerse] = []
    var surahTextCache: [Int: String] = [:]
    var supplementalTexts: SupplementalTexts = .empty
    var pendingSearchIndexRebuildAfterCurrentBuild = false
    var didAttemptPrebuiltSearchIndexLoad = false
    var searchIndexIncludesSupplementalTexts = false
    var loadedPrebuiltSearchIndexSegments: Set<SearchIndexSegment> = []
    var currentCoreLoadToken = UUID()
    var coreLoadTimeoutWorkItem: DispatchWorkItem?
    var currentCoreLoadStartedAt: Date?
    var hasIssuedInitialCoreLoadRequest = false
    var lastReadVerseBySurahIndex: [Int: Int] = [:]

    // Derived property for the current Surah
    var currentSurah: Surah? {
        guard surahs.indices.contains(currentSurahIndex) else { return nil }
        return surahs[currentSurahIndex]
    }

    init() {
        loadLastReadVerseBySurahIndex()
        if let restored = lastReadVerseBySurahIndex[currentSurahIndex], restored > 0 {
            lastReadVerseId = restored
        }
        launchRestoreSurahIndex = currentSurahIndex
        launchRestoreVerseId = lastReadVerseId
        if let savedSort = SurahSortOption(rawValue: surahSortOptionData) {
            self.surahSortOption = savedSort
        }
        loadFavorites()
        loadRecentSurahs()
        loadBookmarkedVerses()
        loadData()
    }

    func ensureDataLoaded() {
        if surahs.isEmpty && !isCoreDataLoading && dataLoadErrorMessage == nil
            && !hasIssuedInitialCoreLoadRequest
        {
            loadData()
        }
    }

    // Reset offset when moving to a different surah manually
    func jumpToSurah(index: Int, verseId: Int? = nil, preferSavedVerse: Bool = false) {
        guard surahs.indices.contains(index) else { return }
        let resolvedVerseId: Int? = {
            if let verseId { return verseId }
            if preferSavedVerse {
                return preferredVerseIdForSurahIndex(index)
            }
            return nil
        }()
        pendingScrollSurahIndex = index
        pendingScrollVerseId = resolvedVerseId

        if let resolvedVerseId {
            rememberLastReadVerseInMemory(resolvedVerseId, forSurahIndex: index)
        }

        if let resolvedVerseId {
            lastReadVerseId = resolvedVerseId
        } else if let firstVerse = surahs[index].verses.first?.id {
            lastReadVerseId = firstVerse
            rememberLastReadVerseInMemory(firstVerse, forSurahIndex: index)
        } else {
            lastReadVerseId = 1
        }

        if currentSurahIndex == index {
            if verseId == nil {
                lastScrollOffset = 0.0
            }
        } else {
            setCurrentSurahIndex(index, resetScrollOffset: true)
        }
    }

    // MARK: - Load Data
    func loadData(force: Bool = false) {
        if !force && hasIssuedInitialCoreLoadRequest {
            return
        }
        hasIssuedInitialCoreLoadRequest = true
        let token = UUID()
        beginCoreLoadAttempt(token: token)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                self.publishCoreLoadStage(.reading, token: token)

                // Initialize database
                try DatabaseManager.shared.setupDatabase()
                guard let dbReader = DatabaseManager.shared.dbReader else {
                    print("Database reader is not initialized.")
                    return
                }

                self.publishCoreLoadStage(.decoding, token: token)

                var loadedSurahs: [Surah] = []
                try dbReader.read { db in
                    let dbSurahs = try DBSurah.fetchAll(db)
                    for ds in dbSurahs {
                        let dbVerses = try DBVerse.filter(Column("surahId") == ds.id).fetchAll(db)
                        let verses: [Verse] = dbVerses.map { dv in
                            Verse(
                                id: dv.verseId, rowId: dv.rowId, text: dv.text, page: dv.page,
                                juz: JuzInfo(number: dv.juz, name: "الجزء \(dv.juz)"),
                                wordCount: dv.wordCount, tafsirSaadi: nil, translations: nil)
                        }
                        loadedSurahs.append(
                            Surah(
                                id: ds.id, name: ds.name, verseCount: ds.verseCount,
                                pageRange: PageRange(start: ds.pageStart, end: ds.pageEnd),
                                juzNumbers: nil, verses: verses))
                    }
                }

                let computedMaxMushafPage =
                    loadedSurahs
                    .lazy
                    .flatMap(\.verses)
                    .compactMap(\.page)
                    .max() ?? 604

                if loadedSurahs.isEmpty {
                    throw NSError(
                        domain: "QuranReader", code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "قاعدة البيانات فارغة"])
                }

                // Populate Juz Bounds
                var juzBoundsMap: [Int: (min: Int, max: Int)] = [:]
                for surah in loadedSurahs {
                    for verse in surah.verses {
                        if let juzNumber = verse.juz?.number, let rowId = verse.rowId {
                            if let existing = juzBoundsMap[juzNumber] {
                                juzBoundsMap[juzNumber] = (
                                    min(existing.min, rowId), max(existing.max, rowId)
                                )
                            } else {
                                juzBoundsMap[juzNumber] = (rowId, rowId)
                            }
                        }
                    }
                }
                let finalJuzRowIdBounds = juzBoundsMap.reduce(into: [Int: JuzRowIdBounds]()) {
                    partialResult, kv in
                    let (juzNumber, bounds) = kv
                    partialResult[juzNumber] = JuzRowIdBounds(
                        min: bounds.min,
                        max: bounds.max,
                        mid: (bounds.min + bounds.max) / 2
                    )
                }

                DispatchQueue.main.async {
                    guard self.isCurrentCoreLoadToken(token) else { return }
                    self.coreLoadStage = .applyingCoreData
                    self.surahs = loadedSurahs
                    self.maxMushafPage = max(1, computedMaxMushafPage)
                    self.juzRowIdBoundsByNumber = finalJuzRowIdBounds
                    self.dataLoadErrorMessage = nil
                    if !self.surahs.indices.contains(self.currentSurahIndex) {
                        self.currentSurahIndex = 0
                    }

                    // Equivalent to applyCacheBundle missing logic for surahTextCache,
                    // which we can lazily load later in surahText(for:).
                    // We also skip setting up searchIndex array entirely.

                    self.cancelCoreLoadTimeout()
                    self.finishCoreLoadTiming(token: token)
                    self.isCoreDataLoading = false
                    self.coreLoadStage = .loaded
                }

            } catch {
                Self.logger.error(
                    "Database load error: \(String(describing: error), privacy: .public)"
                )

                let userMessage = "فشل تحميل القرآن: \(error.localizedDescription)"

                DispatchQueue.main.async {
                    guard self.isCurrentCoreLoadToken(token) else { return }
                    self.cancelCoreLoadTimeout()
                    self.finishCoreLoadTiming(token: token)
                    self.isCoreDataLoading = false
                    self.coreLoadStage = .failed
                    self.dataLoadErrorMessage = userMessage
                    self.surahs = []
                }
            }
        }
    }

    func publishCoreLoadStage(_ stage: CoreLoadStage, token: UUID) {
        DispatchQueue.main.async {
            guard self.isCurrentCoreLoadToken(token) else { return }
            self.coreLoadStage = stage
        }
    }

    func isCurrentCoreLoadToken(_ token: UUID) -> Bool {
        currentCoreLoadToken == token
    }

    func cancelCoreLoadTimeout() {
        coreLoadTimeoutWorkItem?.cancel()
        coreLoadTimeoutWorkItem = nil
    }

    func finishCoreLoadTiming(token: UUID) {
        guard isCurrentCoreLoadToken(token), let startedAt = currentCoreLoadStartedAt else {
            return
        }
        debugCoreLoadDurationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
    }

    func scheduleCoreLoadTimeout(for token: UUID) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.isCurrentCoreLoadToken(token), self.isCoreDataLoading else { return }
            self.finishCoreLoadTiming(token: token)
            self.isCoreDataLoading = false
            self.coreLoadStage = .failed
            self.dataLoadErrorMessage =
                "انتهت مهلة تحميل بيانات القرآن. تحقق من ملفات JSON داخل Target Membership ثم أعد المحاولة."
        }
        coreLoadTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
    }

    func reloadData() {
        loadData(force: true)
    }

    func beginCoreLoadAttempt(token: UUID) {
        let apply = {
            self.currentCoreLoadToken = token
            self.cancelCoreLoadTimeout()
            self.scheduleCoreLoadTimeout(for: token)
            self.currentCoreLoadStartedAt = Date()
            self.debugCoreLoadAttempt &+= 1
            self.debugCoreLoadDurationMs = nil
            self.debugCoreDataSourcePath = nil
            self.dataLoadErrorMessage = nil
            self.isCoreDataLoading = true
            self.coreLoadStage = .locating
            self.isSupplementalDataLoading = false
            self.hasLoadedSupplementalData = false
            self.isSearchIndexLoading = false
            self.isSearchIndexReady = false
            self.supplementalTexts = .empty
            self.searchIndex = []
            self.pendingSearchIndexRebuildAfterCurrentBuild = false
            self.didAttemptPrebuiltSearchIndexLoad = false
            self.searchIndexIncludesSupplementalTexts = false
            self.loadedPrebuiltSearchIndexSegments = []
            self.searchIndexRevision &+= 1
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.sync(execute: apply)
        }
    }

    // MARK: - Favorites Management

    func loadFavorites() {
        if let decoded = try? JSONDecoder().decode(Set<Int>.self, from: favoriteSurahsData) {
            self.favoriteIDs = decoded
        }
    }

    func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteIDs) {
            favoriteSurahsData = encoded
        }
    }

    func loadRecentSurahs() {
        if let decoded = try? JSONDecoder().decode([Int].self, from: recentSurahsData) {
            recentSurahIndices = decoded
        }
    }

    func saveRecentSurahs() {
        if let encoded = try? JSONEncoder().encode(recentSurahIndices) {
            recentSurahsData = encoded
        }
    }

    func loadLastReadVerseBySurahIndex() {
        if let decoded = try? JSONDecoder().decode(
            [Int: Int].self, from: lastReadVerseBySurahIndexData)
        {
            lastReadVerseBySurahIndex = decoded.filter { $0.key >= 0 && $0.value > 0 }
            return
        }
        if let legacy = try? JSONDecoder().decode(
            [String: Int].self, from: lastReadVerseBySurahIndexData)
        {
            var restored: [Int: Int] = [:]
            for (key, value) in legacy {
                guard let index = Int(key), index >= 0, value > 0 else { continue }
                restored[index] = value
            }
            lastReadVerseBySurahIndex = restored
        }
    }

    func saveLastReadVerseBySurahIndex() {
        if let encoded = try? JSONEncoder().encode(lastReadVerseBySurahIndex) {
            lastReadVerseBySurahIndexData = encoded
        }
    }

    func rememberLastReadVerseInMemory(_ verseId: Int, forSurahIndex index: Int) {
        guard index >= 0, verseId > 0 else { return }
        lastReadVerseBySurahIndex[index] = verseId
    }

    func preferredVerseIdForSurahIndex(_ index: Int) -> Int? {
        guard index >= 0 else { return nil }
        let remembered = lastReadVerseBySurahIndex[index]
        guard surahs.indices.contains(index) else { return remembered }
        let verses = surahs[index].verses
        if let remembered, verses.contains(where: { $0.id == remembered }) {
            return remembered
        }
        return verses.first?.id
    }

    func isFavorite(surahId: Int) -> Bool {
        favoriteIDs.contains(surahId)
    }

    func toggleFavorite(surahId: Int) {
        if favoriteIDs.contains(surahId) {
            favoriteIDs.remove(surahId)
        } else {
            favoriteIDs.insert(surahId)
        }
        saveFavorites()
    }

    func removeFavorite(surahId: Int) {
        guard favoriteIDs.contains(surahId) else { return }
        favoriteIDs.remove(surahId)
        saveFavorites()
    }

    func clearFavorites() {
        guard !favoriteIDs.isEmpty else { return }
        favoriteIDs.removeAll()
        saveFavorites()
    }

    func removeRecentSurahIndex(_ index: Int) {
        guard recentSurahIndices.contains(index) else { return }
        recentSurahIndices.removeAll { $0 == index }
        saveRecentSurahs()
    }

    func clearRecentSurahs() {
        guard !recentSurahIndices.isEmpty else { return }
        recentSurahIndices.removeAll()
        saveRecentSurahs()
    }

    // MARK: - Verse Bookmarks (مفضلة الآيات)

    func bookmarkKey(surahId: Int, verseId: Int) -> String {
        "\(surahId):\(verseId)"
    }

    func loadBookmarkedVerses() {
        if let decoded = try? JSONDecoder().decode(Set<String>.self, from: bookmarkedVerseKeysData)
        {
            bookmarkedVerseKeys = decoded
        }
    }

    func saveBookmarkedVerses() {
        if let encoded = try? JSONEncoder().encode(bookmarkedVerseKeys) {
            bookmarkedVerseKeysData = encoded
        }
    }

    func isVerseBookmarked(surahId: Int, verseId: Int) -> Bool {
        bookmarkedVerseKeys.contains(bookmarkKey(surahId: surahId, verseId: verseId))
    }

    func toggleVerseBookmark(surahId: Int, verseId: Int) {
        let key = bookmarkKey(surahId: surahId, verseId: verseId)
        if bookmarkedVerseKeys.contains(key) {
            bookmarkedVerseKeys.remove(key)
        } else {
            bookmarkedVerseKeys.insert(key)
        }
        saveBookmarkedVerses()
    }

    func clearVerseBookmarks() {
        guard !bookmarkedVerseKeys.isEmpty else { return }
        bookmarkedVerseKeys.removeAll()
        saveBookmarkedVerses()
    }

    // MARK: - Navigation Intents
    func nextPage() {
        guard currentSurahIndex < surahs.count - 1 else { return }
        pendingScrollSurahIndex = nil
        pendingScrollVerseId = nil
        lastReadVerseId = 1
        setCurrentSurahIndex(currentSurahIndex + 1, resetScrollOffset: true)
    }

    func previousPage() {
        guard currentSurahIndex > 0 else { return }
        pendingScrollSurahIndex = nil
        pendingScrollVerseId = nil
        lastReadVerseId = 1
        setCurrentSurahIndex(currentSurahIndex - 1, resetScrollOffset: true)
    }

    var readingProgress: Double {
        guard !surahs.isEmpty else { return 0 }
        return Double(currentSurahIndex + 1) / Double(surahs.count)
    }

    var juzProgress: Double {
        guard let surah = currentSurah,
            let verse = surah.verses.first(where: { $0.id == lastReadVerseId }),
            let juzNumber = verse.juz?.number,
            let rowId = verse.rowId,
            let bounds = juzRowIdBoundsByNumber[juzNumber]
        else {
            return 0
        }
        let total = Double(bounds.max - bounds.min)
        guard total > 0 else { return 0 }
        return Double(rowId - bounds.min) / total
    }

    var currentMushafPage: Int {
        guard let surah = currentSurah else { return 1 }
        if let verse = surah.verses.first(where: { $0.id == lastReadVerseId }),
            let page = verse.page
        {
            return page
        }
        return surah.verses.compactMap(\.page).first ?? 1
    }

    func surahText(for surah: Surah) -> String {
        if let cached = surahTextCache[surah.id] {
            return cached
        }
        let text = surah.verses.map(\.text).joined(separator: " ")
        surahTextCache[surah.id] = text
        return text
    }

    func recentSurahs(limit: Int = 6) -> [Surah] {
        recentSurahIndices.prefix(limit).compactMap { index in
            surahs.indices.contains(index) ? surahs[index] : nil
        }
    }

    func search(
        query: String,
        scope: SearchScope = .all,
        arabicMatchMode: ArabicSearchMatchMode = .normalized,
        limit: Int = 50
    ) -> [QuranSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { return [] }
        guard !surahs.isEmpty, let dbReader = DatabaseManager.shared.dbReader else { return [] }

        let queryLooksArabic = containsArabic(trimmedQuery)
        let arabicQuery: String = {
            switch arabicMatchMode {
            case .exact: return trimmedQuery
            case .noDiacritics: return stripArabicDiacriticsAndMarks(trimmedQuery)
            case .normalized: return normalizeArabic(trimmedQuery)
            }
        }()

        do {
            return try dbReader.read { db in
                var results: [QuranSearchResult] = []

                // Construct the SQL LIKE clause based on the scope and script
                var conditions: [SQLSpecificExpressible] = []

                if queryLooksArabic {
                    let verseCol = Column(
                        arabicMatchMode == .exact ? "verseText" : "verseTextArabicBare"
                    )
                    let surahCol = Column(
                        arabicMatchMode == .exact ? "surahName" : "surahNameArabicBare"
                    )
                    let tafsirCol = Column(
                        arabicMatchMode == .exact ? "tafsirText" : "tafsirTextArabicBare"
                    )

                    if scopeAllows(scope, .verseText) {
                        conditions.append(verseCol.like("%\(arabicQuery)%"))
                    }
                    if scopeAllows(scope, .surahName) {
                        conditions.append(surahCol.like("%\(arabicQuery)%"))
                    }
                    if scopeAllows(scope, .tafsir) {
                        conditions.append(tafsirCol.like("%\(arabicQuery)%"))
                    }
                } else {
                    let englishCol = Column("englishText")
                    let swedishCol = Column("swedishText")

                    if scopeAllows(scope, .english) {
                        conditions.append(englishCol.like("%\(trimmedQuery)%"))
                    }
                    if scopeAllows(scope, .swedish) {
                        conditions.append(swedishCol.like("%\(trimmedQuery)%"))
                    }

                    if scopeAllows(scope, .surahName) {
                        conditions.append(Column("surahId").like("%\(trimmedQuery)%"))
                    }
                }

                guard !conditions.isEmpty else { return [] }

                let combinedCondition = conditions.joined(operator: .or)

                let matches = try DBSearchIndex.filter(combinedCondition).limit(limit).fetchAll(db)

                var seen = Set<String>()
                for entry in matches {
                    let key = "\(entry.surahId):\(entry.verseId)"
                    guard seen.insert(key).inserted else { continue }

                    guard
                        let resolvedSurahIndex = surahs.firstIndex(where: { $0.id == entry.surahId }
                        )
                    else { continue }

                    // Determine match source heuristically based on the query since SQLite LIKE condition triggered it
                    var matchSource: QuranSearchResult.MatchSource = .verseText
                    if !queryLooksArabic {
                        if entry.englishText?.localizedCaseInsensitiveContains(trimmedQuery) == true
                        {
                            matchSource = .english
                        } else if entry.swedishText?.localizedCaseInsensitiveContains(trimmedQuery)
                            == true
                        {
                            matchSource = .swedish
                        } else {
                            matchSource = .surahName
                        }
                    } else {
                        if entry.verseText.contains(trimmedQuery)
                            || entry.verseTextArabicBare.contains(arabicQuery)
                        {
                            matchSource = .verseText
                        } else if entry.surahName.contains(trimmedQuery)
                            || (entry.surahNameArabicBare?.contains(arabicQuery) == true)
                        {
                            matchSource = .surahName
                        } else if (entry.tafsirText?.contains(trimmedQuery) == true)
                            || (entry.tafsirTextArabicBare?.contains(arabicQuery) == true)
                        {
                            matchSource = .tafsir
                        }
                    }

                    results.append(
                        QuranSearchResult(
                            surahIndex: resolvedSurahIndex,
                            surahId: entry.surahId,
                            surahName: entry.surahName,
                            verseId: entry.verseId,
                            verseText: entry.verseText,
                            matchSource: matchSource,
                            previewText: previewText(
                                for: matchSource, entry: entry, query: trimmedQuery)
                        )
                    )
                }

                return results
            }
        } catch {
            Self.logger.error("Search error: \(String(describing: error))")
            return []
        }
    }

    func prepareSearchIndexIfNeeded(force: Bool = false, preferredScope: SearchScope = .all) {
        guard !surahs.isEmpty else { return }
        let requiredSegments = requiredSearchIndexSegments(for: preferredScope)

        if isSearchIndexLoading {
            if force {
                pendingSearchIndexRebuildAfterCurrentBuild = true
            }
            return
        }

        if !force && hasSearchIndexCoverage(for: preferredScope) {
            return
        }
        if force && isSearchIndexReady && searchIndexIncludesSupplementalTexts {
            return
        }

        isSearchIndexLoading = true
        let surahsSnapshot = surahs
        let supplementalSnapshot = supplementalTexts
        let includesSupplementals = supplementalSnapshot.hasAnyData
        let shouldTryPrebuilt = !force
        if shouldTryPrebuilt {
            didAttemptPrebuiltSearchIndexLoad = true
        }
        let existingPrebuiltSegments = loadedPrebuiltSearchIndexSegments
        let existingEntries =
            (isSearchIndexReady && !searchIndex.isEmpty && !existingPrebuiltSegments.isEmpty)
            ? searchIndex : []

        DispatchQueue.global(qos: .userInitiated).async {
            let result:
                (
                    entries: [IndexedVerse], includesSupplementals: Bool,
                    loadedSegments: Set<SearchIndexSegment>
                )
            if shouldTryPrebuilt,
                let prebuilt = self.loadPrebuiltSearchIndex(
                    requiredSegments: requiredSegments,
                    existingSegments: existingPrebuiltSegments,
                    existingEntries: existingEntries
                )
            {
                result = prebuilt
            } else {
                result = (
                    entries: self.buildSearchIndex(
                        from: surahsSnapshot, supplementals: supplementalSnapshot),
                    includesSupplementals: includesSupplementals,
                    loadedSegments: []
                )
            }
            DispatchQueue.main.async {
                self.searchIndex = result.entries
                self.isSearchIndexLoading = false
                self.isSearchIndexReady = true
                self.searchIndexIncludesSupplementalTexts = result.includesSupplementals
                self.loadedPrebuiltSearchIndexSegments = result.loadedSegments
                self.searchIndexRevision &+= 1

                if self.pendingSearchIndexRebuildAfterCurrentBuild {
                    self.pendingSearchIndexRebuildAfterCurrentBuild = false
                    self.prepareSearchIndexIfNeeded(force: true, preferredScope: preferredScope)
                }
            }
        }
    }

    func scopeAllows(_ scope: SearchScope, _ source: QuranSearchResult.MatchSource) -> Bool {
        switch scope {
        case .all:
            return true
        case .quran:
            return source == .verseText || source == .surahName
        case .tafsir:
            return source == .tafsir
        case .translations:
            return source == .english || source == .swedish
        }
    }

    func requiredSearchIndexSegments(for scope: SearchScope) -> Set<SearchIndexSegment> {
        switch scope {
        case .all:
            return Set(SearchIndexSegment.allCases)
        case .quran:
            // Quran text search requires the Mushaf segment (prebuilt normalized verse fields).
            return [.mushaf]
        case .tafsir:
            return [.tafsir]
        case .translations:
            return [.translations]
        }
    }

    func hasSearchIndexCoverage(for scope: SearchScope) -> Bool {
        guard isSearchIndexReady, !searchIndex.isEmpty else { return false }
        if loadedPrebuiltSearchIndexSegments.isEmpty {
            return true
        }
        return loadedPrebuiltSearchIndexSegments.isSuperset(
            of: requiredSearchIndexSegments(for: scope))
    }

    func updateLastReadVerse(_ verseId: Int) {
        guard verseId > 0, lastReadVerseId != verseId else { return }
        lastReadVerseId = verseId
        rememberLastReadVerseInMemory(verseId, forSurahIndex: currentSurahIndex)
    }

    func jumpToMushafPage(_ page: Int) {
        guard !surahs.isEmpty else { return }
        let clamped = min(max(page, 1), max(maxMushafPage, 1))

        for (index, surah) in surahs.enumerated() {
            if let verse = surah.verses.first(where: { $0.page == clamped }) {
                pendingScrollSurahIndex = index
                pendingScrollVerseId = verse.id
                setCurrentSurahIndex(index, resetScrollOffset: true)
                lastReadVerseId = verse.id
                rememberLastReadVerseInMemory(verse.id, forSurahIndex: index)
                return
            }
        }

        pendingScrollSurahIndex = nil
        pendingScrollVerseId = nil
    }

    func persistReadingCheckpoint() {
        guard let currentSurah else { return }

        // In continuous Mushaf mode, currentSurahIndex may lag behind visible reading position.
        // Avoid force-resetting to verse 1 when IDs temporarily mismatch.
        if !currentSurah.verses.contains(where: { $0.id == lastReadVerseId }),
            let preferred = preferredVerseIdForSurahIndex(currentSurahIndex),
            currentSurah.verses.contains(where: { $0.id == preferred })
        {
            lastReadVerseId = preferred
        }

        // Touching AppStorage-backed values here makes the checkpoint explicit at app lifecycle boundaries.
        currentSurahIndex = min(max(currentSurahIndex, 0), max(surahs.count - 1, 0))
        lastScrollOffset = max(0, lastScrollOffset)
        if currentSurah.verses.contains(where: { $0.id == lastReadVerseId }) {
            rememberLastReadVerseInMemory(lastReadVerseId, forSurahIndex: currentSurahIndex)
        }
        saveLastReadVerseBySurahIndex()
    }

    func clearPendingScrollRequest() {
        pendingScrollSurahIndex = nil
        pendingScrollVerseId = nil
    }

    func consumeLaunchRestoreCheckpoint() -> (surahIndex: Int, verseId: Int)? {
        guard let surahIndex = launchRestoreSurahIndex, let verseId = launchRestoreVerseId else {
            return nil
        }
        launchRestoreSurahIndex = nil
        launchRestoreVerseId = nil
        return (surahIndex, verseId)
    }

    func tafsirText(for surahId: Int, verseId: Int, fallback verse: Verse? = nil) -> String? {
        guard let dbReader = DatabaseManager.shared.dbReader else { return nil }
        do {
            let rowId = verse?.rowId ?? (surahId * 1000) + verseId
            return try dbReader.read { db in
                try DBTafsir.fetchOne(db, key: rowId)?.text
            }
        } catch {
            return nil
        }
    }

    func englishTranslationText(for surahId: Int, verseId: Int, fallback verse: Verse? = nil)
        -> String?
    {
        guard let dbReader = DatabaseManager.shared.dbReader else { return nil }
        do {
            let rowId = verse?.rowId ?? (surahId * 1000) + verseId
            return try dbReader.read { db in
                try DBTranslation.filter(
                    Column("verseRowId") == rowId && Column("languageCode") == "en"
                ).fetchOne(db)?.text
            }
        } catch {
            return nil
        }
    }

    func swedishTranslationText(for surahId: Int, verseId: Int, fallback verse: Verse? = nil)
        -> String?
    {
        guard let dbReader = DatabaseManager.shared.dbReader else { return nil }
        do {
            let rowId = verse?.rowId ?? (surahId * 1000) + verseId
            return try dbReader.read { db in
                try DBTranslation.filter(
                    Column("verseRowId") == rowId && Column("languageCode") == "sv"
                ).fetchOne(db)?.text
            }
        } catch {
            return nil
        }
    }

    func setCurrentSurahIndex(_ newIndex: Int, resetScrollOffset: Bool) {
        guard surahs.indices.contains(newIndex) else { return }
        guard currentSurahIndex != newIndex else { return }
        currentSurahIndex = newIndex
        if resetScrollOffset {
            lastScrollOffset = 0.0
        }
        recordRecentSurah(index: newIndex)
    }

    func recordRecentSurah(index: Int) {
        guard index >= 0 else { return }
        recentSurahIndices.removeAll { $0 == index }
        recentSurahIndices.insert(index, at: 0)
        if recentSurahIndices.count > 12 {
            recentSurahIndices = Array(recentSurahIndices.prefix(12))
        }
        saveRecentSurahs()
    }

    func locateJSONURL(baseNames: [String]) -> URL? {
        for baseName in baseNames {
            if let direct = Bundle.main.url(forResource: baseName, withExtension: "json") {
                return direct
            }
        }

        let expectedFileNames = Set(baseNames.map { "\($0).json".lowercased() })

        if let candidates = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil),
            let match = candidates.first(where: {
                expectedFileNames.contains($0.lastPathComponent.lowercased())
            })
        {
            return match
        }

        if let resourceRoot = Bundle.main.resourceURL {
            let enumerator = FileManager.default.enumerator(
                at: resourceRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            while let item = enumerator?.nextObject() as? URL {
                guard item.pathExtension.lowercased() == "json" else { continue }
                if expectedFileNames.contains(item.lastPathComponent.lowercased()) {
                    return item
                }
            }
        }

        return nil
    }

    func ensureSupplementalDataLoaded(completion: (() -> Void)? = nil) {
        guard !hasLoadedSupplementalData else {
            completion?()
            return
        }
        if isSupplementalDataLoading {
            return
        }
        loadSupplementalDataAndRebuildCaches(for: surahs)
    }

    func ensureSearchIndexLoaded(for scope: SearchScope = .all) {
        guard !isSearchIndexReady || !hasSearchIndexCoverage(for: scope) else { return }
        prepareSearchIndexIfNeeded(force: false, preferredScope: scope)
    }

    func unloadSearchIndex() {
        searchIndex = []
        isSearchIndexReady = false
        loadedPrebuiltSearchIndexSegments = []
        searchIndexIncludesSupplementalTexts = false
        Self.logger.debug("Unloaded search index to free memory")
    }

    func loadSupplementalDataAndRebuildCaches(for surahs: [Surah]) {
        DispatchQueue.main.async {
            self.isSupplementalDataLoading = true
            self.hasLoadedSupplementalData = false
        }

        DispatchQueue.global(qos: .utility).async {
            let loadedSupplementals = self.loadSupplementalTexts()

            if !loadedSupplementals.hasAnyData {
                DispatchQueue.main.async {
                    self.isSupplementalDataLoading = false
                    self.hasLoadedSupplementalData = false
                }
                return
            }

            let cacheBundle = self.buildCacheBundle(
                from: surahs, supplementals: loadedSupplementals, includeSearchIndex: false)
            DispatchQueue.main.async {
                self.supplementalTexts = loadedSupplementals
                self.applyCacheBundle(cacheBundle)
                self.isSupplementalDataLoading = false
                self.hasLoadedSupplementalData = true

                if self.isSearchIndexLoading
                    || (self.isSearchIndexReady && !self.searchIndexIncludesSupplementalTexts
                        && self.loadedPrebuiltSearchIndexSegments.isEmpty)
                {
                    self.prepareSearchIndexIfNeeded(force: true)
                }
            }
        }
    }

    func loadSupplementalTexts() -> SupplementalTexts {
        SupplementalTexts(
            tafsirByVerseKey: loadSupplementalTextMap(baseName: "tafsir_saadi"),
            englishByVerseKey: loadSupplementalTextMap(baseName: "translations_en"),
            swedishByVerseKey: loadSupplementalTextMap(baseName: "translations_sv")
        )
    }

    func loadSupplementalTextMap(baseName: String) -> [String: String] {
        guard let url = locateJSONURL(baseNames: [baseName]) else { return [:] }

        do {
            let data = try Data(contentsOf: url)
            if let wrapped = try? JSONDecoder().decode(SupplementalTextFile.self, from: data) {
                return wrapped.byVerseKey
            }
            if let flat = try? JSONDecoder().decode([String: String].self, from: data) {
                return flat
            }
        } catch {
            Self.logger.error(
                "Failed loading \(baseName, privacy: .public).json: \(String(describing: error), privacy: .public)"
            )
        }
        return [:]
    }

    func loadPrebuiltSearchIndex(
        requiredSegments: Set<SearchIndexSegment>,
        existingSegments: Set<SearchIndexSegment>,
        existingEntries: [IndexedVerse]
    ) -> (
        entries: [IndexedVerse], includesSupplementals: Bool,
        loadedSegments: Set<SearchIndexSegment>
    )? {
        let missingSegments = requiredSegments.subtracting(existingSegments)
        if missingSegments.isEmpty {
            let mergedSegments = existingSegments
            return (
                entries: existingEntries,
                includesSupplementals: mergedSegments.isSuperset(of: [
                    .tafsir, .translations,
                ]),
                loadedSegments: mergedSegments
            )
        }

        var mergedByKey: [String: IndexedVerse] = [:]
        if !existingEntries.isEmpty {
            mergedByKey.reserveCapacity(existingEntries.count)
            for entry in existingEntries {
                mergedByKey["\(entry.surahIndex)-\(entry.verseId)"] = entry
            }
        }

        for segment in SearchIndexSegment.allCases where missingSegments.contains(segment) {
            guard let segmentEntries = loadPrebuiltSearchIndexSegment(segment) else {
                if missingSegments == Set(SearchIndexSegment.allCases),
                    let monolithic = loadLegacyMonolithicPrebuiltSearchIndex()
                {
                    return (
                        entries: monolithic,
                        includesSupplementals: true,
                        loadedSegments: Set(SearchIndexSegment.allCases)
                    )
                }
                return nil
            }

            if mergedByKey.isEmpty {
                mergedByKey.reserveCapacity(segmentEntries.count)
            }

            for entry in segmentEntries {
                let key = "\(entry.surahIndex)-\(entry.verseId)"
                if let existing = mergedByKey[key] {
                    mergedByKey[key] = mergeIndexedVerse(existing, with: entry)
                } else {
                    mergedByKey[key] = entry
                }
            }
        }

        let mergedSegments = existingSegments.union(missingSegments)
        let mergedEntries = mergedByKey.values.sorted {
            if $0.surahIndex != $1.surahIndex { return $0.surahIndex < $1.surahIndex }
            return $0.verseId < $1.verseId
        }
        return (
            entries: mergedEntries,
            includesSupplementals: mergedSegments.isSuperset(of: [.tafsir, .translations]),
            loadedSegments: mergedSegments
        )
    }

    func mergeIndexedVerse(_ base: IndexedVerse, with other: IndexedVerse) -> IndexedVerse {
        func pick(_ a: String, _ b: String) -> String { a.isEmpty ? b : a }
        func pickOptional(_ a: String?, _ b: String?) -> String? { a ?? b }

        return IndexedVerse(
            surahIndex: base.surahIndex,
            surahId: base.surahId,
            surahName: pick(base.surahName, other.surahName),
            verseId: base.verseId,
            verseText: pick(base.verseText, other.verseText),
            verseTextArabicBare: pick(base.verseTextArabicBare, other.verseTextArabicBare),
            verseTextArabic: pick(base.verseTextArabic, other.verseTextArabic),
            surahNameArabicBare: pick(base.surahNameArabicBare, other.surahNameArabicBare),
            surahNameArabic: pick(base.surahNameArabic, other.surahNameArabic),
            tafsirArabicBare: pick(base.tafsirArabicBare, other.tafsirArabicBare),
            tafsirArabic: pick(base.tafsirArabic, other.tafsirArabic),
            englishFolded: pick(base.englishFolded, other.englishFolded),
            swedishFolded: pick(base.swedishFolded, other.swedishFolded),
            tafsirText: pick(base.tafsirText, other.tafsirText),
            tafsirPreviewText: pickOptional(base.tafsirPreviewText, other.tafsirPreviewText),
            englishText: pick(base.englishText, other.englishText),
            swedishText: pick(base.swedishText, other.swedishText)
        )
    }

    func loadPrebuiltSearchIndexSegment(_ segment: SearchIndexSegment) -> [IndexedVerse]? {
        guard let url = locateJSONURL(baseNames: [segment.prebuiltBaseName]) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            if let wrapped = try? JSONDecoder().decode(SearchIndexFile.self, from: data) {
                return wrapped.entries
            }
            if let direct = try? JSONDecoder().decode([IndexedVerse].self, from: data) {
                return direct
            }
        } catch {
            Self.logger.error(
                "Failed loading \(segment.prebuiltBaseName, privacy: .public).json: \(String(describing: error), privacy: .public)"
            )
        }
        return nil
    }

    func loadLegacyMonolithicPrebuiltSearchIndex() -> [IndexedVerse]? {
        guard let url = locateJSONURL(baseNames: ["search_index"]) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            if let wrapped = try? JSONDecoder().decode(SearchIndexFile.self, from: data) {
                return wrapped.entries
            }
            if let direct = try? JSONDecoder().decode([IndexedVerse].self, from: data) {
                return direct
            }
        } catch {
            Self.logger.error(
                "Failed loading search_index.json: \(String(describing: error), privacy: .public)")
        }
        return nil
    }

    func rebuildCaches() {
        applyCacheBundle(
            buildCacheBundle(
                from: surahs, supplementals: supplementalTexts, includeSearchIndex: false))
        if isSearchIndexReady {
            prepareSearchIndexIfNeeded(force: true)
        }
    }

    func applyCacheBundle(_ bundle: CacheBundle) {
        if let searchIndex = bundle.searchIndex {
            self.searchIndex = searchIndex
            isSearchIndexReady = true
            searchIndexIncludesSupplementalTexts = supplementalTexts.hasAnyData
            loadedPrebuiltSearchIndexSegments = []
            searchIndexRevision &+= 1
        }
        surahTextCache = bundle.surahTextCache
    }

    func buildCacheBundle(
        from surahs: [Surah],
        supplementals: SupplementalTexts,
        includeSearchIndex: Bool
    ) -> CacheBundle {
        var builtSearchIndex: [IndexedVerse]? = includeSearchIndex ? [] : nil
        if includeSearchIndex {
            builtSearchIndex?.reserveCapacity(7000)
        }
        var builtSurahTextCache: [Int: String] = [:]

        for (surahIndex, surah) in surahs.enumerated() {
            let combinedText = surah.verses.map(\.text).joined(separator: " ")
            builtSurahTextCache[surah.id] = combinedText

            for verse in surah.verses {
                let verseKey = verseLookupKey(surahId: surah.id, verseId: verse.id)
                let tafsirText =
                    supplementals.tafsirByVerseKey[verseKey] ?? (verse.tafsirSaadi ?? "")
                let englishText =
                    supplementals.englishByVerseKey[verseKey]
                    ?? (verse.translations?.enHilaliKhan ?? "")
                let swedishText =
                    supplementals.swedishByVerseKey[verseKey]
                    ?? (verse.translations?.svBernstrom ?? "")

                if includeSearchIndex {
                    builtSearchIndex?.append(
                        IndexedVerse(
                            surahIndex: surahIndex,
                            surahId: surah.id,
                            surahName: surah.name,
                            verseId: verse.id,
                            verseText: verse.text,
                            verseTextArabicBare: stripArabicDiacriticsAndMarks(verse.text),
                            verseTextArabic: normalizeArabic(verse.text),
                            surahNameArabicBare: stripArabicDiacriticsAndMarks(surah.name),
                            surahNameArabic: normalizeArabic(surah.name),
                            tafsirArabicBare: stripArabicDiacriticsAndMarks(tafsirText),
                            tafsirArabic: normalizeArabic(tafsirText),
                            englishFolded: foldForSearch(englishText),
                            swedishFolded: foldForSearch(swedishText),
                            tafsirText: tafsirText,
                            tafsirPreviewText: nil,
                            englishText: englishText,
                            swedishText: swedishText
                        )
                    )
                }
            }
        }

        return CacheBundle(
            searchIndex: builtSearchIndex,
            surahTextCache: builtSurahTextCache
        )
    }

    func buildSearchIndex(from surahs: [Surah], supplementals: SupplementalTexts)
        -> [IndexedVerse]
    {
        buildCacheBundle(from: surahs, supplementals: supplementals, includeSearchIndex: true)
            .searchIndex ?? []
    }

    func verseLookupKey(surahId: Int, verseId: Int) -> String {
        "\(surahId):\(verseId)"
    }

    func normalizeArabic(_ text: String) -> String {
        var result = stripArabicDiacriticsAndMarks(text)
        result = result.replacingOccurrences(of: "أ", with: "ا")
        result = result.replacingOccurrences(of: "إ", with: "ا")
        result = result.replacingOccurrences(of: "آ", with: "ا")
        result = result.replacingOccurrences(of: "ٱ", with: "ا")
        result = result.replacingOccurrences(of: "ى", with: "ي")
        result = result.replacingOccurrences(of: "ؤ", with: "و")
        result = result.replacingOccurrences(of: "ئ", with: "ي")
        result = result.replacingOccurrences(of: "ة", with: "ه")
        return result
    }

    func stripArabicDiacriticsAndMarks(_ text: String) -> String {
        let normalizedScalars = text.unicodeScalars.filter { scalar in
            let v = scalar.value

            // Arabic combining marks / tashkeel / Quranic annotation marks / tatweel
            if (0x0610...0x061A).contains(v) { return false }
            if v == 0x0640 { return false }
            if (0x064B...0x065F).contains(v) { return false }
            if v == 0x0670 { return false }
            if (0x06D6...0x06ED).contains(v) { return false }
            if (0x08D4...0x08FF).contains(v) { return false }

            return true
        }

        var result = String(normalizedScalars.map(Character.init))
        result = result.replacingOccurrences(of: "۞", with: "")
        result = result.replacingOccurrences(of: "ـ", with: "")
        result =
            result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return result
    }

    func foldForSearch(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current
        )
        .lowercased()
    }

    func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0600...0x06FF).contains(scalar.value) || (0x0750...0x077F).contains(scalar.value)
        }
    }

    func previewText(
        for source: QuranSearchResult.MatchSource, entry: DBSearchIndex, query: String
    ) -> String? {
        switch source {
        case .tafsir:
            return makeSnippet(entry.tafsirText ?? "", query: query)
        case .english:
            return makeSnippet(entry.englishText ?? "", query: query)
        case .swedish:
            return makeSnippet(entry.swedishText ?? "", query: query)
        case .verseText, .surahName:
            return nil
        }
    }

    func allRangesOfNormalizedQuery(_ query: String, in text: String) -> [Range<String.Index>] {
        let normQuery = normalizeArabic(query)
        guard !normQuery.isEmpty else { return [] }

        var normChars = ""
        var map: [String.Index] = []

        for idx in text.indices {
            let charStr = String(text[idx])
            let normCharStr = normalizeArabic(charStr)
            if !normCharStr.isEmpty {
                normChars.append(normCharStr)
                map.append(idx)
            }
        }

        var ranges: [Range<String.Index>] = []
        var searchStart = normChars.startIndex

        while searchStart < normChars.endIndex,
            let normRange = normChars[searchStart...].range(of: normQuery)
        {
            let startNormIdx = normChars.distance(
                from: normChars.startIndex, to: normRange.lowerBound)
            let endNormIdx =
                normChars.distance(from: normChars.startIndex, to: normRange.upperBound) - 1

            guard map.indices.contains(startNormIdx), map.indices.contains(endNormIdx) else {
                break
            }

            let origStart = map[startNormIdx]
            let origEnd = text.index(after: map[endNormIdx])
            ranges.append(origStart..<origEnd)
            searchStart = normRange.upperBound
        }

        return ranges
    }

    func makeSnippet(_ text: String, query: String, maxLength: Int = 180) -> String? {
        let cleaned = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let matchRange: Range<String.Index>? = {
            if let r = cleaned.range(
                of: query, options: [.caseInsensitive, .diacriticInsensitive])
            {
                return r
            }
            if containsArabic(cleaned) {
                return allRangesOfNormalizedQuery(query, in: cleaned).first
            }
            return nil
        }()

        if let range = matchRange {
            let start =
                cleaned.index(range.lowerBound, offsetBy: -70, limitedBy: cleaned.startIndex)
                ?? cleaned.startIndex
            let end =
                cleaned.index(range.upperBound, offsetBy: 100, limitedBy: cleaned.endIndex)
                ?? cleaned.endIndex
            var snippet = String(cleaned[start..<end]).trimmingCharacters(
                in: .whitespacesAndNewlines)
            if start > cleaned.startIndex { snippet = "… " + snippet }
            if end < cleaned.endIndex { snippet += " …" }
            return snippet
        }

        let prefixEnd =
            cleaned.index(cleaned.startIndex, offsetBy: maxLength, limitedBy: cleaned.endIndex)
            ?? cleaned.endIndex
        var snippet = String(cleaned[..<prefixEnd]).trimmingCharacters(
            in: .whitespacesAndNewlines)
        if prefixEnd < cleaned.endIndex { snippet += " …" }
        return snippet
    }

    func quranVerseText(for surahId: Int, verseId: Int) -> String {
        guard let dbReader = DatabaseManager.shared.dbReader else { return "" }
        do {
            let dbVerse = try dbReader.read { db in
                try DBVerse.filter(Column("surahId") == surahId && Column("verseId") == verseId)
                    .fetchOne(db)
            }
            return dbVerse?.text ?? ""
        } catch {
            return ""
        }
    }
}
