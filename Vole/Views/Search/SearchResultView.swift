//
//  SearchResultsView.swift
//  Vole
//
//  Created by 杨权 on 11/23/25.
//

import SwiftUI

struct SearchResultView: View {
    let query: String

    private enum SearchLoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum SearchCategory: String, CaseIterable, Identifiable {
        case topic = "话题"
        case node = "节点"
        case user = "用户"

        var id: String { self.rawValue }
    }

    @State private var selectedCategory: SearchCategory = .topic
    @State private var results: [SoV2exHit] = []
    @State private var topicLoadState: SearchLoadState = .idle
    @State private var pagingState = SearchPagingState()
    @State private var isPagingLoading = false
    @State private var pagingErrorMessage: String?

    @State private var nodes: [Node] = []
    @State private var nodeLoadState: SearchLoadState = .idle
    @State private var users: [Member] = []
    @State private var userLoadState: SearchLoadState = .idle

    @ObservedObject private var nodeManager = NodeManager.shared
    @ObservedObject private var userManager = UserManager.shared

    @State private var filterOptions = SearchFilterOptions()
    @State private var isFilterPresented = false

    @Binding var path: NavigationPath

    private var currentLoadState: SearchLoadState {
        switch selectedCategory {
        case .topic: return topicLoadState
        case .node: return nodeLoadState
        case .user: return userLoadState
        }
    }

    private var isLoading: Bool {
        if case .loading = currentLoadState {
            return true
        }
        return false
    }

    private var currentErrorMessage: String? {
        if case .failed(let message) = currentLoadState {
            return message
        }
        return nil
    }

    private var shouldShowEmptyState: Bool {
        currentLoadState == .loaded && isCurrentCategoryEmpty
    }

    private var shouldShowErrorState: Bool {
        currentErrorMessage != nil
    }

    private var activeTopicFilterLabels: [String] {
        var labels: [String] = []

        if filterOptions.timeRange != .all {
            labels.append(filterOptions.timeRange.rawValue)
        }

        let nodeName = filterOptions.nodeName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !nodeName.isEmpty {
            labels.append("节点: \(nodeName)")
        }

        switch filterOptions.sortType {
        case .weight:
            break
        case .timeDesc:
            labels.append("排序: 最新")
        case .timeAsc:
            labels.append("排序: 最早")
        }

        return labels
    }

    private var hasVisibleTopicFilters: Bool {
        !activeTopicFilterLabels.isEmpty
    }

