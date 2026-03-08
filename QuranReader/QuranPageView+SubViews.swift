//
//  QuranPageView+SubViews.swift
//  QuranReader
//
//  Reusable sub-view structs extracted from QuranPageView.
//

import CoreText
import SwiftUI

// MARK: - Sub-Views
extension QuranPageView {
    static let searchMatchScrollAttribute = NSAttributedString.Key("ReaderSearchMatch")

    struct ActionButton: View {
        let icon: String
        let color: Color

        var body: some View {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.95), color.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                )
                .shadow(color: color.opacity(0.22), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - ConnectedVersesView (Standard Mode — truly flowing text, grouped by page)

    struct ConnectedVersesView: View {
        let surahId: Int
        let verses: [Verse]
        let currentVerseId: Int?
        let fontSize: Double
        let lineSpacing: Double
        let showTranslation: Bool
        let primaryGreen: Color
        let textColor: Color
        let secondaryTextColor: Color
        let isNightMode: Bool
        let verseHighlightColor: Color
        let searchHighlightQuery: String
        let searchHighlightSurahId: Int?
        let searchHighlightMode: QuranPageViewModel.ArabicSearchMatchMode
        let searchHighlightVerseId: Int?
        let preciseScrollSurahId: Int?
        let preciseScrollVerseId: Int?
        let preciseScrollRequestID: Int
        let customFontName: String?
        let systemDesign: Font.Design
        let fontWeight: ReaderFontWeightOption
        let chunkSize: Int
        let contextMenuEnabled: Bool
        let showsPageDividers: Bool
        let horizontalPadding: CGFloat
        let onVerseTap: (Verse) -> Void
        let onShowTafsir: (Verse) -> Void
        let isSurahFavorite: () -> Bool
        let onToggleSurahFavorite: () -> Void
        let isVerseBookmarked: (Int) -> Bool
        let onToggleBookmark: (Verse) -> Void
        let onCopyVerse: (Verse) -> Void
        let onShareVerse: (Verse) -> Void
        let onPageChange: ((Int) -> Void)?
        let scrollSpace: String?
        let onRegisterAnchor: ((Int, CGFloat) -> Void)?
        let onPreciseScrollCompleted: ((Int, Int) -> Void)?

        // Group verses by their page number, preserving order
        // Optimization: Pre-calculating this more efficiently
        var pageGroups: [(pageNumber: Int, verses: [Verse])] {
            guard !verses.isEmpty else { return [] }
            var groups: [(Int, [Verse])] = []
            var currentGroup: [Verse] = []
            var currentPage: Int = verses.first?.page ?? -1

            for verse in verses {
                let pg = verse.page ?? -1
                if pg != currentPage {
                    groups.append((currentPage, currentGroup))
                    currentPage = pg
                    currentGroup = [verse]
                } else {
                    currentGroup.append(verse)
                }
            }
            groups.append((currentPage, currentGroup))
            return groups
        }

        // Split a group of verses into chunks of 10 for performance
        func chunks(for groupVerses: [Verse]) -> [[Verse]] {
            let size = max(1, chunkSize)
            var result: [[Verse]] = []
            result.reserveCapacity((groupVerses.count + size - 1) / size)
            for i in stride(from: 0, to: groupVerses.count, by: size) {
                result.append(Array(groupVerses[i..<min(i + size, groupVerses.count)]))
            }
            return result
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(pageGroups, id: \.pageNumber) { group in
                    if showsPageDividers {
                        PageDividerView(
                            surahId: surahId,
                            pageNumber: group.pageNumber,
                            primaryGreen: primaryGreen,
                            isNightMode: isNightMode,
                            isFirstPage: false,  // Simplified for performance
                            isHidden: false
                        )
                        .id("DIV_S\(surahId)_P\(group.pageNumber)")
                        .onAppear {
                            onPageChange?(group.pageNumber)
                        }
                        .background(
                            GeometryReader { geo in
                                let minY = geo.frame(in: .named(scrollSpace ?? "")).origin.y
                                let anchorToken = Int(minY.rounded())
                                Color.clear
                                    .task(id: anchorToken) {
                                        if let scrollSpace = scrollSpace, !scrollSpace.isEmpty {
                                            DispatchQueue.main.async {
                                                onRegisterAnchor?(group.pageNumber, minY)
                                            }
                                        }
                                    }
                            }
                        )
                    }

                    ForEach(chunks(for: group.verses), id: \.first?.id) { chunk in
                        FlowingVerseChunk(
                            surahId: surahId,
                            chunk: chunk,
                            currentVerseId: currentVerseId,
                            fontSize: fontSize,
                            lineSpacing: lineSpacing,
                            showTranslation: showTranslation,
                            primaryGreen: primaryGreen,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            isNightMode: isNightMode,
                            verseHighlightColor: verseHighlightColor,
                            searchHighlightQuery: searchHighlightQuery,
                            searchHighlightSurahId: searchHighlightSurahId,
                            searchHighlightMode: searchHighlightMode,
                            searchHighlightVerseId: searchHighlightVerseId,
                            preciseScrollSurahId: preciseScrollSurahId,
                            preciseScrollVerseId: preciseScrollVerseId,
                            preciseScrollRequestID: preciseScrollRequestID,
                            customFontName: customFontName,
                            systemDesign: systemDesign,
                            fontWeight: fontWeight,
                            contextMenuEnabled: contextMenuEnabled,
                            onShowTafsir: onShowTafsir,
                            isSurahFavorite: isSurahFavorite,
                            onToggleSurahFavorite: onToggleSurahFavorite,
                            isVerseBookmarked: isVerseBookmarked,
                            onToggleBookmark: onToggleBookmark,
                            onCopyVerse: onCopyVerse,
                            onShareVerse: onShareVerse,
                            onPreciseScrollCompleted: onPreciseScrollCompleted,
                            onTap: { verse in onVerseTap(verse) }
                        )
                        .id("CHUNK_S\(surahId)_V\(chunk.first?.id ?? 0)")
                    }

                    // Restore visual gap anchor for ScrollViewReader stability
                    Color.clear.frame(height: 0)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    // MARK: - PageDividerView

    struct PageDividerView: View {
        let surahId: Int
        let pageNumber: Int
        let primaryGreen: Color
        let isNightMode: Bool
        let isFirstPage: Bool
        let isHidden: Bool

        @ViewBuilder
        var body: some View {
            if isHidden {
                Color.clear
                    .frame(height: isFirstPage ? 2 : 4)
                    .padding(.vertical, isFirstPage ? 2 : 4)
            } else {
                let lineMaxOpacity: Double = isNightMode ? 0.35 : 0.42
                let badgeFill = isNightMode ? Color.white.opacity(0.04) : Color.white.opacity(0.68)
                let badgeStroke = primaryGreen.opacity(isNightMode ? 0.26 : 0.18)

                HStack(spacing: 12) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    primaryGreen.opacity(0), primaryGreen.opacity(lineMaxOpacity),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)

                    // Creative page badge
                    HStack(spacing: 10) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(primaryGreen.opacity(0.9))

                        VStack(spacing: -1) {
                            Text("صفحة")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(primaryGreen.opacity(0.95))
                            Text("\(pageNumber)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(primaryGreen)
                        }

                        Image(systemName: "sparkle")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(primaryGreen.opacity(0.65))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(badgeFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(badgeStroke, lineWidth: 1)
                            )
                    )
                    .shadow(
                        color: primaryGreen.opacity(isNightMode ? 0.10 : 0.14),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
                    .fixedSize()

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    primaryGreen.opacity(lineMaxOpacity), primaryGreen.opacity(0),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                }
                .padding(.vertical, isFirstPage ? 2 : 4)
                .padding(.horizontal, 4)
                .environment(\.layoutDirection, .leftToRight)  // Keep divider LTR so gradients stay correct
            }
        }
    }

    // Each chunk = ONE flowing Text with all verse texts merged as AttributedString
    struct FlowingVerseChunk: View {
        @Environment(\.horizontalSizeClass) var horizontalSizeClass
        let surahId: Int
        let chunk: [Verse]
        let currentVerseId: Int?
        let fontSize: Double
        let lineSpacing: Double
        let showTranslation: Bool
        let primaryGreen: Color
        let textColor: Color
        let secondaryTextColor: Color
        let isNightMode: Bool
        let verseHighlightColor: Color
        let searchHighlightQuery: String
        let searchHighlightSurahId: Int?
        let searchHighlightMode: QuranPageViewModel.ArabicSearchMatchMode
        let searchHighlightVerseId: Int?
        let preciseScrollSurahId: Int?
        let preciseScrollVerseId: Int?
        let preciseScrollRequestID: Int
        let customFontName: String?
        let systemDesign: Font.Design
        let fontWeight: ReaderFontWeightOption
        let contextMenuEnabled: Bool
        let onShowTafsir: (Verse) -> Void
        let isSurahFavorite: () -> Bool
        let onToggleSurahFavorite: () -> Void
        let isVerseBookmarked: (Int) -> Bool
        let onToggleBookmark: (Verse) -> Void
        let onCopyVerse: (Verse) -> Void
        let onShareVerse: (Verse) -> Void
        let onPreciseScrollCompleted: ((Int, Int) -> Void)?
        let onTap: (Verse) -> Void
        @State var selectedVerseForMenu: Verse?
        @State var transientHighlightedVerseId: Int?
        @State var clearTransientHighlightTask: Task<Void, Never>?
        @State var presentVerseMenuTask: Task<Void, Never>?
        var effectiveLineSpacing: Double {
            lineSpacing + ((horizontalSizeClass == .regular) ? 2 : 0)
        }
        var longPressedVerseId: Int? {
            transientHighlightedVerseId ?? selectedVerseForMenu?.id
        }
        var markedHighlightColor: Color {
            verseHighlightColor.opacity(isNightMode ? 0.55 : 0.42)
        }
        var markerMarkedHighlightColor: Color {
            verseHighlightColor.opacity(isNightMode ? 0.62 : 0.50)
        }
        var longPressUnderlineColor: Color {
            verseHighlightColor.opacity(isNightMode ? 0.95 : 0.82)
        }
        var transientLongPressHighlightColor: Color {
            verseHighlightColor.opacity(isNightMode ? 0.72 : 0.58)
        }
        var searchMatchHighlightColor: UIColor {
            UIColor(isNightMode ? Color.yellow.opacity(0.34) : Color.yellow.opacity(0.28))
        }
        var preciseScrollTargetURL: URL? {
            guard preciseScrollSurahId == surahId, let preciseScrollVerseId else { return nil }
            guard chunk.contains(where: { $0.id == preciseScrollVerseId }) else { return nil }
            return verseLinkURL(forVerseId: preciseScrollVerseId)
        }
        var prefersHighlightedPreciseScroll: Bool {
            let trimmedQuery = searchHighlightQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedQuery.isEmpty else { return false }
            guard searchHighlightSurahId == surahId else { return false }
            guard let preciseScrollVerseId else { return false }
            return searchHighlightVerseId == preciseScrollVerseId
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // One flowing Text for ALL verses in this chunk
                InteractiveAttributedVerseText(
                    attributedText: chunkNSAttributedString,
                    lineSpacing: effectiveLineSpacing,
                    contextMenuEnabled: contextMenuEnabled,
                    preciseScrollTargetURL: preciseScrollTargetURL,
                    preciseScrollRequestID: preciseScrollRequestID,
                    preferHighlightedRangeForPreciseScroll: prefersHighlightedPreciseScroll,
                    onPreciseScrollCompleted: {
                        guard let preciseScrollVerseId else { return }
                        onPreciseScrollCompleted?(surahId, preciseScrollVerseId)
                    },
                    onTapURL: { url in
                        guard let verse = verse(for: url) else { return }
                        onTap(verse)
                    },
                    onLongPressURL: { url in
                        guard let verse = verse(for: url) else { return }
                        transientHighlightedVerseId = verse.id
                        clearTransientHighlightTask?.cancel()
                        clearTransientHighlightTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_300_000_000)
                            guard !Task.isCancelled else { return }
                            if transientHighlightedVerseId == verse.id {
                                transientHighlightedVerseId = nil
                            }
                        }
                        presentVerseMenuTask?.cancel()
                        presentVerseMenuTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 80_000_000)
                            guard !Task.isCancelled else { return }
                            selectedVerseForMenu = verse
                        }
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                // Translations list below the chunk (if enabled)
                if showTranslation {
                    ForEach(chunk, id: \.id) { verse in
                        if let translations = verse.translations,
                            let en = translations.enHilaliKhan
                        {
                            if contextMenuEnabled {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("﴿\(verse.id)﴾")
                                        .font(.caption2.bold())
                                        .foregroundColor(primaryGreen.opacity(0.8))
                                        .fixedSize()
                                    if isVerseBookmarked(verse.id) {
                                        Image(systemName: "bookmark.fill")
                                            .font(.caption2.weight(.bold))
                                            .foregroundColor(primaryGreen.opacity(0.85))
                                            .padding(.top, 1)
                                    }
                                    Text(en)
                                        .font(.system(size: fontSize * 0.70))
                                        .foregroundColor(secondaryTextColor)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onTap(verse)
                                }
                                .padding(.top, 4)
                                .environment(\.layoutDirection, .leftToRight)
                            } else {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("﴿\(verse.id)﴾")
                                        .font(.caption2.bold())
                                        .foregroundColor(primaryGreen.opacity(0.8))
                                        .fixedSize()
                                    if isVerseBookmarked(verse.id) {
                                        Image(systemName: "bookmark.fill")
                                            .font(.caption2.weight(.bold))
                                            .foregroundColor(primaryGreen.opacity(0.85))
                                            .padding(.top, 1)
                                    }
                                    Text(en)
                                        .font(.system(size: fontSize * 0.70))
                                        .foregroundColor(secondaryTextColor)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onTap(verse)
                                }
                                .padding(.top, 4)
                                .environment(\.layoutDirection, .leftToRight)
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedVerseForMenu) { verse in
                NavigationStack {
                    List {
                        verseContextMenu(for: verse)
                    }
                    .navigationTitle("خيارات الآية")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("إغلاق") { selectedVerseForMenu = nil }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .environment(\.layoutDirection, .rightToLeft)
            }
            .onDisappear {
                clearTransientHighlightTask?.cancel()
                presentVerseMenuTask?.cancel()
            }
        }

        var verseUIFont: UIFont {
            if let customFontName, let font = UIFont(name: customFontName, size: fontSize) {
                return font
            }
            let base = UIFont.systemFont(ofSize: fontSize, weight: fontWeight.uiFontWeight)
            switch systemDesign {
            case .rounded:
                if let descriptor = base.fontDescriptor.withDesign(.rounded) {
                    return UIFont(descriptor: descriptor, size: fontSize)
                }
                return base
            case .serif:
                if let descriptor = base.fontDescriptor.withDesign(.serif) {
                    return UIFont(descriptor: descriptor, size: fontSize)
                }
                return base
            default:
                return base
            }
        }

        var markerUIFont: UIFont {
            let markerSize = max(fontSize * 0.78, 14)
            if let customFontName, let font = UIFont(name: customFontName, size: markerSize) {
                return font
            }
            return UIFont.systemFont(ofSize: markerSize, weight: .bold)
        }

        var chunkAttributedString: AttributedString {
            var result = AttributedString("")
            for verse in chunk {
                let isMarked = isVerseBookmarked(verse.id)
                let isLongPressed = longPressedVerseId == verse.id

                var verseText = AttributedString(verse.text)
                verseText.foregroundColor = isMarked ? primaryGreen : textColor
                if let customFontName {
                    verseText.font = .custom(customFontName, size: fontSize)
                } else {
                    verseText.font = .system(size: fontSize, weight: fontWeight.fontWeight)
                }
                if isMarked {
                    verseText.backgroundColor = markedHighlightColor
                }
                if isLongPressed {
                    verseText.backgroundColor = transientLongPressHighlightColor
                    verseText.underlineStyle = .single
                }
                verseText.link = verseLinkURL(forVerseId: verse.id)

                var marker = AttributedString(" ﴿\(verse.id)﴾ ")
                marker.foregroundColor = primaryGreen.opacity(isMarked ? 1.0 : 0.6)
                if isMarked {
                    marker.backgroundColor = markerMarkedHighlightColor
                }
                if isLongPressed {
                    marker.backgroundColor = transientLongPressHighlightColor
                    marker.underlineStyle = .single
                }
                marker.link = verseLinkURL(forVerseId: verse.id)
                if let customFontName {
                    marker.font = .custom(customFontName, size: fontSize * 0.78)
                } else {
                    marker.font = .system(size: fontSize * 0.78, weight: .bold)
                }

                result.append(verseText)
                result.append(marker)
            }
            return result
        }

        var chunkNSAttributedString: NSAttributedString {
            let mutable = NSMutableAttributedString()
            let normalColor = UIColor(textColor)
            let activeColor = UIColor(primaryGreen)
            let markedBackground = UIColor(markedHighlightColor)

            for verse in chunk {
                let isMarked = isVerseBookmarked(verse.id)
                let isLongPressed = longPressedVerseId == verse.id
                let verseURL = verseLinkURL(forVerseId: verse.id)

                var verseAttributes: [NSAttributedString.Key: Any] = [
                    .font: verseUIFont,
                    .foregroundColor: isMarked ? activeColor : normalColor,
                    .link: verseURL,
                ]
                if isMarked {
                    verseAttributes[.backgroundColor] = markedBackground
                }
                if isLongPressed {
                    verseAttributes[.backgroundColor] = UIColor(transientLongPressHighlightColor)
                    verseAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    verseAttributes[.underlineColor] = UIColor(longPressUnderlineColor)
                }
                let verseAttributed = NSMutableAttributedString(
                    string: verse.text,
                    attributes: verseAttributes
                )
                applySearchHighlightIfNeeded(to: verseAttributed, verse: verse)
                mutable.append(verseAttributed)

                var markerAttributes: [NSAttributedString.Key: Any] = [
                    .font: markerUIFont,
                    .foregroundColor: UIColor(
                        primaryGreen.opacity(isMarked ? 1.0 : 0.6)),
                    .link: verseURL,
                ]
                if isMarked {
                    markerAttributes[.backgroundColor] = UIColor(markerMarkedHighlightColor)
                }
                if isLongPressed {
                    markerAttributes[.backgroundColor] = UIColor(transientLongPressHighlightColor)
                    markerAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    markerAttributes[.underlineColor] = UIColor(longPressUnderlineColor)
                }
                mutable.append(
                    NSAttributedString(string: " ﴿\(verse.id)﴾ ", attributes: markerAttributes)
                )
            }
            return mutable
        }

        func applySearchHighlightIfNeeded(
            to attributedText: NSMutableAttributedString,
            verse: Verse
        ) {
            let trimmedQuery = searchHighlightQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard searchHighlightSurahId == surahId, verse.id == searchHighlightVerseId,
                trimmedQuery.count >= 2
            else { return }
            let verseText = attributedText.string

            if let ranges = highlightRanges(in: verseText, query: trimmedQuery), !ranges.isEmpty {
                for range in ranges {
                    let nsRange = NSRange(range, in: verseText)
                    attributedText.addAttribute(
                        .backgroundColor,
                        value: searchMatchHighlightColor,
                        range: nsRange
                    )
                    attributedText.addAttribute(
                        QuranPageView.searchMatchScrollAttribute,
                        value: true,
                        range: nsRange
                    )
                }
            }
        }

        func highlightRanges(in text: String, query: String) -> [Range<String.Index>]? {
            if containsArabic(query) {
                let normalizedQuery = normalizedSearchText(query, mode: searchHighlightMode)
                guard !normalizedQuery.isEmpty else { return nil }
                return normalizedArabicRanges(in: text, query: normalizedQuery)
            }

            var ranges: [Range<String.Index>] = []
            var searchStart = text.startIndex

            while searchStart < text.endIndex,
                let range = text[searchStart...].range(
                    of: query,
                    options: [.caseInsensitive, .diacriticInsensitive]
                )
            {
                ranges.append(range)
                searchStart = range.upperBound
            }

            return ranges.isEmpty ? nil : ranges
        }

        func normalizedArabicRanges(in text: String, query: String) -> [Range<String.Index>]? {
            let mapping = normalizedArabicIndexMap(for: text)
            guard !mapping.normalized.isEmpty, !mapping.map.isEmpty else { return nil }

            var ranges: [Range<String.Index>] = []
            var searchStart = mapping.normalized.startIndex

            while searchStart < mapping.normalized.endIndex,
                let foundRange = mapping.normalized[searchStart...].range(of: query)
            {
                let lowerOffset = mapping.normalized.distance(
                    from: mapping.normalized.startIndex,
                    to: foundRange.lowerBound
                )
                let upperOffset = mapping.normalized.distance(
                    from: mapping.normalized.startIndex,
                    to: foundRange.upperBound
                )
                guard
                    mapping.map.indices.contains(lowerOffset),
                    mapping.map.indices.contains(max(upperOffset - 1, lowerOffset))
                else {
                    break
                }

                let lower = mapping.map[lowerOffset]
                let lastMatched = mapping.map[max(upperOffset - 1, lowerOffset)]
                let upper = text.index(after: lastMatched)
                ranges.append(lower..<upper)
                searchStart = foundRange.upperBound
            }

            return ranges.isEmpty ? nil : ranges
        }

        func normalizedArabicIndexMap(for text: String) -> (normalized: String, map: [String.Index])
        {
            var normalized = ""
            var map: [String.Index] = []
            var lastWasWhitespace = false

            for index in text.indices {
                let character = text[index]
                if character.isWhitespace || character.isNewline {
                    if !lastWasWhitespace, !normalized.isEmpty {
                        normalized.append(" ")
                        map.append(index)
                    }
                    lastWasWhitespace = true
                    continue
                }

                lastWasWhitespace = false
                let transformed = normalizedSearchText(String(character), mode: searchHighlightMode)
                guard !transformed.isEmpty else { continue }
                for transformedCharacter in transformed {
                    normalized.append(transformedCharacter)
                    map.append(index)
                }
            }

            while normalized.last == " " {
                normalized.removeLast()
                map.removeLast()
            }

            return (normalized, map)
        }

        func normalizedSearchText(
            _ text: String,
            mode: QuranPageViewModel.ArabicSearchMatchMode
        ) -> String {
            switch mode {
            case .exact:
                return text
            case .noDiacritics:
                return stripArabicDiacriticsAndMarks(text)
            case .normalized:
                return normalizeArabic(text)
            }
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
                let value = scalar.value
                if (0x0610...0x061A).contains(value) { return false }
                if value == 0x0640 { return false }
                if (0x064B...0x065F).contains(value) { return false }
                if value == 0x0670 { return false }
                if (0x06D6...0x06ED).contains(value) { return false }
                if (0x08D4...0x08FF).contains(value) { return false }
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

        func containsArabic(_ text: String) -> Bool {
            text.unicodeScalars.contains { scalar in
                (0x0600...0x06FF).contains(scalar.value) || (0x0750...0x077F).contains(scalar.value)
            }
        }

        @ViewBuilder
        func verseContextMenu(for verse: Verse) -> some View {
            Button {
                onToggleBookmark(verse)
                selectedVerseForMenu = nil
            } label: {
                Label(
                    isVerseBookmarked(verse.id)
                        ? "إزالة الآية من المفضلة"
                        : "إضافة الآية للمفضلة",
                    systemImage: isVerseBookmarked(verse.id)
                        ? "bookmark.slash.fill" : "bookmark.fill"
                )
            }

            Button {
                onShowTafsir(verse)
                selectedVerseForMenu = nil
            } label: {
                Label("التفسير", systemImage: "book")
            }

            Button {
                onToggleSurahFavorite()
                selectedVerseForMenu = nil
            } label: {
                Label(
                    isSurahFavorite()
                        ? "إزالة السورة فقط من المفضلة"
                        : "إضافة السورة فقط للمفضلة",
                    systemImage: isSurahFavorite() ? "heart.slash" : "heart"
                )
            }

            Button {
                onCopyVerse(verse)
                selectedVerseForMenu = nil
            } label: {
                Label("نسخ الآية", systemImage: "doc.on.doc")
            }

            Button {
                onShareVerse(verse)
                selectedVerseForMenu = nil
            } label: {
                Label("مشاركة", systemImage: "square.and.arrow.up")
            }
        }

        func verseLinkURL(forVerseId verseId: Int) -> URL {
            // Use a private URL scheme so we can map taps back to a Verse without leaving the app.
            URL(string: "quranverse:///s/\(surahId)/v/\(verseId)")!
        }

        func verse(for url: URL) -> Verse? {
            guard url.scheme == "quranverse" else { return nil }
            let comps = url.pathComponents  // ["/", "s", "<surahId>", "v", "<verseId>"]
            guard comps.count >= 5,
                comps[1] == "s",
                comps[3] == "v",
                let urlSurahId = Int(comps[2]),
                let urlVerseId = Int(comps[4]),
                urlSurahId == surahId
            else { return nil }
            return chunk.first(where: { $0.id == urlVerseId })
        }

        struct InteractiveAttributedVerseText: UIViewRepresentable {
            let attributedText: NSAttributedString
            let lineSpacing: Double
            let contextMenuEnabled: Bool
            let preciseScrollTargetURL: URL?
            let preciseScrollRequestID: Int
            let preferHighlightedRangeForPreciseScroll: Bool
            let onPreciseScrollCompleted: (() -> Void)?
            let onTapURL: (URL) -> Void
            let onLongPressURL: (URL) -> Void

            func makeCoordinator() -> Coordinator {
                Coordinator(
                    onTapURL: onTapURL,
                    onLongPressURL: onLongPressURL,
                    preferHighlightedRangeForPreciseScroll: preferHighlightedRangeForPreciseScroll,
                    onPreciseScrollCompleted: onPreciseScrollCompleted
                )
            }

            final class StableLayoutTextView: UITextView {
                private(set) var stableLayoutWidth: CGFloat = 0
                private var lastLoggedWidth: CGFloat = 0

                func applyStableLayoutWidth(_ width: CGFloat) {
                    let screenScale =
                        window?.windowScene?.screen.scale
                        ?? window?.screen.scale
                        ?? traitCollection.displayScale
                    let snappedWidth = floor(width * screenScale) / screenScale
                    guard snappedWidth.isFinite, snappedWidth > 0 else { return }
                    guard abs(stableLayoutWidth - snappedWidth) > 0.25 else { return }

                    stableLayoutWidth = snappedWidth
                    textContainer.size = CGSize(
                        width: snappedWidth,
                        height: CGFloat.greatestFiniteMagnitude
                    )

                    #if DEBUG
                        if abs(lastLoggedWidth - snappedWidth) > 0.25 {
                            lastLoggedWidth = snappedWidth
                            print(
                                "MUSHAF_LAYOUT width=\(String(format: "%.2f", snappedWidth)) bounds=\(String(format: "%.2f", bounds.width)) frame=\(String(format: "%.2f", frame.width)) inset=\(String(format: "%.2f", textContainerInset.left + textContainerInset.right))"
                            )
                        }
                    #endif
                }
            }

            func makeUIView(context: Context) -> UITextView {
                let textView: StableLayoutTextView
                if #available(iOS 16.0, *) {
                    // We rely on NSLayoutManager APIs for precise verse targeting.
                    textView = StableLayoutTextView(usingTextLayoutManager: false)
                } else {
                    textView = StableLayoutTextView()
                }
                textView.isEditable = false
                textView.isSelectable = false
                textView.isScrollEnabled = false
                textView.backgroundColor = .clear
                textView.textContainerInset = .zero
                textView.textContainer.lineFragmentPadding = 0
                textView.textContainer.widthTracksTextView = true
                textView.textContainer.lineBreakMode = .byWordWrapping
                textView.textContainer.maximumNumberOfLines = 0
                textView.setContentHuggingPriority(.required, for: .vertical)
                textView.setContentCompressionResistancePriority(.required, for: .vertical)
                textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                textView.adjustsFontForContentSizeCategory = true
                textView.semanticContentAttribute = .forceRightToLeft
                textView.textAlignment = .justified
                textView.layoutManager.allowsNonContiguousLayout = false
                textView.linkTextAttributes = [
                    .underlineStyle: 0
                ]
                let tapGesture = UITapGestureRecognizer(
                    target: context.coordinator,
                    action: #selector(Coordinator.handleTap(_:))
                )
                tapGesture.cancelsTouchesInView = false
                tapGesture.delegate = context.coordinator

                let longGesture = UILongPressGestureRecognizer(
                    target: context.coordinator,
                    action: #selector(Coordinator.handleLongPress(_:))
                )
                longGesture.minimumPressDuration = 0.38
                longGesture.cancelsTouchesInView = false
                longGesture.delegate = context.coordinator

                tapGesture.require(toFail: longGesture)
                textView.addGestureRecognizer(tapGesture)
                longGesture.isEnabled = contextMenuEnabled
                textView.addGestureRecognizer(longGesture)
                context.coordinator.textView = textView
                context.coordinator.longPressGesture = longGesture

                // Assign immediately to prevent layout jumps on first render
                textView.attributedText = withParagraphStyle(appliedTo: attributedText)

                return textView
            }

            func updateUIView(_ uiView: UITextView, context: Context) {
                context.coordinator.onTapURL = onTapURL
                context.coordinator.onLongPressURL = onLongPressURL
                context.coordinator.preferHighlightedRangeForPreciseScroll =
                    preferHighlightedRangeForPreciseScroll
                context.coordinator.onPreciseScrollCompleted = onPreciseScrollCompleted
                context.coordinator.longPressGesture?.isEnabled = contextMenuEnabled
                context.coordinator.preciseScrollTargetURL = preciseScrollTargetURL

                let newText = withParagraphStyle(appliedTo: attributedText)

                // PERFORMANCE: Only update if anything actually changed.
                // Comparing attribute lengths and string content is much faster than full attributed equality.
                if uiView.attributedText.length != newText.length
                    || uiView.attributedText.string != newText.string
                {
                    uiView.attributedText = newText
                    uiView.invalidateIntrinsicContentSize()

                    // Optimization: Use setNeedsLayout instead of layoutIfNeeded to coalesce layout passes
                    uiView.setNeedsLayout()
                } else {
                    // Check for potential attribute changes even if string remains same (like highlights)
                    // But don't force layout unless really needed.
                    if !uiView.attributedText.isEqual(to: newText) {
                        uiView.attributedText = newText
                        uiView.setNeedsLayout()
                    }
                }

                context.coordinator.performPreciseScrollIfNeeded(requestID: preciseScrollRequestID)
            }

            func sizeThatFits(
                _ proposal: ProposedViewSize,
                uiView: UITextView,
                context: Context
            ) -> CGSize? {
                guard let width = proposal.width else { return nil }
                if let stableTextView = uiView as? StableLayoutTextView {
                    stableTextView.applyStableLayoutWidth(width)
                }
                let fitting = uiView.sizeThatFits(
                    CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
                )
                return CGSize(width: width, height: ceil(fitting.height))
            }

            func withParagraphStyle(appliedTo source: NSAttributedString)
                -> NSAttributedString
            {
                let mutable = NSMutableAttributedString(attributedString: source)
                let fullRange = NSRange(location: 0, length: mutable.length)

                let style = NSMutableParagraphStyle()
                style.lineSpacing = lineSpacing
                style.alignment = .justified
                style.baseWritingDirection = .rightToLeft
                mutable.addAttribute(.paragraphStyle, value: style, range: fullRange)

                // Restore: Remove lineSpacing from the LAST paragraph so consecutive chunks
                // don't create a visible gap between UITextViews.
                let text = mutable.string as NSString
                let lastParagraphRange = text.paragraphRange(
                    for: NSRange(location: max(0, text.length - 1), length: 0))
                if lastParagraphRange.length > 0 {
                    let lastStyle = NSMutableParagraphStyle()
                    lastStyle.lineSpacing = 0
                    lastStyle.alignment = .justified
                    lastStyle.baseWritingDirection = .rightToLeft
                    mutable.addAttribute(
                        .paragraphStyle, value: lastStyle, range: lastParagraphRange)
                }

                return mutable
            }

            final class Coordinator: NSObject, UIGestureRecognizerDelegate {
                weak var textView: UITextView?
                weak var longPressGesture: UILongPressGestureRecognizer?
                var onTapURL: (URL) -> Void
                var onLongPressURL: (URL) -> Void
                var preferHighlightedRangeForPreciseScroll: Bool
                var onPreciseScrollCompleted: (() -> Void)?
                var preciseScrollTargetURL: URL?
                var lastPreciseScrollRequestID = 0
                var preciseScrollRetryCount = 0

                init(
                    onTapURL: @escaping (URL) -> Void,
                    onLongPressURL: @escaping (URL) -> Void,
                    preferHighlightedRangeForPreciseScroll: Bool,
                    onPreciseScrollCompleted: (() -> Void)?
                ) {
                    self.onTapURL = onTapURL
                    self.onLongPressURL = onLongPressURL
                    self.preferHighlightedRangeForPreciseScroll =
                        preferHighlightedRangeForPreciseScroll
                    self.onPreciseScrollCompleted = onPreciseScrollCompleted
                }

                func performPreciseScrollIfNeeded(requestID: Int) {
                    guard requestID > 0, requestID != lastPreciseScrollRequestID else { return }
                    guard let textView, let targetURL = preciseScrollTargetURL else { return }
                    guard let scrollView = containingReaderScrollView(startingAt: textView) else {
                        return
                    }
                    guard
                        let targetSelection = preferredPreciseScrollSelection(
                            in: textView.attributedText,
                            fallbackURL: targetURL
                        )
                    else {
                        return
                    }
                    let targetRange = targetSelection.range

                    textView.layoutManager.ensureLayout(for: textView.textContainer)
                    let glyphRange = textView.layoutManager.glyphRange(
                        forCharacterRange: targetRange,
                        actualCharacterRange: nil
                    )
                    var targetRect = textView.layoutManager.boundingRect(
                        forGlyphRange: glyphRange,
                        in: textView.textContainer
                    )
                    targetRect.origin.x += textView.textContainerInset.left
                    targetRect.origin.y += textView.textContainerInset.top

                    let targetRectInScrollView = textView.convert(targetRect, to: scrollView)
                    let targetOffsetY = max(
                        -scrollView.adjustedContentInset.top,
                        targetRectInScrollView.minY - 28
                    )

                    lastPreciseScrollRequestID = requestID
                    preciseScrollRetryCount = 0
                    DispatchQueue.main.async {
                        scrollView.setContentOffset(
                            CGPoint(x: scrollView.contentOffset.x, y: targetOffsetY),
                            animated: true
                        )
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
                        guard let self else { return }
                        guard self.lastPreciseScrollRequestID == requestID else { return }
                        guard let textView = self.textView,
                            let scrollView = self.containingReaderScrollView(startingAt: textView),
                            let targetSelection = self.preferredPreciseScrollSelection(
                                in: textView.attributedText,
                                fallbackURL: targetURL
                            )
                        else { return }
                        let targetRange = targetSelection.range

                        textView.layoutManager.ensureLayout(for: textView.textContainer)
                        let glyphRange = textView.layoutManager.glyphRange(
                            forCharacterRange: targetRange,
                            actualCharacterRange: nil
                        )
                        var refreshedRect = textView.layoutManager.boundingRect(
                            forGlyphRange: glyphRange,
                            in: textView.textContainer
                        )
                        refreshedRect.origin.x += textView.textContainerInset.left
                        refreshedRect.origin.y += textView.textContainerInset.top

                        let refreshedRectInScrollView = textView.convert(
                            refreshedRect, to: scrollView)
                        let refinedOffsetY = max(
                            -scrollView.adjustedContentInset.top,
                            refreshedRectInScrollView.minY - 18
                        )
                        scrollView.setContentOffset(
                            CGPoint(x: scrollView.contentOffset.x, y: refinedOffsetY),
                            animated: false
                        )
                        if self.isRangeVisible(
                            targetRange,
                            in: textView,
                            scrollView: scrollView
                        ),
                            targetSelection.usedHighlightedRange
                                || !self.preferHighlightedRangeForPreciseScroll
                        {
                            self.onPreciseScrollCompleted?()
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
                                self?.retryHighlightedPreciseScroll(
                                    requestID: requestID,
                                    fallbackURL: targetURL
                                )
                            }
                        }
                    }
                }

                func preferredPreciseScrollSelection(
                    in attributedText: NSAttributedString,
                    fallbackURL: URL
                ) -> (range: NSRange, usedHighlightedRange: Bool)? {
                    if let highlightedRange = firstRange(
                        for: QuranPageView.searchMatchScrollAttribute,
                        in: attributedText
                    ) {
                        return (highlightedRange, true)
                    }
                    guard let fallbackRange = range(of: fallbackURL, in: attributedText) else {
                        return nil
                    }
                    return (fallbackRange, false)
                }

                func retryHighlightedPreciseScroll(requestID: Int, fallbackURL: URL) {
                    guard lastPreciseScrollRequestID == requestID else { return }
                    guard preciseScrollRetryCount < 6 else { return }
                    guard preferHighlightedRangeForPreciseScroll else {
                        onPreciseScrollCompleted?()
                        return
                    }
                    guard let textView,
                        let scrollView = containingReaderScrollView(startingAt: textView)
                    else { return }
                    guard
                        let targetSelection = preferredPreciseScrollSelection(
                            in: textView.attributedText,
                            fallbackURL: fallbackURL
                        )
                    else { return }
                    guard targetSelection.usedHighlightedRange else { return }

                    textView.layoutManager.ensureLayout(for: textView.textContainer)
                    let glyphRange = textView.layoutManager.glyphRange(
                        forCharacterRange: targetSelection.range,
                        actualCharacterRange: nil
                    )
                    var targetRect = textView.layoutManager.boundingRect(
                        forGlyphRange: glyphRange,
                        in: textView.textContainer
                    )
                    targetRect.origin.x += textView.textContainerInset.left
                    targetRect.origin.y += textView.textContainerInset.top

                    let targetRectInScrollView = textView.convert(targetRect, to: scrollView)
                    let targetOffsetY = max(
                        -scrollView.adjustedContentInset.top,
                        targetRectInScrollView.minY - 18
                    )
                    preciseScrollRetryCount += 1
                    scrollView.setContentOffset(
                        CGPoint(x: scrollView.contentOffset.x, y: targetOffsetY),
                        animated: false
                    )
                    if isRangeVisible(targetSelection.range, in: textView, scrollView: scrollView) {
                        onPreciseScrollCompleted?()
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                            self?.retryHighlightedPreciseScroll(
                                requestID: requestID,
                                fallbackURL: fallbackURL
                            )
                        }
                    }
                }

                func isRangeVisible(
                    _ range: NSRange,
                    in textView: UITextView,
                    scrollView: UIScrollView
                ) -> Bool {
                    textView.layoutManager.ensureLayout(for: textView.textContainer)
                    let glyphRange = textView.layoutManager.glyphRange(
                        forCharacterRange: range,
                        actualCharacterRange: nil
                    )
                    var targetRect = textView.layoutManager.boundingRect(
                        forGlyphRange: glyphRange,
                        in: textView.textContainer
                    )
                    targetRect.origin.x += textView.textContainerInset.left
                    targetRect.origin.y += textView.textContainerInset.top

                    let rectInScrollView = textView.convert(targetRect, to: scrollView)
                    let visibleBoundsRect = CGRect(
                        x: 0,
                        y: scrollView.adjustedContentInset.top,
                        width: scrollView.bounds.width,
                        height: scrollView.bounds.height
                            - scrollView.adjustedContentInset.top
                            - scrollView.adjustedContentInset.bottom
                    )
                    return visibleBoundsRect.intersects(rectInScrollView.insetBy(dx: 0, dy: -8))
                }

                func range(of url: URL, in attributedText: NSAttributedString) -> NSRange? {
                    let fullRange = NSRange(location: 0, length: attributedText.length)
                    var foundRange: NSRange?

                    attributedText.enumerateAttribute(.link, in: fullRange) { value, range, stop in
                        guard let linkedURL = value as? URL, linkedURL == url else { return }
                        foundRange = range
                        stop.pointee = true
                    }

                    return foundRange
                }

                func firstRange(
                    for key: NSAttributedString.Key,
                    in attributedText: NSAttributedString
                ) -> NSRange? {
                    let fullRange = NSRange(location: 0, length: attributedText.length)
                    var foundRange: NSRange?

                    attributedText.enumerateAttribute(key, in: fullRange) { value, range, stop in
                        guard value != nil else { return }
                        foundRange = range
                        stop.pointee = true
                    }

                    return foundRange
                }

                func containingReaderScrollView(startingAt view: UIView) -> UIScrollView? {
                    var current = view.superview
                    while let candidate = current {
                        if let scrollView = candidate as? UIScrollView,
                            scrollView !== view,
                            scrollView.isScrollEnabled
                        {
                            return scrollView
                        }
                        current = candidate.superview
                    }
                    return nil
                }

                @objc func handleTap(_ gesture: UITapGestureRecognizer) {
                    guard gesture.state == .ended, let textView else { return }
                    let location = gesture.location(in: textView)
                    guard let url = linkURL(at: location, in: textView) else { return }
                    onTapURL(url)
                }

                @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
                    guard gesture.state == .began, let textView else { return }
                    let location = gesture.location(in: textView)
                    guard let url = linkURL(at: location, in: textView) else { return }
                    onLongPressURL(url)
                }

                func linkURL(at point: CGPoint, in textView: UITextView) -> URL? {
                    guard let position = textView.closestPosition(to: point) else { return nil }
                    var index = textView.offset(from: textView.beginningOfDocument, to: position)
                    let length = textView.attributedText.length
                    guard length > 0 else { return nil }
                    if index >= length { index = length - 1 }
                    if index < 0 { return nil }
                    return textView.attributedText.attribute(.link, at: index, effectiveRange: nil)
                        as? URL
                }

                func gestureRecognizer(
                    _ gestureRecognizer: UIGestureRecognizer,
                    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
                ) -> Bool {
                    false
                }
            }
        }
    }

