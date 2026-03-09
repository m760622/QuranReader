//
//  QuranPageView+Settings.swift
//  QuranReader
//
//  Settings sheet view extracted from QuranPageView.
//

import SwiftUI

// MARK: - Settings Sheet
extension QuranPageView {
    struct SettingsSheetView: View {
        @EnvironmentObject var viewModel: QuranPageViewModel
        @AppStorage("readerFontSize") var fontSize: Double = 28
        @AppStorage("readerLineSpacing") var lineSpacing: Double = 25
        @AppStorage("readerFontSelection") var readerFontSelection: String = "auto"
        @AppStorage("readerSurahTitleFontSelection") var readerSurahTitleFontSelection: String =
            "auto"
        @AppStorage("readerBasmalaFontSelection") var readerBasmalaFontSelection: String = "auto"
        @AppStorage("readerFontWeight") var readerFontWeightRawValue: String =
            ReaderFontWeightOption.regular.rawValue
        @AppStorage("useHaptics") var useHaptics: Bool = true
        @AppStorage("showTranslation") var showTranslation: Bool = false
        @AppStorage("readerMode") var readerModeRawValue: String = ReaderMode.mushafPage.rawValue
        @AppStorage("mushafPageNumber") var mushafPageNumber: Int = 1
        @AppStorage("searchHistory") var searchHistoryData: Data = Data()
        @AppStorage("readerDayTextColor") var dayTextColorData: Data = Data()
        @AppStorage("readerNightTextColor") var nightTextColorData: Data = Data()
        @AppStorage("readerDayBackgroundColor") var dayBackgroundColorData: Data = Data()
        @AppStorage("readerNightBackgroundColor") var nightBackgroundColorData: Data =
            Data()
        @AppStorage("readerDayHighlightColor") var dayHighlightColorData: Data = Data()
        @AppStorage("readerNightHighlightColor") var nightHighlightColorData: Data = Data()
        @AppStorage("readerPrimaryColor") var primaryColorData: Data = Data()
        @AppStorage("readerSecondaryColor") var secondaryColorData: Data = Data()
        @AppStorage("readerDayPrimaryColor") var dayPrimaryColorData: Data = Data()
        @AppStorage("readerNightPrimaryColor") var nightPrimaryColorData: Data = Data()
        @AppStorage("readerDaySecondaryColor") var daySecondaryColorData: Data = Data()
        @AppStorage("readerNightSecondaryColor") var nightSecondaryColorData: Data = Data()
        @AppStorage("readerDaySurfaceColor") var daySurfaceColorData: Data = Data()
        @AppStorage("readerNightSurfaceColor") var nightSurfaceColorData: Data = Data()
        @AppStorage("showInternalFontNames") var showInternalFontNames: Bool = false
        @AppStorage("enableReaderDiagnostics") var enableReaderDiagnostics: Bool = false
        @AppStorage("showClock") var showClock: Bool = true
        @AppStorage("showBattery") var showBattery: Bool = true
        @Binding var jumpSliderValue: Double
        @Binding var autoScrollMinutesPerPage: Double
        @Environment(\.dismiss) var dismiss
        @State var showClearFavoritesConfirmation = false
        @State var showClearRecentsConfirmation = false
        @State var showClearSearchHistoryConfirmation = false
        @State var showClearVerseBookmarksConfirmation = false

        var readerMode: ReaderMode {
            ReaderMode(rawValue: readerModeRawValue) ?? .surah
        }

        var isMushafPageMode: Bool {
            true
        }

        var searchHistoryCount: Int {
            (try? JSONDecoder().decode([String].self, from: searchHistoryData))?.count ?? 0
        }

        var fontWeightOption: ReaderFontWeightOption {
            ReaderFontWeightOption(rawValue: readerFontWeightRawValue) ?? .regular
        }

        var systemFontDesign: Font.Design {
            readerFontDesign(for: readerFontSelection)
        }

        var resolvedCustomFontName: String? {
            resolveReaderFontName(
                selection: readerFontSelection,
                size: 18,
                autoCandidates: quranFontCandidates
            )
        }

