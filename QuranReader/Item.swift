//
//  Item.swift
//  QuranReader
//
//  Created by Mohammed Abunada on 2026-02-24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
