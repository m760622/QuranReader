import Foundation

// MARK: - QuranModel
struct QuranData: Codable, Sendable {
    let meta: QuranMeta?
    let quran: [Surah]
}

struct QuranMeta: Codable, Sendable {
    let generatedAtUTC: String?
    let sourceFile: String?
    let sourceFormat: String?
    let rowCount: Int?
    let surahCount: Int?
    let emptyTafsirSaadiRows: Int?
    let schemaVersion: Int?
    let notes: [String]?
}

// MARK: - Surah
struct Surah: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let verseCount: Int?
    let pageRange: PageRange?
    let juzNumbers: [Int]?
    let verses: [Verse]
}

struct PageRange: Codable, Sendable {
    let start: Int
    let end: Int
}

struct JuzInfo: Codable, Sendable {
    let number: Int
    let name: String
}

struct VerseTranslations: Codable, Sendable {
    let enHilaliKhan: String?
    let svBernstrom: String?
}

// MARK: - Verse
struct Verse: Codable, Identifiable, Sendable {
    let id: Int
    let rowId: Int?
    let text: String
    let page: Int?
    let juz: JuzInfo?
    let wordCount: Int?
    let tafsirSaadi: String?
    let translations: VerseTranslations?
}
struct JuzRowIdBounds: Codable, Sendable {
    let min: Int
    let max: Int
    let mid: Int
}