        var previewFont: Font {
            if let custom = resolvedCustomFontName {
                return .custom(custom, size: 28)
            }
            return .system(size: 28, weight: fontWeightOption.fontWeight, design: systemFontDesign)
        }

        var dayTextColorBinding: Binding<Color> {
            Binding(
                get: { storedColor(from: dayTextColorData, fallback: .black) },
                set: { dayTextColorData = encodeStoredColor($0) }
            )
        }

        var nightTextColorBinding: Binding<Color> {
            Binding(
                get: {
                    storedColor(
                        from: nightTextColorData, fallback: Color(red: 0.9, green: 0.9, blue: 0.9))
                },
                set: { nightTextColorData = encodeStoredColor($0) }
            )
        }

        var dayBackgroundColorBinding: Binding<Color> {
            Binding(
                get: {
                    storedColor(
                        from: dayBackgroundColorData,
                        fallback: Color(red: 0.97, green: 0.95, blue: 0.91))
                },
                set: { dayBackgroundColorData = encodeStoredColor($0) }
            )
        }

        var dayHighlightColorBinding: Binding<Color> {
            Binding(
                get: {
                    storedColor(from: dayHighlightColorData, fallback: Color.yellow.opacity(0.34))
                },
                set: { dayHighlightColorData = encodeStoredColor($0) }
            )
        }

        var nightBackgroundColorBinding: Binding<Color> {
            Binding(
                get: {
                    storedColor(
                        from: nightBackgroundColorData,
                        fallback: Color(red: 0.1, green: 0.12, blue: 0.15))
                },
                set: { nightBackgroundColorData = encodeStoredColor($0) }
            )
        }

        var nightHighlightColorBinding: Binding<Color> {
            Binding(
                get: {
                    storedColor(from: nightHighlightColorData, fallback: Color.orange.opacity(0.34))
                },
                set: { nightHighlightColorData = encodeStoredColor($0) }
            )
        }

        var dayPrimaryColorBinding: Binding<Color> {
            Binding(
                get: {
                    let legacy = storedColor(from: primaryColorData, fallback: Color(hex: "00713D"))
                    return storedColor(from: dayPrimaryColorData, fallback: legacy)
                },
                set: { dayPrimaryColorData = encodeStoredColor($0) }
            )
        }

        var nightPrimaryColorBinding: Binding<Color> {
            Binding(
                get: {
                    let legacy = storedColor(from: primaryColorData, fallback: Color(hex: "00713D"))
                    return storedColor(from: nightPrimaryColorData, fallback: legacy)
                },
                set: { nightPrimaryColorData = encodeStoredColor($0) }
            )
        }

        var daySecondaryColorBinding: Binding<Color> {
            Binding(
                get: {
                    let legacy = storedColor(from: secondaryColorData, fallback: .orange)
                    return storedColor(from: daySecondaryColorData, fallback: legacy)
                },
                set: { daySecondaryColorData = encodeStoredColor($0) }
            )
        }

        var nightSecondaryColorBinding: Binding<Color> {
            Binding(
                get: {
                    let legacy = storedColor(from: secondaryColorData, fallback: .orange)
                    return storedColor(from: nightSecondaryColorData, fallback: legacy)
                },
                set: { nightSecondaryColorData = encodeStoredColor($0) }
            )
        }

        var daySurfaceColorBinding: Binding<Color> {
            Binding(
                get: {
                    storedColor(from: daySurfaceColorData, fallback: Color.white.opacity(0.72))
                },
                set: { daySurfaceColorData = encodeStoredColor($0) }
            )
        }

        var nightSurfaceColorBinding: Binding<Color> {
            Binding(
                get: {
                    storedColor(from: nightSurfaceColorData, fallback: Color.white.opacity(0.06))
                },
                set: { nightSurfaceColorData = encodeStoredColor($0) }
            )
        }

        var body: some View {
            NavigationView {
                settingsContent
            }
            .preferredColorScheme(viewModel.isNightMode ? .dark : .light)
        }

