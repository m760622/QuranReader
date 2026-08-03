import Foundation
import GRDB

public struct DBSurah: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "surah"

    public var id: Int
    public var name: String
    public var verseCount: Int
    public var pageStart: Int
    public var pageEnd: Int
}

public struct DBVerse: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "verse"

    public var rowId: Int
    public var surahId: Int
    public var verseId: Int
    public var text: String
    public var page: Int
    public var juz: Int
    public var wordCount: Int
}

public struct DBTafsir: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "tafsir"

    public var verseRowId: Int
    public var text: String
}

public struct DBTranslation: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "translation"

    public var verseRowId: Int
    public var languageCode: String
    public var text: String
}

public struct DBSearchIndex: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "search_index"

    public var verseRowId: Int
    public var surahId: Int
    public var verseId: Int
    public var surahName: String
    public var surahNameArabicBare: String?
    public var verseText: String
    public var verseTextArabicBare: String
    public var tafsirText: String?
    public var tafsirTextArabicBare: String?
    public var englishText: String?
    public var swedishText: String?
}

