//
//  NodeGroupView.swift
//  Vole
//
//  Created by 杨权 on 11/13/25.
//

import Kingfisher
import SwiftUI

struct NodeCollectionView: View {
    @Binding var path: NavigationPath

    @State var collection: NodeCollection
    @State private var topics: [Topic] = []
    @State private var isLoading = true

    @StateObject private var nodeManager = NodeManager.shared
    @ObservedObject private var userManager = UserManager.shared

    var body: some View {
        List {
            // Topics 列表 Section
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("加载中…")
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(topics) { topic in
                        TopicRow(topic: topic) {
                            if userManager.token != nil {
                                path.append(Route.topicId(topic.id))
                            }else {
                                path.append(Route.topic(topic))
                            }
                        }
                    }
                }
            } header: {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(collection.nodeNames, id: \.self) { nodeName in
                            let node = nodeManager.getNode(nodeName)

                            Button {
                                openNode(node, named: nodeName)
                            } label: {
                                nodeCard(node, named: nodeName)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .textCase(nil)
            }
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if topics.isEmpty {
                await loadTopics()
            }
        }
        .refreshable {
            await loadTopics()
        }
    }

    private func openNode(_ node: Node?, named nodeName: String) {
        if let node {
            path.append(Route.node(node))
        } else {
            path.append(Route.nodeName(nodeName))
        }
    }

    private func nodeCard(_ node: Node?, named nodeName: String) -> some View {
        HStack(spacing: 10) {
            nodeAvatar(node, named: nodeName)

            VStack(alignment: .leading, spacing: 2) {
                Text(node?.title ?? nodeName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(collection.color.opacity(0.1))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(collection.color.opacity(0.22), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func nodeAvatar(_ node: Node?, named nodeName: String) -> some View {
        Group {
            if let avatarPath = node?.getHighestQualityAvatar(),
                let url = nodeAvatarURL(from: avatarPath)
            {
                KFImage(url)
                    .placeholder { nodeAvatarPlaceholder(node, named: nodeName) }
                    .fade(duration: 0.15)
                    .resizable()
                    .scaledToFill()
            } else {
                nodeAvatarPlaceholder(node, named: nodeName)
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func nodeAvatarPlaceholder(
        _ node: Node?,
        named nodeName: String
    ) -> some View {
        ZStack {
            collection.color.opacity(0.16)
            Text(String((node?.title ?? nodeName).prefix(1)))
                .font(.caption.weight(.bold))
                .foregroundStyle(collection.color)
        }
    }

    private func nodeAvatarURL(from path: String) -> URL? {
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        return URL(string: path, relativeTo: URL(string: "https://www.v2ex.com"))
    }

    // 并发加载所有节点的 topics
    private func loadTopics() async {
        isLoading = true

        await withTaskGroup(of: [Topic].self) { group in
            for name in collection.nodeNames {
                group.addTask {
                    do {
                        let response = try await V2exAPI().topics(
                            nodeName: name
                        )
                        if let topics = response {
                            return topics.map { t -> Topic in
                                var t = t
                                if t.node == nil {
                                    t.node = Node(
                                        id: nil,
                                        name: name,
                                        title: name,
                                        url: nil,
                                        topics: nil,
                                        footer: nil,
                                        header: nil,
                                        titleAlternative: nil,
                                        avatar: nil,
                                        avatarMini: nil,
                                        avatarNormal: nil,
                                        avatarLarge: nil,
                                        stars: nil,
                                        aliases: nil,
                                        root: nil,
                                        parentNodeName: nil
                                    )
                                }
                                return t
                            }
                        }
                    } catch {
                        print("加载失败：\(name)", error)
                    }
                    return []
                }
            }

            var all: [Topic] = []
            for await list in group {
                all += list
            }

            let sorted = all.sorted { ($0.created ?? 0) > ($1.created ?? 0) }

            await MainActor.run {
                self.topics = sorted
                self.isLoading = false
            }
        }
    }
}
