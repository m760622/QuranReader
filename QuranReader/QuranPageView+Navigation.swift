//
//  QuranPageView+Navigation.swift
//  QuranReader
//
//  Scroll logic and navigation helpers extracted from QuranPageView.
//

import SwiftUI

extension QuranPageView {
    // MARK: - Scroll Logic

    func restoreScrollPosition(proxy: ScrollViewProxy) {
        if handlePendingScrollIfNeeded(proxy: proxy) { return }

        let checkpointVerseId: Int? = {
            guard checkpointRestoreSurahIndex == viewModel.currentSurahIndex else { return nil }
            return checkpointRestoreVerseId
        }()

        if let checkpointVerseId, checkpointVerseId > 1 {
            beginVerseTrackingSuppression()
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(verseAnchorID(checkpointVerseId), anchor: .top)
            }
            checkpointRestoreSurahIndex = nil
            checkpointRestoreVerseId = nil
            return
        }

        if viewModel.lastScrollOffset <= 10 {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo("TOP", anchor: .top)
            }
        }
    }

    func handleAutoScrollToggle(active: Bool, proxy: ScrollViewProxy) {
        autoScrollTask?.cancel()
        autoScrollTask = nil
        autoScrollAdvancingSurah = false
        autoScrollCarry = 0

        guard active else {
            if let scrollView = resolvedScrollView {
                let offset = max(
                    0,
                    Double(scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
                )
                if abs(viewModel.lastScrollOffset - offset) > 1 {
                    viewModel.lastScrollOffset = offset
                }
            }
            return
        }

        autoScrollTask = Task {
            while !Task.isCancelled {
                let minutesPerPage: Double = await MainActor.run { autoScrollMinutesPerPage }
                let updatesPerSecond: Double = await MainActor.run { reduceMotion ? 20.0 : 30.0 }
                // Assuming a standard page is roughly 1200 points.
                let pointsPerSecond = 1200.0 / (minutesPerPage * 60.0)
                let pointsPerUpdate = CGFloat(pointsPerSecond / updatesPerSecond)
                let delayNanoseconds = UInt64(1_000_000_000 / updatesPerSecond)

                await MainActor.run {
                    guard isAutoScrolling else { return }
                    guard let scrollView = resolvedScrollView else { return }
                    guard !scrollView.isDragging, !scrollView.isDecelerating else { return }

                    let minOffsetY = -scrollView.adjustedContentInset.top
                    let maxOffsetY = max(
                        minOffsetY,
                        scrollView.contentSize.height - scrollView.bounds.height
                            + scrollView.adjustedContentInset.bottom
                    )

                    autoScrollCarry += pointsPerUpdate
                    let delta = CGFloat(Int(autoScrollCarry))
                    guard delta >= 1 else { return }
                    autoScrollCarry -= delta

                    let nextY = min(scrollView.contentOffset.y + delta, maxOffsetY)
                    scrollView.setContentOffset(
                        CGPoint(x: scrollView.contentOffset.x, y: nextY),
                        animated: false
                    )

                    if nextY >= (maxOffsetY - 0.5) {
                        isAutoScrolling = false
                        showToast("وصلت لنهاية المحتوى")
                    }
                }

                guard !Task.isCancelled else { break }
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
        }
    }

    func handleScrollOffsetGeometryChange(_ newY: CGFloat) {
        let offset = max(0, Double(-newY))

        if isAutoScrolling {
            // Avoid hammering @AppStorage/UserDefaults and spawning scroll handling tasks at high frequency.
            let now = CFAbsoluteTimeGetCurrent()
            if (now - lastAutoScrollPersistAt) >= 0.5 {
                lastAutoScrollPersistAt = now
                if abs(viewModel.lastScrollOffset - offset) > 8 {
                    viewModel.lastScrollOffset = offset
                }
            }
            return
        }

        // Reduce noisy writes from tiny geometry jitter.
        if abs(viewModel.lastScrollOffset - offset) > 0.75 || offset <= 1 {
            viewModel.lastScrollOffset = offset
        }

        handleReaderScroll(offset: offset)
    }

    func registerMushafPageAnchor(page: Int, minYInScrollSpace: CGFloat) {
        let contentOffsetY = CGFloat(max(0, viewModel.lastScrollOffset))
        let contentY = minYInScrollSpace + contentOffsetY
        guard contentY.isFinite else { return }

        let previous = mushafPageAnchorYByPage[page] ?? contentY
        if abs(previous - contentY) > 1.5 {
            mushafPageAnchorYByPage[page] = contentY
        } else if mushafPageAnchorYByPage[page] == nil {
            mushafPageAnchorYByPage[page] = contentY
        }
    }

    var mushafPageTrackingTopBias: CGFloat {
        var bias: CGFloat = isTopChromeCollapsed ? 10 : 16
        if showQuickNavigator && !isTopChromeCollapsed { bias += 8 }

        return bias
    }

    func syncVisibleMushafPageFromOffset(_ offset: Double) {
        guard Date() >= suppressChromeScrollUntil else { return }

        // Handle pending jump timeout or clear if reached
        if pendingMushafScrollTargetPage != nil {
            let now = CFAbsoluteTimeGetCurrent()
            // If we've been waiting for a jump for more than 1.5 seconds, clear it.
            // This prevents the "Sync Lock" where the toolbar is stuck while content is elsewhere.
            if lastMushafJumpAt > 0 && (now - lastMushafJumpAt) > 1.5 {
                pendingMushafScrollTargetPage = nil
            }
        }

        guard pendingMushafScrollTargetPage == nil else { return }
        guard !mushafPageAnchorYByPage.isEmpty else { return }

        // PERFORMANCE: Throttled anchor sorting
        let now = CFAbsoluteTimeGetCurrent()
        if (now - lastMushafScrollThrottledAt) < 0.04 { return }
        lastMushafScrollThrottledAt = now

        let referenceY = CGFloat(offset) + hiddenChromeReaderTopInset + mushafPageTrackingTopBias

        let sortedAnchors = mushafPageAnchorYByPage.sorted { $0.value < $1.value }
        guard let first = sortedAnchors.first else { return }

        var candidate = first
        for anchor in sortedAnchors {
            if anchor.value <= referenceY {
                candidate = anchor
            } else {
                // Find closest between candidate and current
                let currentDist = abs(candidate.value - referenceY)
                let nextDist = abs(anchor.value - referenceY)
                if nextDist < currentDist {
                    candidate = anchor
                }
                break
            }
        }

        let candidatePage = candidate.key
        syncVisibleMushafPage(candidatePage)
    }

    func syncVisibleMushafPage(_ page: Int) {
        guard Date() >= suppressChromeScrollUntil else { return }

        // Clear pending jumps BEFORE any early return checks!
        if let startupTarget = startupMushafRestorePage {
            if page == startupTarget {
                startupMushafRestorePage = nil
            }
        }

        let isPendingTargetMatch: Bool
        if let targetPage = pendingMushafScrollTargetPage {
            if page == targetPage {
                pendingMushafScrollTargetPage = nil
                isPendingTargetMatch = true
            } else {
                isPendingTargetMatch = false
            }
        } else {
            isPendingTargetMatch = false
        }

        // Determine if any synchronization is needed to avoid redundant work while ensuring full state sync.
        let needsStoredPageUpdate = storedMushafPageNumber != page
        let needsStandardPageUpdate = currentStandardPage != page
        let needsSliderUpdate = Int(jumpSliderValue) != page

        if let firstSection = mushafIndexByPage[page]?.first {
            let surahIndex =
                viewModel.surahs.firstIndex(where: { $0.id == firstSection.surah.id })
                ?? viewModel.currentSurahIndex
            let needsSurahUpdate = viewModel.currentSurahIndex != surahIndex

            // If we just matched a pending target, FORCE a state update without early returning!
            if !isPendingTargetMatch && !needsStoredPageUpdate && !needsStandardPageUpdate
                && !needsSliderUpdate
                && !needsSurahUpdate
            {
                return
            }
        } else if !isPendingTargetMatch && !needsStoredPageUpdate && !needsStandardPageUpdate
            && !needsSliderUpdate
        {
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        if (now - lastMushafVisiblePageSyncAt) < 0.15 {
            // Throttle hit: Setup trailing debounce
            pendingMushafPageSyncTask?.cancel()
            pendingMushafPageSyncTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 160_000_000)  // 0.16s
                guard !Task.isCancelled else { return }
                syncVisibleMushafPage(page)
            }
            return
        }

        lastMushafVisiblePageSyncAt = now
        pendingMushafPageSyncTask?.cancel()

        // Apply state updates
        if needsStoredPageUpdate {
            self.storedMushafPageNumber = page
        }
        if needsStandardPageUpdate {
            self.currentStandardPage = page
        }
        if needsSliderUpdate {
            self.jumpSliderValue = Double(page)
        }

        if let firstSection = mushafIndexByPage[page]?.first,
            let surahIndex = viewModel.surahs.firstIndex(where: { $0.id == firstSection.surah.id })
        {
            if viewModel.currentSurahIndex != surahIndex {
                self.viewModel.currentSurahIndex = surahIndex
            }
            if let targetVerseId = pendingMushafTargetVerseId,
                let targetSurah = viewModel.surahs[safe: viewModel.currentSurahIndex],
                targetSurah.verses.contains(where: { $0.id == targetVerseId && $0.page == page })
            {
                self.viewModel.updateLastReadVerse(targetVerseId)
            } else if let verseId = firstSection.verses.first?.id {
                let recentlyTappedVerse = Date().timeIntervalSince(lastInteractiveTapAt) < 0.55
                if !recentlyTappedVerse {
                    self.viewModel.updateLastReadVerse(verseId)
                }
            }
        }
    }

    func handleReaderScroll(offset: Double) {
        let delta = offset - lastTrackedScrollOffset
        lastTrackedScrollOffset = offset
        lastReaderScrollDelta = delta
        syncVisibleMushafPageFromOffset(offset)

        guard !isFocusMode else { return }
        guard Date() >= suppressChromeScrollUntil else { return }
        guard abs(delta) > 10 else { return }

        hideFloatingMenuTemporarily()

        if offset < 30 {
            if isTopChromeCollapsed {
                animateChrome(.easeInOut(duration: 0.18)) {
                    isTopChromeCollapsed = false
                }
            }
            return
        }

        if delta > 14, !isTopChromeCollapsed {
            animateChrome(.easeInOut(duration: 0.18)) {
                isTopChromeCollapsed = true
            }
        } else if delta < -10, isTopChromeCollapsed {
            animateChrome(.easeInOut(duration: 0.18)) {
                isTopChromeCollapsed = false
            }
        }
    }

    func captureLaunchCheckpointIfNeeded() {
        guard checkpointRestoreVerseId == nil, checkpointRestoreSurahIndex == nil else { return }
        guard let checkpoint = viewModel.consumeLaunchRestoreCheckpoint() else { return }
        checkpointRestoreSurahIndex = checkpoint.surahIndex
        checkpointRestoreVerseId = checkpoint.verseId

        if checkpoint.surahIndex == viewModel.currentSurahIndex, checkpoint.verseId > 1 {
            beginVerseTrackingSuppression()
        }
    }

    func applyLaunchRestoreNavigationIfNeeded() {
        guard !hasAppliedLaunchRestoreNavigation else { return }
        guard let checkpointSurahIndex = checkpointRestoreSurahIndex else { return }
        guard viewModel.surahs.indices.contains(checkpointSurahIndex) else { return }

        let targetVerseId =
            checkpointRestoreVerseId
            ?? viewModel.surahs[checkpointSurahIndex].verses.first?.id
            ?? 1

        if isMushafPageMode {
            if let targetPage = mushafPageForVerse(
                surahIndex: checkpointSurahIndex, verseId: targetVerseId)
            {
                startupMushafRestorePage = targetPage
            }
            goToMushafVerse(surahIndex: checkpointSurahIndex, verseId: targetVerseId)
        } else {
            jumpToSurahSafely(index: checkpointSurahIndex, verseId: targetVerseId)
        }

        hasAppliedLaunchRestoreNavigation = true
    }

    func performInitialMushafScrollIfNeeded(proxy: ScrollViewProxy) {
        guard isMushafPageMode, !hasPerformedInitialMushafScroll else { return }
        let maxPage = max(viewModel.maxMushafPage, 1)
        let target = min(
            max(
                startupMushafRestorePage ?? pendingMushafScrollTargetPage ?? storedMushafPageNumber,
                1),
            maxPage
        )

        DispatchQueue.main.async {
            proxy.scrollTo("MUSHAF_PAGE_\(target)", anchor: .top)
            currentStandardPage = target
            storedMushafPageNumber = target
            hasPerformedInitialMushafScroll = true
        }
    }

    func beginVerseTrackingSuppression(duration: UInt64 = 900_000_000) {
        suppressVerseTracking = true
        resumeVerseTrackingTask?.cancel()
        resumeVerseTrackingTask = Task {
            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                suppressVerseTracking = false
            }
        }
    }

    func handleVerseDidAppear(_ verseId: Int) {
        guard !suppressVerseTracking else { return }
        viewModel.updateLastReadVerse(verseId)
    }

    func hideFloatingMenuTemporarily() {
        floatingMenuRevealTask?.cancel()
        if !isFloatingMenuHiddenByScroll {
            animateFloating(.easeInOut(duration: 0.14)) {
                isFloatingMenuHiddenByScroll = true
            }
        }

        floatingMenuRevealTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if !isFocusMode {
                    animateFloating(.easeInOut(duration: 0.18)) {
                        isFloatingMenuHiddenByScroll = false
                    }
                }
            }
        }
    }

    var horizontalPageSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onEnded { value in
                let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                guard isHorizontal, abs(value.translation.width) > 60 else { return }

                if value.translation.width < 0 {
                    navigatePrevious()
                } else {
                    navigateNext()
                }
                lightHaptic()
            }
    }

    func handlePendingScrollIfNeeded(proxy: ScrollViewProxy) -> Bool {
        guard viewModel.pendingScrollSurahIndex == viewModel.currentSurahIndex else { return false }
        defer { viewModel.clearPendingScrollRequest() }

        if let verseId = viewModel.pendingScrollVerseId {
            beginVerseTrackingSuppression(duration: 700_000_000)
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(verseAnchorID(verseId), anchor: .top)
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo("TOP", anchor: .top)
            }
        }
        return true
    }

}
