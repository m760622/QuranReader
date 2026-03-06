//
//  QuranReaderApp.swift
//  QuranReader
//
//  Created by Mohammed Abunada on 2026-02-24.
//

import OSLog
import SwiftData
import SwiftUI

@main
struct QuranReaderApp: App {
    private static let logger = Logger(subsystem: "nmds.se.QuranReader", category: "SwiftData")

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            logger.error(
                "Could not create ModelContainer (persistent). Falling back to in-memory. Error: \(String(describing: error))"
            )
            assertionFailure(
                "Could not create ModelContainer (persistent). Falling back to in-memory. Error: \(error)"
            )

            let fallbackConfiguration = ModelConfiguration(
                schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                fatalError("Could not create ModelContainer fallback: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            QuranPageView()
                .environment(\EnvironmentValues.layoutDirection, LayoutDirection.rightToLeft)
        }
        .modelContainer(sharedModelContainer)
    }
}
