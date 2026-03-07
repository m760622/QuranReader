//
//  QuranPageView+Toolbar.swift
//  QuranReader
//
//  Toolbar-related views and helpers extracted from QuranPageView.
//

import SwiftUI

// MARK: - Toolbar Views
extension QuranPageView {

    // MARK: DualProgressBar
    struct DualProgressBar: View {
        let quranProgress: Double
        let juzProgress: Double
        let primaryColor: Color
        let secondaryColor: Color
        let isNightMode: Bool

        var body: some View {
            HStack(spacing: 8) {
                // Quran Progress (Left side)
                progressItem(
                    progress: quranProgress,
                    color: primaryColor,
                    opacity: isNightMode ? 0.15 : 0.12
                )

                // Juz Progress (Right side)
                progressItem(
                    progress: juzProgress,
                    color: secondaryColor,
                    opacity: isNightMode ? 0.12 : 0.08
                )
            }
            .frame(height: 5)
        }

        @ViewBuilder
        private func progressItem(progress: Double, color: Color, opacity: CGFloat) -> some View {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(opacity))
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: max(4, geo.size.width * CGFloat(progress)))
                        .shadow(color: color.opacity(0.2), radius: 1, x: 0, y: 1)
                }
            }
        }
    }

    // MARK: - Collapsed Top Handle
    var collapsedTopHandle: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Title & Context Section - Now on the RIGHT (First in RTL HStack)
                HStack(spacing: 8) {
                    Button {
                        showSurahList = true
                        lightHaptic()
                    } label: {
                        HStack(spacing: 4) {
                            Text(currentSurahTitle)
                                .font(.system(size: 14, weight: .bold, design: .serif))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(primaryGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(primaryGreen.opacity(viewModel.isNightMode ? 0.15 : 0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    primaryGreen.opacity(viewModel.isNightMode ? 0.25 : 0.15),
                                    lineWidth: 1)
                        )
                    }

                    // Contextual Pill (Juz)
                    pill(
                        text: currentJuzLabel,
                        tint: secondaryAccentColor,
                        dualTone: true
                    )

                // Page Number Pill
                    Text("ص \(chromeMushafPageNumber)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(primaryGreen)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(primaryGreen.opacity(0.1))
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Quick Actions - Now on the LEFT (Last in RTL HStack)
                HStack(spacing: 8) {
                    // Bookmarks
                    Button {
                        showVerseBookmarksList = true
                        lightHaptic()
                    } label: {
                        toolbarIcon("bookmark.fill", tint: .orange)
                    }

                    // Search
                    Button {
                        searchScope = .quran
                        showSearch = true
                        lightHaptic()
                    } label: {
                        toolbarIcon("magnifyingglass", tint: primaryGreen)
                    }

                    // Auto-Scroll Play/Pause
                    Button {
                        if isAutoScrolling {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAutoScrolling = false
                            }
                        } else {
                            activateReadingModeForAutoScrollIfNeeded(starting: true)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAutoScrolling = true
                            }
                        }
                        lightHaptic()
                    } label: {
                        toolbarIcon(
                            isAutoScrolling ? "pause.fill" : "play.fill", tint: primaryGreen)
                    }
                }
            }
            .padding(.horizontal, 4)

            // Distinctive Full-Width Progress
            DualProgressBar(
                quranProgress: viewModel.readingProgress,
                juzProgress: viewModel.juzProgress,
                primaryColor: primaryGreen,
                secondaryColor: secondaryAccentColor,
                isNightMode: viewModel.isNightMode
            )
            .padding(.top, 4)  // Add breathing room
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(backgroundColor)
        .overlay(Divider().opacity(0.35), alignment: .bottom)  // Soften Divider
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Top Navigation Bar
    var topNavigationBar: some View {
        standardTopNavigationBar
            .background(backgroundColor)
            .overlay(Divider().opacity(0.35), alignment: .bottom)  // Soften Divider
    }

    var standardTopNavigationBar: some View {
        VStack(spacing: 0) {
            // Row 1: Focus Header
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Button {
                            showSurahList = true
                            lightHaptic()
                        } label: {
                            HStack(spacing: 4) {
                                Text(currentSurahTitle)
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(primaryGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(primaryGreen.opacity(viewModel.isNightMode ? 0.15 : 0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        primaryGreen.opacity(viewModel.isNightMode ? 0.25 : 0.15),
                                        lineWidth: 1)
                            )
                        }

                        // Context Information (Integrated)
                        HStack(spacing: 6) {
                            pill(
                                text: currentJuzLabel,
                                tint: secondaryAccentColor,
                                dualTone: true
                            )

                            Text(currentHizbLabel)
                                .font(.system(size: 9).weight(.semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundColor(secondaryTextColor)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(
                            "\(viewModel.currentSurah?.verses.count ?? 0) آية • \(currentSurahSubtitle)"
                        )
                        .foregroundColor(secondaryTextColor.opacity(0.8))

                        if !currentJuzRemainingTimeStatusLabel.isEmpty {
                            Text(currentJuzRemainingTimeStatusLabel)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange.opacity(0.92))
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                }

                Spacer()

                standardTopHeaderActions
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Row 2: Streamlined Premium Ribbon
            HStack(spacing: 12) {
                standardPagerControl

                // Contemporary Slider — always in mushaf-page space
                Slider(
                    value: Binding(
                        get: {
                            isJumpSliderEditing ? jumpSliderValue : Double(chromeMushafPageNumber)
                        },
                        set: { jumpSliderValue = $0 }
                    ),
                    in: 1...Double(max(viewModel.maxMushafPage, 1)),
                    step: 1,
                    onEditingChanged: { editing in
                        isJumpSliderEditing = editing
                        if !editing {
                            goToMushafPage(Int(jumpSliderValue))
                            lightHaptic()
                        }
                    }
                )
                .tint(primaryGreen)
                .controlSize(.mini)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(viewModel.isNightMode ? 0.2 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(primaryGreen.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)

            // Row 3: Visual Progress (Ghost Bar)
            DualProgressBar(
                quranProgress: viewModel.readingProgress,
                juzProgress: viewModel.juzProgress,
                primaryColor: primaryGreen,
                secondaryColor: secondaryAccentColor,
                isNightMode: viewModel.isNightMode
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Header Actions
    var standardTopHeaderActions: some View {
        HStack(spacing: 8) {
            // Auto-Scroll Play/Pause
            Button {
                if isAutoScrolling {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAutoScrolling = false
                    }
                } else {
                    activateReadingModeForAutoScrollIfNeeded(starting: true)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAutoScrolling = true
                    }
                }
                lightHaptic()
            } label: {
                toolbarIcon(
                    isAutoScrolling ? "pause.fill" : "play.fill", tint: primaryGreen)
            }

            // Bookmarks
            Button {
                showVerseBookmarksList = true
                lightHaptic()
            } label: {
                toolbarIcon("bookmark.fill", tint: .orange)
            }

            // Search
            Button {
                searchScope = .quran
                showSearch = true
                lightHaptic()
            } label: {
                toolbarIcon("magnifyingglass", tint: primaryGreen)
            }

            // Settings - Far Left
            Button {
                showSettingsSheet = true
                lightHaptic()
            } label: {
                toolbarIcon("gearshape.fill", tint: secondaryTextColor)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Pager Control
    var standardPagerControl: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation { navigatePrevious() }
                lightHaptic()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(
                        canNavigatePrevious ? textColor : secondaryTextColor
                    )
                    .frame(width: 24, height: 24)
            }
            .disabled(!canNavigatePrevious)

            Text(pagerCenterLabel)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(primaryGreen)
                .frame(minWidth: 28)

            Button {
                withAnimation { navigateNext() }
                lightHaptic()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(
                        canNavigateNext ? textColor : secondaryTextColor
                    )
                    .frame(width: 24, height: 24)
            }
            .disabled(!canNavigateNext)
        }
    }

    // MARK: - Toolbar Helper Views
    func toolbarIcon(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .rotationEffect(.degrees(systemName == "play.fill" ? 90 : 0))
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(viewModel.isNightMode ? 0.25 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(tint.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    func pill(text: String, tint: Color, dualTone: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(dualTone ? .white : tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                dualTone
                    ? AnyView(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.8)], startPoint: .topLeading,
                            endPoint: .bottomTrailing))
                    : AnyView(tint.opacity(0.12))
            )
            .clipShape(Capsule())
            .shadow(color: dualTone ? tint.opacity(0.3) : .clear, radius: 2, x: 0, y: 1)
    }

    func modeBadge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundColor(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(viewModel.isNightMode ? 0.14 : 0.10))
                    .overlay(
                        Capsule()
                            .stroke(
                                tint.opacity(viewModel.isNightMode ? 0.25 : 0.18), lineWidth: 0.8)
                    )
            )
    }

    func quickNavigatorActionPill(
        title: String,
        systemImage: String,
        tint: Color,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .rotationEffect(.degrees(systemImage == "play.fill" ? 90 : 0))
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundColor(isActive ? .white : tint)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isActive ? tint : tint.opacity(viewModel.isNightMode ? 0.18 : 0.10))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(isActive ? 0.15 : 0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