        var settingsContent: some View {
            VStack(spacing: 0) {
                Form {
                    systemInfoSection
                    // readingModeSection removed – always mushafPage
                    appearanceSection
                    fontSelectionSection
                    fontSizingSection
                    if viewModel.isNightMode {
                        nightThemesSection
                        nightColorsSection
                    } else {
                        dayColorsSection
                    }
                    autoScrollSection
                    otherOptionsSection
                    dataSection
                    quickActionsSection
                }
            }
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("تم") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundColor(primaryGreen)
                }
            }
            .confirmationDialog(
                "مسح مفضلة السور؟",
                isPresented: $showClearFavoritesConfirmation,
                titleVisibility: .visible
            ) {
                Button("مسح مفضلة السور", role: .destructive) {
                    viewModel.clearFavorites()
                }
                Button("إلغاء", role: .cancel) {}
            }
            .confirmationDialog(
                "مسح الأخيرة؟",
                isPresented: $showClearRecentsConfirmation,
                titleVisibility: .visible
            ) {
                Button("مسح الأخيرة", role: .destructive) {
                    viewModel.clearRecentSurahs()
                }
                Button("إلغاء", role: .cancel) {}
            }
            .confirmationDialog(
                "مسح سجل البحث؟",
                isPresented: $showClearSearchHistoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("مسح سجل البحث", role: .destructive) {
                    searchHistoryData = Data()
                }
                Button("إلغاء", role: .cancel) {}
            }
            .confirmationDialog(
                "مسح مفضلة الآيات؟",
                isPresented: $showClearVerseBookmarksConfirmation,
                titleVisibility: .visible
            ) {
                Button("مسح مفضلة الآيات", role: .destructive) {
                    viewModel.clearVerseBookmarks()
                }
                Button("إلغاء", role: .cancel) {}
            }
            .environment(\.layoutDirection, .rightToLeft)
            .onAppear {
                jumpSliderValue = Double(mushafPageNumber)
            }
        }

        @ViewBuilder
        var systemInfoSection: some View {
            Section(header: Text("شريط النظام").font(.headline)) {
                Toggle(isOn: $showClock) {
                    Label("إظهار شريط الساعة والبطارية (أيقونات الأيفون)", systemImage: "iphone")
                }
                .tint(primaryGreen)
            }
        }

        @ViewBuilder
        var readingModeSection: some View {
            Section(header: Text("نمط القراءة").font(.headline)) {
                Picker("نمط القراءة", selection: $readerModeRawValue) {
                    ForEach(ReaderMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }

        @ViewBuilder
        var appearanceSection: some View {
            Section(header: Text("المظهر").font(.headline)) {
                Toggle(isOn: $viewModel.isNightMode) {
                    Label("الوضع الليلي", systemImage: "moon.stars.fill")
                }
                .tint(primaryGreen)
                Toggle(isOn: $useHaptics) {
                    Label("الاهتزازات", systemImage: "iphone.radiowaves.left.and.right")
                }
                .tint(primaryGreen)
            }
        }

        @ViewBuilder
        var fontSelectionSection: some View {
            Section(header: Text("الخطوط").font(.headline)) {
                Toggle("إظهار الاسم الداخلي للخط", isOn: $showInternalFontNames)
                    .tint(primaryGreen)
                verseFontTypePicker
                surahTitleFontPicker
                basmalaFontPicker
                fontWeightPicker
                fontPreview
            }
        }

        var verseFontTypePicker: some View {
            Picker("خط نص المصحف", selection: $readerFontSelection) {
                Text("تلقائي (عثماني)").tag("auto")
                Text("نظامي (سيرف)").tag("system-serif")
                Text("نظامي (افتراضي)").tag("system-default")
                Text("نظامي (مستدير)").tag("system-rounded")
                fontMenuSections
            }
            .pickerStyle(.menu)
        }

        var surahTitleFontPicker: some View {
            Picker("خط عنوان السورة", selection: $readerSurahTitleFontSelection) {
                Text("تلقائي (عنوان موصى به)").tag("auto")
                Text("نظامي (سيرف)").tag("system-serif")
                fontMenuSections
            }
            .pickerStyle(.menu)
        }

        var basmalaFontPicker: some View {
            Picker("خط البسملة", selection: $readerBasmalaFontSelection) {
                Text("تلقائي (A Suls)").tag("auto")
                Text("نظامي (سيرف)").tag("system-serif")
                fontMenuSections
            }
            .pickerStyle(.menu)
        }

        @ViewBuilder
        var fontMenuSections: some View {
            ForEach(readerCustomFontSections) { section in
                Section(section.title) {
                    ForEach(section.fonts) { fontOption in
                        Text(
                            showInternalFontNames
                                ? fontPickerLabel(
                                    for: fontOption,
                                    showingInternalName: true
                                )
                                : fontPickerLabel(
                                    for: fontOption,
                                    showingInternalName: false
                                )
                        )
                        .tag("custom:\(fontOption.postScriptName)")
                    }
                }
            }
        }

        func fontPickerLabel(
            for fontOption: ReaderCustomFontOption,
            showingInternalName: Bool
        ) -> String {
            var parts: [String] = ["خط: \(fontOption.displayName)"]
            if let recommendation = fontOption.recommendation {
                parts.append(recommendation)
            }
            if showingInternalName {
                parts.append(fontOption.postScriptName)
            }
            return parts.joined(separator: " • ")
        }

        var fontWeightPicker: some View {
            Picker("السماكة", selection: $readerFontWeightRawValue) {
                ForEach(ReaderFontWeightOption.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .pickerStyle(.menu)
        }

        var fontPreview: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("معاينة")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                    .font(previewFont)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gray.opacity(0.10))
                    )
            }
            .padding(.vertical, 4)
        }

        @ViewBuilder
        var fontSizingSection: some View {
            Section(header: Text("إعدادات الخط").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("حجم الخط", systemImage: "textformat.size")
                        Spacer()
                        Text("\(Int(fontSize))")
                            .font(.caption.monospacedDigit())
                    }
                    Slider(value: $fontSize, in: 18...60, step: 1)
                        .tint(primaryGreen)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(
                            "تباعد الأسطر", systemImage: "arrow.up.and.down.text.horizontal"
                        )
                        Spacer()
                        Text("\(Int(lineSpacing))")
                            .font(.caption.monospacedDigit())
                    }
                    Slider(value: $lineSpacing, in: 14...60, step: 1)
                        .tint(secondaryAccentColor)
                }
                .padding(.vertical, 4)
            }
        }

        @ViewBuilder
        var dayColorsSection: some View {
            Section(header: Text("ألوان النهار").font(.headline)) {
                ColorPicker("Primary", selection: dayPrimaryColorBinding, supportsOpacity: false)
                ColorPicker(
                    "Secondary", selection: daySecondaryColorBinding, supportsOpacity: false)
                ColorPicker(
                    "لون الخلفية", selection: dayBackgroundColorBinding, supportsOpacity: true)
                ColorPicker(
                    "لون البطاقات", selection: daySurfaceColorBinding, supportsOpacity: true)
                ColorPicker("لون النص", selection: dayTextColorBinding, supportsOpacity: true)
                ColorPicker(
                    "لون التضليل", selection: dayHighlightColorBinding, supportsOpacity: true)
            }
        }

        // MARK: - Night Mode Themes
        struct NightTheme: Identifiable {
            let id: String
            let name: String
            let primary: Color
            let background: Color
            let surface: Color
            let text: Color
            let highlight: Color
        }

        var nightThemes: [NightTheme] {
            [
                NightTheme(
                    id: "royal",
                    name: "الملكي",
                    primary: Color(red: 0.77, green: 0.63, blue: 0.35),  // Golden Sand
                    background: Color(red: 0.04, green: 0.07, blue: 0.12),  // Deep Navy
                    surface: Color(red: 0.04, green: 0.07, blue: 0.12).opacity(0.8),
                    text: Color(white: 0.88),
                    highlight: Color(red: 0.77, green: 0.63, blue: 0.35).opacity(0.15)
                ),
                NightTheme(
                    id: "professional",
                    name: "الاحترافي",
                    primary: Color(red: 0.18, green: 0.55, blue: 0.34),  // Soft Emerald
                    background: Color(red: 0.07, green: 0.07, blue: 0.07),  // Midnight Grey
                    surface: Color(red: 0.12, green: 0.12, blue: 0.12),
                    text: Color(white: 0.9),
                    highlight: Color(red: 0.18, green: 0.55, blue: 0.34).opacity(0.2)
                ),
                NightTheme(
                    id: "default",
                    name: "الافتراضي",
                    primary: Color(hex: "00713D"),
                    background: Color(red: 0.1, green: 0.12, blue: 0.15),
                    surface: Color.white.opacity(0.06),
                    text: Color(red: 0.9, green: 0.9, blue: 0.9),
                    highlight: Color.orange.opacity(0.34)
                ),
            ]
        }

        @ViewBuilder
        var nightThemesSection: some View {
            Section(header: Text("ثيمات الوضع الليلي").font(.headline)) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(nightThemes) { theme in
                            Button {
                                applyNightTheme(theme)
                                performLightHaptic(enabled: useHaptics)
                            } label: {
                                VStack(spacing: 8) {
                                    // Theme Preview Circle
                                    ZStack {
                                        Circle()
                                            .fill(theme.background)
                                            .frame(width: 50, height: 50)
                                            .shadow(radius: 2)

                                        Circle()
                                            .strokeBorder(theme.primary, lineWidth: 3)
                                            .frame(width: 44, height: 44)

                                        Text("آ")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(theme.text)
                                    }

                                    Text(theme.name)
                                        .font(.caption2.weight(.medium))
                                        .foregroundColor(.primary)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            isCurrentTheme(theme)
                                                ? theme.primary.opacity(0.12) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            isCurrentTheme(theme) ? theme.primary : Color.clear,
                                            lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }

        func applyNightTheme(_ theme: NightTheme) {
            nightPrimaryColorData = encodeStoredColor(theme.primary)
            nightBackgroundColorData = encodeStoredColor(theme.background)
            nightSurfaceColorData = encodeStoredColor(theme.surface)
            nightTextColorData = encodeStoredColor(theme.text)
            nightHighlightColorData = encodeStoredColor(theme.highlight)
            nightSecondaryColorData = encodeStoredColor(theme.primary)  // Optional: match secondary to primary
        }

        func isCurrentTheme(_ theme: NightTheme) -> Bool {
            // Simple check based on background color
            let currentBG = storedColor(
                from: nightBackgroundColorData, fallback: Color(red: 0.1, green: 0.12, blue: 0.15))
            return currentBG == theme.background
        }

        var nightColorsSection: some View {
            Section(header: Text("ألوان الليل").font(.headline)) {
                ColorPicker("Primary", selection: nightPrimaryColorBinding, supportsOpacity: false)
                ColorPicker(
                    "Secondary", selection: nightSecondaryColorBinding, supportsOpacity: false)
                ColorPicker(
                    "لون الخلفية", selection: nightBackgroundColorBinding, supportsOpacity: true)
                ColorPicker(
                    "لون البطاقات", selection: nightSurfaceColorBinding, supportsOpacity: true)
                ColorPicker("لون النص", selection: nightTextColorBinding, supportsOpacity: true)
                ColorPicker(
                    "لون التضليل", selection: nightHighlightColorBinding, supportsOpacity: true)
            }
        }

        @ViewBuilder
        var autoScrollSection: some View {
            Section(header: Text("التمرير التلقائي").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("وقت قراءة الصفحة", systemImage: "clock")
                        Spacer()
                        Text(String(format: "%.1f د", autoScrollMinutesPerPage))
                            .font(.caption.monospacedDigit())
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "hare.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Slider(value: $autoScrollMinutesPerPage, in: 0.5...10, step: 0.5)
                            .tint(primaryGreen)
                        Image(systemName: "tortoise.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
        }

        @ViewBuilder
        var otherOptionsSection: some View {
            Section(header: Text("خيارات أخرى").font(.headline)) {
                Toggle(isOn: $showTranslation) {
                    Label("إظهار الترجمة", systemImage: "globe")
                }
                .tint(primaryGreen)

                Toggle(isOn: $enableReaderDiagnostics) {
                    Label("تشخيص التمرير (DEBUG)", systemImage: "ladybug")
                }
                .tint(primaryGreen)

                Button {
                    fontSize = 28
                    lineSpacing = 25
                    autoScrollMinutesPerPage = 2.0
                    readerFontSelection = "auto"
                    readerSurahTitleFontSelection = "auto"
                    readerBasmalaFontSelection = "auto"
                    readerFontWeightRawValue = ReaderFontWeightOption.regular.rawValue
                    dayTextColorData = Data()
                    nightTextColorData = Data()
                    dayBackgroundColorData = Data()
                    nightBackgroundColorData = Data()
                    dayHighlightColorData = Data()
                    nightHighlightColorData = Data()
                    primaryColorData = Data()
                    secondaryColorData = Data()
                    dayPrimaryColorData = Data()
                    nightPrimaryColorData = Data()
                    daySecondaryColorData = Data()
                    nightSecondaryColorData = Data()
                    daySurfaceColorData = Data()
                    nightSurfaceColorData = Data()
                } label: {
                    Label("إعادة ضبط الإعدادات", systemImage: "arrow.counterclockwise")
                        .foregroundColor(primaryGreen)
                }
            }
        }

        @ViewBuilder
        var dataSection: some View {
            Section(header: Text("البيانات").font(.headline)) {
                Button(role: .destructive) {
                    showClearFavoritesConfirmation = true
                } label: {
                    Label(
                        "مسح مفضلة السور (\(viewModel.favoriteIDs.count))",
                        systemImage: "heart.slash"
                    )
                }
                .disabled(viewModel.favoriteIDs.isEmpty)

                Button(role: .destructive) {
                    showClearRecentsConfirmation = true
                } label: {
                    Label(
                        "مسح الأخيرة (\(viewModel.recentSurahIndices.count))",
                        systemImage: "trash"
                    )
                }
                .disabled(viewModel.recentSurahIndices.isEmpty)

                Button(role: .destructive) {
                    showClearSearchHistoryConfirmation = true
                } label: {
                    Label(
                        "مسح سجل البحث (\(searchHistoryCount))",
                        systemImage: "clock.arrow.circlepath"
                    )
                }
                .disabled(searchHistoryCount == 0)

                Button(role: .destructive) {
                    showClearVerseBookmarksConfirmation = true
                } label: {
                    Label(
                        "مسح مفضلة الآيات (\(viewModel.bookmarkedVerseKeys.count))",
                        systemImage: "bookmark.slash"
                    )
                }
                .disabled(viewModel.bookmarkedVerseKeys.isEmpty)
            }
        }

        @ViewBuilder
        var quickActionsSection: some View {
            Section(header: Text("الإجراءات السريعة").font(.headline)) {
                if let surah = viewModel.currentSurah {
                    Button {
                        viewModel.toggleFavorite(surahId: surah.id)
                    } label: {
                        Label(
                            viewModel.isFavorite(surahId: surah.id)
                                ? "إزالة السورة من المفضلة" : "إضافة السورة للمفضلة",
                            systemImage: viewModel.isFavorite(surahId: surah.id)
                                ? "heart.fill" : "heart"
                        )
                        .foregroundColor(.red)
                    }
                }
                Button {
                    dismiss()
                } label: {
                    Label("إغلاق", systemImage: "xmark.circle")
                        .foregroundColor(.secondary)
                }
            }
        }

        var primaryGreen: Color {
            let legacy = storedColor(from: primaryColorData, fallback: Color(hex: "00713D"))
            return viewModel.isNightMode
                ? storedColor(from: nightPrimaryColorData, fallback: legacy)
                : storedColor(from: dayPrimaryColorData, fallback: legacy)
        }

        var secondaryAccentColor: Color {
            let legacy = storedColor(from: secondaryColorData, fallback: .orange)
            return viewModel.isNightMode
                ? storedColor(from: nightSecondaryColorData, fallback: legacy)
                : storedColor(from: daySecondaryColorData, fallback: legacy)
        }
    }
}
