import Foundation
import GRDB

public final class DatabaseSeeder: @unchecked Sendable {
    public static func seedDatabaseIfNeeded() async throws {
        // If production db exists, skip
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
            create: true)
        let prodDB = appSupportURL.appendingPathComponent("quran_prod.sqlite")

        if fileManager.fileExists(atPath: prodDB.path) {
            return
        }

        print("🌱 Starting database seeding...")
        let startTime = Date()

        guard let dbPool = DatabaseManager.shared.dbReader as? DatabasePool else {
            throw NSError(
                domain: "DatabaseSeeder", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "DatabasePool not initialized for seeding"])
        }

        // 1. Load Quran Data
        guard let quranURL = locateJSONURL(baseNames: ["quran_core", "quran"]) else { return }
        let quranData = try Data(contentsOf: quranURL)
        let decodedQuran = try JSONDecoder().decode(QuranData.self, from: quranData)

        // 2. Load Supplementals
        let tafsirMap = loadSupplemental("tafsir_saadi")
        let englishMap = loadSupplemental("translations_en")
        let swedishMap = loadSupplemental("translations_sv")

        // 3. Insert into Database inside a transaction
        try await dbPool.write { db in
            for surah in decodedQuran.quran {
                let dbSurah = DBSurah(
                    id: surah.id,
                    name: surah.name,
                    verseCount: surah.verses.count,
                    pageStart: surah.pageRange?.start ?? 0,
                    pageEnd: surah.pageRange?.end ?? 0
                )
                try dbSurah.insert(db)

                for verse in surah.verses {
                    // Safe fallbacks for missing data
                    let rawRowId = verse.rowId ?? ((surah.id * 1000) + verse.id)
                    let page = verse.page ?? 1
                    let juz = verse.juz?.number ?? 1
                    let wordCount = verse.wordCount ?? 0

                    let dbVerse = DBVerse(
                        rowId: rawRowId,
                        surahId: surah.id,
                        verseId: verse.id,
                        text: verse.text,
                        page: page,
                        juz: juz,
                        wordCount: wordCount
                    )
                    try dbVerse.insert(db)

                    // Tafsir
                    let verseKey = "\(surah.id):\(verse.id)"
                    if let tafsirText = verse.tafsirSaadi ?? tafsirMap[verseKey] {
                        let dbTafsir = DBTafsir(verseRowId: rawRowId, text: tafsirText)
                        try dbTafsir.insert(db)
                    }

                    // Translations
                    if let enText = verse.translations?.enHilaliKhan ?? englishMap[verseKey] {
                        let dbTranslation = DBTranslation(
                            verseRowId: rawRowId, languageCode: "en", text: enText)
                        try dbTranslation.insert(db)
                    }
                    if let svText = verse.translations?.svBernstrom ?? swedishMap[verseKey] {
                        let dbTranslation = DBTranslation(
                            verseRowId: rawRowId, languageCode: "sv", text: svText)
                        try dbTranslation.insert(db)
                    }

                    // Search Index FTS
                    // Create normalized texts for indexing
                    let bareArabic = verse.text.replacingOccurrences(
                        of: "[\\u064B-\\u065F\\u0670\\u06D6-\\u06ED]", with: "",
                        options: .regularExpression)

                    let dbSearch = DBSearchIndex(
                        verseRowId: rawRowId,
                        surahId: surah.id,
                        verseId: verse.id,
                        surahName: surah.name,
                        verseText: verse.text,
                        verseTextArabicBare: bareArabic,
                        tafsirText: verse.tafsirSaadi ?? tafsirMap[verseKey],
                        englishText: verse.translations?.enHilaliKhan ?? englishMap[verseKey],
                        swedishText: verse.translations?.svBernstrom ?? swedishMap[verseKey]
                    )
                    try dbSearch.insert(db)
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        print("✅ Finished seeding database in \(String(format: "%.2f", duration)) seconds!")

        // Move dev db to prod db location
        let devDB = appSupportURL.appendingPathComponent("quran_dev.sqlite")
        if fileManager.fileExists(atPath: devDB.path) {
            try fileManager.moveItem(at: devDB, to: prodDB)
        }
    }

    // MARK: - Helpers
    private static func locateJSONURL(baseNames: [String]) -> URL? {
        for baseName in baseNames {
            if let url = Bundle.main.url(forResource: baseName, withExtension: "json") {
                return url
            }
        }
        return nil
    }

    private static func loadSupplemental(_ baseName: String) -> [String: String] {
        guard let url = Bundle.main.url(forResource: baseName, withExtension: "json") else {
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            struct SupplementalTextFile: Decodable { let byVerseKey: [String: String] }
            let decoded = try JSONDecoder().decode(SupplementalTextFile.self, from: data)
            return decoded.byVerseKey
        } catch {
            return [:]
        }
    }
}
