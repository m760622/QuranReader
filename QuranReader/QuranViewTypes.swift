//
//  QuranViewTypes.swift
//  QuranReader
//

import SwiftUI
import UIKit

// MARK: - Enums
enum ReaderFontWeightOption: String, CaseIterable, Identifiable {
    case ultraLight, light, regular, medium, semibold, bold, black
    var id: String { rawValue }

    var title: String {
        switch self {
        case .ultraLight: return "خفيف جدًا"
        case .light: return "خفيف"
        case .regular: return "عادي"
        case .medium: return "متوسط"
        case .semibold: return "شبه عريض"
        case .bold: return "عريض"
        case .black: return "ثقيل"
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .black: return .black
        }
    }

    var uiFontWeight: UIFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .black: return .black
        }
    }
}

enum MushafSearchRange: String, CaseIterable, Identifiable {
    case all, currentPage
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "المصحف كله"
        case .currentPage: return "هذه الصفحة"
        }
    }
}

enum SurahListFilter: String, CaseIterable, Identifiable {
    case all, favorites, recent
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "الكل"
        case .favorites: return "مفضلة السور"
        case .recent: return "الأخيرة"
        }
    }
}

enum SurahSortOption: String, CaseIterable, Identifiable {
    case standard, alphabetical, verseCount, revelation
    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "المصحفي"
        case .alphabetical: return "الأبجدي"
        case .verseCount: return "الآيات"
        case .revelation: return "النزول"
        }
    }
}

enum VerseDetailsTab: String, CaseIterable, Identifiable {
    case tafsir, english, swedish
    var id: String { rawValue }

    var title: String {
        switch self {
        case .tafsir: return "التفسير"
        case .english: return "EN"
        case .swedish: return "SV"
        }
    }
}

enum QuickNavigatorMiniTab: String, CaseIterable, Identifiable {
    case control, reading, manage
    var id: String { rawValue }

    var title: String {
        switch self {
        case .control: return "تحكم"
        case .reading: return "قراءة"
        case .manage: return "إدارة"
        }
    }

    var icon: String {
        switch self {
        case .control: return "bolt.fill"
        case .reading: return "text.book.closed"
        case .manage: return "square.stack.3d.up"
        }
    }
}

enum ReaderMode: String, CaseIterable, Identifiable {
    case surah, mushafPage
    var id: String { rawValue }

    var title: String {
        switch self {
        case .surah: return "حسب السورة"
        case .mushafPage: return "صفحات المصحف"
        }
    }
}

struct ReaderVerseHighlightPayload: Equatable {
    let surahId: Int
    let verseId: Int
    let query: String
    let matchMode: QuranPageViewModel.ArabicSearchMatchMode
}

struct ReaderVerseNavigationRequest: Equatable {
    let surahIndex: Int
    let surahId: Int
    let verseId: Int
    let highlight: ReaderVerseHighlightPayload?
}

struct ReaderNavigationState: Equatable {
    var targetSurahId: Int?
    var targetVerseId: Int?
    var highlight: ReaderVerseHighlightPayload?
}

// MARK: - Helper Structs
struct ReaderCustomFontOption: Identifiable, Hashable {
    let postScriptName: String
    let displayName: String
    let recommendation: String?
    var id: String { postScriptName }
}

struct ReaderCustomFontSection: Identifiable {
    let title: String
    let fonts: [ReaderCustomFontOption]
    var id: String { title }
}

struct VerseBookmarkRow: Identifiable {
    let key: String
    let surahIndex: Int
    let surah: Surah
    let verse: Verse
    var id: String { key }
}