    // MARK: - VerseRowView (Standard Mode)

    struct VerseRowView: View {
        let verse: Verse
        let isCurrentVerse: Bool
        let isAutoScrolling: Bool
        let showTranslation: Bool
        let fontSize: Double
        let primaryGreen: Color
        let textColor: Color
        let secondaryTextColor: Color
        let onTap: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Verse text + ayah number
                Text(attributedVerseText)

                if showTranslation, let translations = verse.translations,
                    let en = translations.enHilaliKhan
                {
                    Text(en)
                        .font(.system(size: fontSize * 0.75))
                        .foregroundColor(secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .id(verse.id)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isAutoScrolling { onTap() }
            }
        }

        var attributedVerseText: AttributedString {
            let uthmanic = "KFGQPC Uthmanic Script HAFS"
            let hasUthmanic = UIFont(name: uthmanic, size: fontSize) != nil

            var combined = AttributedString(verse.text)
            combined.font =
                hasUthmanic
                ? .custom(uthmanic, size: fontSize)
                : .system(size: fontSize, weight: .regular, design: .serif)
            combined.foregroundColor = isCurrentVerse ? primaryGreen : textColor

            var marker = AttributedString(" ﴿\(verse.id)﴾ ")
            marker.font =
                hasUthmanic
                ? .custom(uthmanic, size: fontSize * 0.75)
                : .system(size: fontSize * 0.8, weight: .bold, design: .rounded)
            marker.foregroundColor = primaryGreen.opacity(isCurrentVerse ? 1.0 : 0.7)

            combined.append(marker)
            return combined
        }
    }
}