    var body: some View {
        List {
            Section(header: listHeaderView, footer: footerView) {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("搜索中…")
                        Spacer()
                    }
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
                } else if shouldShowErrorState {
                    errorStateView
                } else if shouldShowEmptyState {
                    emptyStateView
                        .transition(.opacity)
                } else {
                    renderSearchResults()
                }
            }
        }
        .homeLikeListTopInset()
        .sheet(isPresented: $isFilterPresented) {
            SearchFilterSheet(
                options: $filterOptions,
                onConfirm: {
                    isFilterPresented = false
                    resetTopicData()
                    Task { await performSearch() }
                },
                onCancel: {
                    isFilterPresented = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await performSearch()
        }
        .onChange(of: selectedCategory) {
            Task { await performSearch() }
        }
    }

    private func resetTopicData() {
        results = []
        topicLoadState = .idle
        pagingState = SearchPagingState()
        isPagingLoading = false
        pagingErrorMessage = nil
    }

    @ViewBuilder
    private func renderSearchResults() -> some View {
        switch selectedCategory {
        case .topic:
            ForEach(results) { res in
                SearchRowView(result: res)
                    .onAppear {
                        if res.id == results.last?.id {
                            Task { await loadNextPage() }
                        }
                    }
                    .onTapGesture { path.append(Route.topicId(res.source.id)) }
            }

        case .node:
            ForEach(nodes) { node in
                NodeRowView(node: node)
                    .onTapGesture {
                        path.append(Route.nodeName(node.name))
                    }
            }

        case .user:
            ForEach(users) { member in
                MemberRowView(member: member)
                    .onTapGesture { path.append(Route.member(member)) }
            }
        }
    }

    private var isCurrentCategoryEmpty: Bool {
        switch selectedCategory {
        case .topic: return results.isEmpty
        case .node: return nodes.isEmpty
        case .user: return users.isEmpty
        }
    }

    private var listHeaderView: some View {
        VStack(spacing: 12) {
            Picker("搜索类别", selection: $selectedCategory) {
                ForEach(SearchCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 4)

            HStack {
                switch selectedCategory {
                case .topic:
                    if let total = pagingState.totalResults {
                        Text(
                            total == results.count
                                ? "共 \(total) 条结果"
                                : "共 \(total) 条结果，已展示 \(results.count) 条"
                        )
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else if !results.isEmpty {
                        Text("已展示 \(results.count) 条结果")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                case .node:
                    if !nodes.isEmpty {
                        Text("共 \(nodes.count) 个匹配节点")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                case .user:
                    if !users.isEmpty {
                        Text("共 \(users.count) 位相关用户")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if selectedCategory == .topic {
                    Button(action: {
                        isFilterPresented = true
                    }) {
                        HStack(spacing: 4) {
                            Text("筛选")
                            Image(
                                systemName: hasVisibleTopicFilters
                                    ? "line.3.horizontal.decrease.circle.fill"
                                    : "line.3.horizontal.decrease.circle"
                            )
                        }
                    }
                }
            }

            if selectedCategory == .topic && hasVisibleTopicFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activeTopicFilterLabels, id: \.self) { label in
                            Text(label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        Color.secondary.opacity(0.12)
                                    )
                                )
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .textCase(nil)
    }

    @ViewBuilder
    private var footerView: some View {
        if selectedCategory == .topic {
            if isPagingLoading {
                HStack(spacing: 8) {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("正在加载更多...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if let pagingErrorMessage, !results.isEmpty {
                VStack(spacing: 8) {
                    footerText(pagingErrorMessage)
                    Button("重试加载更多") {
                        Task { await loadNextPage() }
                    }
                    .font(.footnote)
                }
            } else if let total = pagingState.totalResults, !results.isEmpty {
                if results.count >= total {
                    footerText("已加载全部 \(results.count) 条结果")
                } else {
                    footerText("上滑加载更多 (共 \(total) 条，已展示 \(results.count) 条)")
                }
            }
        }
    }

    private func footerText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowSeparator(.hidden)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(
                systemName: selectedCategory == .user
                    ? "person.slash" : "magnifyingglass"
            )
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(.quaternary)
            .padding(.top, 60)

            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(emptyStateDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if selectedCategory == .topic && hasVisibleTopicFilters {
                VStack(spacing: 12) {
                    Button(action: {
                        isFilterPresented = true
                    }) {
                        Text("调整筛选条件")
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }

                    Button("清除所有筛选") {
                        resetFilters()
                    }
                    .font(.footnote)
                    .foregroundColor(.red)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 60)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var emptyStateTitle: String {
        switch selectedCategory {
        case .topic: return "没有找到相关话题"
        case .node: return "没有找到匹配的节点"
        case .user: return "没有找到匹配的用户"
        }
    }

    private var emptyStateDescription: String {
        "尝试更换关键词，或者确认\n拼写是否正确"
    }

    private var errorStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.quaternary)
                .padding(.top, 60)

            VStack(spacing: 8) {
                Text("搜索失败")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(currentErrorMessage ?? "请稍后重试")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("重新搜索") {
                retryCurrentSearch()
            }
            .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 60)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func resetFilters() {
        filterOptions = SearchFilterOptions()
        resetTopicData()
        Task { await performSearch() }
    }

    private func retryCurrentSearch() {
        switch selectedCategory {
        case .topic:
            resetTopicData()
        case .node:
            nodes = []
            nodeLoadState = .idle
        case .user:
            users = []
            userLoadState = .idle
        }

        Task { await performSearch() }
    }

    private func performSearch() async {
        guard !query.isEmpty else { return }
        if currentLoadState != .idle {
            return
        }

        await MainActor.run { setCurrentLoadState(.loading) }

        switch selectedCategory {
        case .topic:
            await performTopicSearch()
        case .node:
            await performNodeSearch()
        case .user:
            await performUserSearch()
        }
    }

    private func performTopicSearch() async {
        let req = buildRequest(from: 0)
        do {
            let res = try await SoV2exService.shared.search(req)
            if Task.isCancelled { return }

            await MainActor.run {
                self.pagingErrorMessage = nil
                self.pagingState.totalResults = res.total
                self.results = res.hits
                self.pagingState.currentOffset = res.hits.count
                self.topicLoadState = .loaded
            }
        } catch {
            await MainActor.run {
                self.topicLoadState = .failed("话题搜索请求失败，请检查网络后重试")
            }
        }
    }

    private func performNodeSearch() async {
        do {
            let list = try await nodeManager.search(name: query)
            await MainActor.run {
                self.nodes = list
                self.nodeLoadState = .loaded
            }
        } catch {
            await MainActor.run {
                self.nodeLoadState = .failed("节点搜索失败，请检查网络后重试")
            }
        }
    }

    private func performUserSearch() async {
        do {
            let members = try await userManager.search(name: query)
            await MainActor.run {
                self.users = members
                self.userLoadState = .loaded
            }
        } catch {
            await MainActor.run {
                self.userLoadState = .failed("用户搜索失败，请检查网络后重试")
            }
        }
    }

    private func loadNextPage() async {
        guard !isPagingLoading,
            let total = pagingState.totalResults,
            pagingState.currentOffset < total
        else { return }

        await MainActor.run {
            isPagingLoading = true
        }
        let req = buildRequest(from: pagingState.currentOffset)

        do {
            let res = try await SoV2exService.shared.search(req)
            if Task.isCancelled { return }

            await MainActor.run {
                self.pagingErrorMessage = nil
                self.results.append(contentsOf: res.hits)
                self.pagingState.currentOffset = self.results.count
                self.isPagingLoading = false
            }
        } catch {
            await MainActor.run {
                self.isPagingLoading = false
                self.pagingErrorMessage = "加载更多失败，请稍后重试"
            }
        }
    }

    private func buildRequest(from: Int) -> SoV2exSearchRequest {
        var req = SoV2exSearchRequest(
            q: query,
            from: from,
            size: pagingState.pageSize
        )

        if let startTime = filterOptions.timeRange.startTimeStamp {
            req.gte = startTime
        }

        let nodeName = filterOptions.nodeName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !nodeName.isEmpty {
            req.node = nodeName
        }

        switch filterOptions.sortType {
        case .weight:
            req.sort = .sumup
            req.order = nil
        case .timeDesc:
            req.sort = .created
            req.order = .descending
        case .timeAsc:
            req.sort = .created
            req.order = .ascending
        }

        return req
    }

    @MainActor
    private func setCurrentLoadState(_ state: SearchLoadState) {
        switch selectedCategory {
        case .topic:
            topicLoadState = state
        case .node:
            nodeLoadState = state
        case .user:
            userLoadState = state
        }
    }
}

#Preview {
    //    SearchResultsView()
}
