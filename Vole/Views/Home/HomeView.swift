//
//  Home.swift
//  Vole
//
//  Created by 杨权 on 5/25/25.
//

import SwiftUI

struct HomeView: View {

    @Binding var selection: HomeFeed
    @State private var data: [HomeFeed: [Topic]] = [:]
    @State private var showProfile = false
    @State private var loadingFeeds: Set<HomeFeed> = []

    @ObservedObject private var userManager = UserManager.shared
    @StateObject private var collectionManager = NodeCollectionManager.shared
    @EnvironmentObject var navManager: NavigationManager

    init(selection: Binding<HomeFeed> = .constant(.latest)) {
        _selection = selection
    }

    var body: some View {
        NavigationStack(path: $navManager.homePath) {
            HomeFeedPage(
                topics: data[selection],
                isLoading: loadingFeeds.contains(selection),
                onLoad: {
                    await loadTopics(for: selection)
                },
                onSelectTopic: { topic in
                    openTopic(topic)
                }
            )
            .navigationTitle("主页")
            .modifier(HomeTitleDisplayModeModifier())
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .topicId(let topicId):
                    DetailView(topicId: topicId, path: $navManager.homePath)
                case .topic(let topic):
                    DetailView(
                        topicId: nil,
                        topic: topic,
                        path: $navManager.homePath
                    )
                case .node(let node):
                    NodeDetailView(node: node, path: $navManager.homePath)
                case .nodeName(let nodeName):
                    NodeDetailView(
                        nodeName: nodeName,
                        path: $navManager.nodePath
                    )
                default:
                    EmptyView()
                }
            }
            .toolbar {
                if #unavailable(iOS 26) {
                    ToolbarItem(placement: .topBarLeading) {
                        HomeFeedPicker(
                            selection: $selection,
                            collections: collectionManager.customCollections
                        )
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        AvatarView {
                            showProfile = true
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        AvatarView {
                            showProfile = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .task(id: selection) {
                if data[selection] == nil || data[selection]?.isEmpty == true {
                    await loadTopics(for: selection)
                }
            }
            .onChange(of: collectionManager.customCollections) { _, value in
                data = data.filter { key, _ in
                    if case .collection = key { return false }
                    return true
                }

                guard case .collection(let id) = selection else { return }
                if !value.contains(where: { $0.id == id }) {
                    selection = .latest
                } else {
                    Task {
                        await loadTopics(for: selection)
                    }
                }
            }
        }
    }

    @MainActor
    private func loadTopics(for feed: HomeFeed) async {
        guard !loadingFeeds.contains(feed) else { return }
        guard let action = action(for: feed) else {
            selection = .latest
            return
        }
        loadingFeeds.insert(feed)
        defer { loadingFeeds.remove(feed) }
        do {
            let result = try await action()
            data[feed] = result ?? []
        } catch {
            if error is CancellationError { return }
            print("出错了: \(error)")
        }
    }

    private func openTopic(_ topic: Topic) {
        if userManager.token != nil {
            navManager.homePath.append(Route.topicId(topic.id))
        } else {
            navManager.homePath.append(Route.topic(topic))
        }
    }

    private func action(for feed: HomeFeed) -> (() async throws -> [Topic]?)? {
        switch feed {
        case .hot:
            return { try await V2exAPI.shared.hotTopics() }
        case .latest:
            return { try await V2exAPI.shared.latestTopics() }
        case .collection(let id):
            guard let collection = collectionManager.customCollection(id: id)
            else { return nil }
            return { try await loadCollectionTopics(collection) }
        }
    }

    private func loadCollectionTopics(_ collection: NodeCollection) async throws
        -> [Topic]
    {
        await withTaskGroup(of: [Topic].self) { group in
            for name in collection.nodeNames {
                group.addTask {
                    do {
                        let topics = try await V2exAPI.shared.topics(
                            nodeName: name
                        ) ?? []
                        return topics.map { topic in
                            var topic = topic
                            if topic.node == nil {
                                topic.node = Node.createVirtual(name: name)
                            }
                            return topic
                        }
                    } catch {
                        print("加载失败：\(name)", error)
                        return []
                    }
                }
            }

            var all: [Topic] = []
            for await list in group {
                all.append(contentsOf: list)
            }
            return all.sorted { ($0.created ?? 0) > ($1.created ?? 0) }
        }
    }
}

struct HomeTitleDisplayModeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .toolbarTitleDisplayMode(.inlineLarge)
        } else {
            content
        }
    }
}

extension View {
    @ViewBuilder
    func homeLikeListTopInset() -> some View {
        if #available(iOS 26, *) {
            self.contentMargins(.top, 0, for: .scrollContent)
        } else {
            self
        }
    }
}

struct HomeFeedPicker: View {
    @Binding var selection: HomeFeed
    let collections: [NodeCollection]

    var body: some View {
        Picker("category", selection: $selection) {
            ForEach(HomeFeed.builtInFeeds) { item in
                Text(item.title).tag(item)
            }
            ForEach(collections) { collection in
                Text(collection.name).tag(HomeFeed.collection(collection.id))
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct HomeFeedPage: View {
    let topics: [Topic]?
    let isLoading: Bool
    let onLoad: () async -> Void
    let onSelectTopic: (Topic) -> Void

    var body: some View {
        Group {
            if let topics, !topics.isEmpty {
                topicList(topics)
            } else if isLoading {
                HomeFeedStateView(
                    systemImage: "arrow.triangle.2.circlepath",
                    title: "正在加载主题",
                    message: "稍等片刻，内容马上回来。",
                    isLoading: true,
                    retryAction: nil
                )
            } else {
                HomeFeedStateView(
                    systemImage: "doc.text.magnifyingglass",
                    title: "暂时没有内容",
                    message: "当前列表没有加载到主题，可以稍后再试。",
                    isLoading: false
                ) {
                    Task {
                        await onLoad()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func topicList(_ topics: [Topic]) -> some View {
        list(topics)
            .homeLikeListTopInset()
    }

    private func list(_ topics: [Topic]) -> some View {
        List {
            ForEach(topics) { topic in
                TopicRow(topic: topic) {
                    onSelectTopic(topic)
                }
                .listRowInsets(
                    EdgeInsets(
                        top: 6,
                        leading: 12,
                        bottom: 6,
                        trailing: 12
                    )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await onLoad()
        }
    }
}

private struct HomeFeedStateView: View {
    let systemImage: String
    let title: String
    let message: String
    let isLoading: Bool
    let retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 52, height: 52)

                if isLoading {
                    ProgressView()
                        .controlSize(.regular)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            VStack(spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let retryAction {
                Button {
                    retryAction()
                } label: {
                    Label("重新加载", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

enum HomeFeed: Hashable, Identifiable {
    case latest
    case hot
    case collection(UUID)

    static let builtInFeeds: [HomeFeed] = [.latest, .hot]

    var id: String {
        switch self {
        case .latest:
            return "latest"
        case .hot:
            return "hot"
        case .collection(let id):
            return id.uuidString
        }
    }

    var title: String {
        switch self {
        case .latest:
            return "最新"
        case .hot:
            return "热门"
        case .collection:
            return ""
        }
    }
}

#Preview {
    HomeView()
}
