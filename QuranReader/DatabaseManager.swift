import CryptoKit
import Foundation
import GRDB

public final class DatabaseManager: @unchecked Sendable {
    public static let shared = DatabaseManager()
    private static let bundledDatabaseSignatureKey = "db_manager.bundled_database_signature"

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
            let bundledSignature = try databaseSignature(for: bundleURL)

            // Ensure the directory actually exists before copying into it
            do {
                if !fileManager.fileExists(atPath: documentsURL.path) {
                    try fileManager.createDirectory(
                        at: documentsURL, withIntermediateDirectories: true, attributes: nil)
                }

                databaseURL = documentsURL.appendingPathComponent("quran_prod.sqlite")
                let storedSignature = UserDefaults.standard.string(
                    forKey: Self.bundledDatabaseSignatureKey)
                let shouldRefreshDatabase =
                    !fileManager.fileExists(atPath: databaseURL.path)
                    || storedSignature != bundledSignature

                if shouldRefreshDatabase {
                    if fileManager.fileExists(atPath: databaseURL.path) {
                        try removeDatabaseArtifacts(at: databaseURL, using: fileManager)
                        print("DB_MANAGER: Replacing outdated quran_prod.sqlite")
                    }
                    try fileManager.copyItem(at: bundleURL, to: databaseURL)
                    UserDefaults.standard.set(
                        bundledSignature, forKey: Self.bundledDatabaseSignatureKey)
                    print("DB_MANAGER: Successfully copied quran.sqlite to Documents")
                } else {
                    // Up-to-date database already exists; keep startup logs quiet.
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
            // Use DatabaseQueue on the copied file in Documents.
            self.dbReader = try DatabaseQueue(path: databaseURL.path, configuration: config)
        } else {
            config.readonly = false  // Writable for seeder
            // Use DatabasePool for concurrent reads in development/seeding
            self.dbReader = try DatabasePool(path: databaseURL.path, configuration: config)
            try createSchemaIfNeeded()
        }
    }

    private func databaseSignature(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func removeDatabaseArtifacts(at databaseURL: URL, using fileManager: FileManager) throws {
        let walURL = databaseURL.deletingLastPathComponent().appendingPathComponent(
            databaseURL.lastPathComponent + "-wal")
        let shmURL = databaseURL.deletingLastPathComponent().appendingPathComponent(
            databaseURL.lastPathComponent + "-shm")

        for url in [databaseURL, walURL, shmURL] where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
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
