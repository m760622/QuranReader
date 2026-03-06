import Foundation
import GRDB

public final class DatabaseManager: @unchecked Sendable {
    public static let shared = DatabaseManager()

    public var dbReader: DatabaseReader?

    public init() {}

    /// Called on app launch to connect to the bundled quran.sqlite database.
    /// If it doesn't exist, we'll need to run the seeder (in development).
    public func setupDatabase() throws {
        // Attempt to find the bundled sqlite file
        let bundleURL = Bundle.main.url(forResource: "quran", withExtension: "sqlite")

        var databaseURL: URL
        if let bundleURL = bundleURL {
            let fileManager = FileManager.default
            let documentsURL = try fileManager.url(
                for: .documentDirectory, in: .userDomainMask, appropriateFor: nil,
                create: true)

            // Ensure the directory actually exists before copying into it
            do {
                if !fileManager.fileExists(atPath: documentsURL.path) {
                    try fileManager.createDirectory(
                        at: documentsURL, withIntermediateDirectories: true, attributes: nil)
                }

                databaseURL = documentsURL.appendingPathComponent("quran_prod.sqlite")

                if !fileManager.fileExists(atPath: databaseURL.path) {
                    try fileManager.copyItem(at: bundleURL, to: databaseURL)
                    print("DB_MANAGER: Successfully copied quran.sqlite to Documents")
                } else {
                    print("DB_MANAGER: Database already exists at \(databaseURL.path)")
                }
            } catch {
                print("DB_MANAGER: File System Error: \(error)")
                databaseURL = bundleURL  // Fallback to bundle URL if copy fails
            }
        } else {
            // For development: Seeder will create it here
            let fileManager = FileManager.default
            let documentsURL = try fileManager.url(
                for: .documentDirectory, in: .userDomainMask, appropriateFor: nil,
                create: true)
            databaseURL = documentsURL.appendingPathComponent("quran_dev.sqlite")
        }

        var config = Configuration()
        if bundleURL != nil {
            config.readonly = true  // Read-only if we found it in the bundle (assuming production)
            // A database created with WAL mode keeps the .sqlite-wal requirement until explicitly changed.
            // Temporarily open the database with write access to change the journal mode before reading.
            do {
                let tempConfig = Configuration()
                let tempQueue = try DatabaseQueue(path: databaseURL.path, configuration: tempConfig)
                try tempQueue.write { db in
                    try db.execute(sql: "PRAGMA journal_mode = DELETE;")
                }
            } catch {
                print("DB_MANAGER: Failed to reset WAL mode: \(error)")
            }

            // Use DatabaseQueue on the copied file in Documents.
            self.dbReader = try DatabaseQueue(path: databaseURL.path, configuration: config)
        } else {
            config.readonly = false  // Writable for seeder
            // Use DatabasePool for concurrent reads in development/seeding
            self.dbReader = try DatabasePool(path: databaseURL.path, configuration: config)
            try createSchemaIfNeeded()
        }
    }

    private func createSchemaIfNeeded() throws {
        // Schema creation is only for development/seeding when using DatabasePool
        guard let dbPool = dbReader as? DatabasePool else { return }

        try dbPool.write { db in
            try db.create(table: "surah", ifNotExists: true) { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text).notNull()
                t.column("verseCount", .integer).notNull()
                t.column("pageStart", .integer).notNull()
                t.column("pageEnd", .integer).notNull()
            }

            try db.create(table: "verse", ifNotExists: true) { t in
                t.column("rowId", .integer).primaryKey()
                t.column("surahId", .integer).notNull().indexed()
                t.column("verseId", .integer).notNull()
                t.column("text", .text).notNull()
                t.column("page", .integer).notNull().indexed()
                t.column("juz", .integer).notNull().indexed()
                t.column("wordCount", .integer).notNull()
            }

            try db.create(table: "tafsir", ifNotExists: true) { t in
                t.column("verseRowId", .integer).primaryKey().references(
                    "verse", column: "rowId", onDelete: .cascade)
                t.column("text", .text).notNull()
            }

            try db.create(table: "translation", ifNotExists: true) { t in
                t.column("verseRowId", .integer).notNull().references(
                    "verse", column: "rowId", onDelete: .cascade)
                t.column("languageCode", .text).notNull()
                t.column("text", .text).notNull()
                t.primaryKey(["verseRowId", "languageCode"])
            }

            // FTS5 Virtual Table for blazing fast search
            try db.create(virtualTable: "search_index", using: FTS5()) { t in
                t.column("verseRowId")  // Unindexed, just for joining
                t.column("surahId")
                t.column("verseId")
                t.column("surahName")
                t.column("verseText")
                t.column("verseTextArabicBare")
                t.column("tafsirText")
                t.column("englishText")
                t.column("swedishText")
                // Using unicode61 tokenizer to strip diacritics automatically if needed
                t.tokenizer = .unicode61()
            }
        }
    }
}
