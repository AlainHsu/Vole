//
//  NodeCollectionManager.swift
//  Vole
//
//  Created by 杨权 on 11/15/25.
//

import Foundation
import SwiftUI

@MainActor
final class NodeCollectionManager: ObservableObject {
    static let shared = NodeCollectionManager()

    @Published private(set) var collections: [NodeCollection] = []
    @Published private(set) var customCollections: [NodeCollection] = []

    private let saveKey = "node_collections_v1"
    private let customSaveKey = "home_node_collections_v1"

    init() {
        collections = Self.defaultCollections
        loadCustomCollections()
    }

    // MARK: - CRUD 集合
    @discardableResult
    func addCustomCollection(
        name: String,
        nodeNames: [String] = [],
        color: String = "blue",
        symbol: String = "list.bullet"
    ) -> NodeCollection {
        let new = NodeCollection(
            name: name,
            systemIcon: symbol,
            colorHex: color,
            nodeNames: Array(nodeNames.prefix(10))
        )
        customCollections.append(new)
        saveCustomCollections()
        return new
    }

    func removeCustomCollection(_ c: NodeCollection) {
        customCollections.removeAll { $0.id == c.id }
        saveCustomCollections()
    }

    func updateCustomCollection(_ c: NodeCollection) {
        var updated = c
        updated.nodeNames = Array(c.nodeNames.prefix(10))
        if let idx = customCollections.firstIndex(where: { $0.id == c.id }) {
            customCollections[idx] = updated
            saveCustomCollections()
        }
    }

    func setNode(_ nodeName: String, selected: Bool, in collection: NodeCollection)
        -> Bool
    {
        guard
            let idx = customCollections.firstIndex(where: {
                $0.id == collection.id
            })
        else { return false }

        if selected {
            guard !customCollections[idx].nodeNames.contains(nodeName) else {
                return true
            }
            guard customCollections[idx].nodeNames.count < 10 else {
                return false
            }
            customCollections[idx].nodeNames.append(nodeName)
        } else {
            customCollections[idx].nodeNames.removeAll { $0 == nodeName }
        }
        saveCustomCollections()
        return true
    }

    func customCollection(id: UUID) -> NodeCollection? {
        customCollections.first { $0.id == id }
    }

    func addCollection(name: String, color: String, symbol: String) {
        let new = NodeCollection(
            name: name,
            systemIcon: symbol,
            colorHex: color
        )
        collections.append(new)
        save()
    }

    func removeCollection(_ c: NodeCollection) {
        collections.removeAll { $0.id == c.id }
        save()
    }

    func updateCollection(_ c: NodeCollection) {
        if let idx = collections.firstIndex(where: { $0.id == c.id }) {
            collections[idx] = c
            save()
        }
    }

    // MARK: - 节点增删
    func addNode(_ nodeName: String, to collection: NodeCollection) {
        guard
            let idx = collections.firstIndex(where: { $0.id == collection.id })
        else { return }
        if !collections[idx].nodeNames.contains(nodeName) {
            collections[idx].nodeNames.append(nodeName)
            save()
        }
    }

    func removeNode(_ nodeName: String, from collection: NodeCollection) {
        guard
            let idx = collections.firstIndex(where: { $0.id == collection.id })
        else { return }
        collections[idx].nodeNames.removeAll { $0 == nodeName }
        save()
    }

    // MARK: - 持久化
    private func save() {
        if let data = try? JSONEncoder().encode(collections) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
            let value = try? JSONDecoder().decode(
                [NodeCollection].self,
                from: data
            )
        {
            self.collections = value
        }
    }

    private func saveCustomCollections() {
        if let data = try? JSONEncoder().encode(customCollections) {
            UserDefaults.standard.set(data, forKey: customSaveKey)
        }
    }

    private func loadCustomCollections() {
        guard let data = UserDefaults.standard.data(forKey: customSaveKey),
            let value = try? JSONDecoder().decode(
                [NodeCollection].self,
                from: data
            )
        else { return }
        customCollections = value
    }
}

@MainActor
final class FavoriteNodeManager: ObservableObject {
    static let shared = FavoriteNodeManager()

    @Published private(set) var favoriteNodes: [Node] = []

    private let storageKey = "favorite_nodes_v1"

    private init() {
        loadFavorites()
    }

    func isFavorite(_ node: Node) -> Bool {
        favoriteNodes.contains { $0.name == node.name }
    }

    func toggleFavorite(_ node: Node) {
        if isFavorite(node) {
            removeFavorite(node)
        } else {
            addFavorite(node)
        }
    }

    func addFavorite(_ node: Node) {
        let resolvedNode = node.withResolvedHeaderText()
        favoriteNodes.removeAll { $0.name == node.name }
        favoriteNodes.insert(resolvedNode, at: 0)
        saveFavorites()
    }

    func removeFavorite(_ node: Node) {
        favoriteNodes.removeAll { $0.name == node.name }
        saveFavorites()
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteNodes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
            let value = try? JSONDecoder().decode([Node].self, from: data)
        else { return }
        favoriteNodes = value.map { $0.withResolvedHeaderText() }
    }
}

private extension NodeCollectionManager {
    static let defaultCollections: [NodeCollection] = [
        NodeCollection(
            name: "技术",
            systemIcon: "hammer.fill",
            colorHex: "indigo",
            nodeNames: ["programmer", "cloud", "idev", "rss", "nas", "android"]
        ),
        NodeCollection(
            name: "创意",
            systemIcon: "sparkles",
            colorHex: "green",
            nodeNames: ["create", "design", "ideas"]
        ),
        NodeCollection(
            name: "好玩",
            systemIcon: "puzzlepiece.fill",
            colorHex: "cyan",
            nodeNames: ["share", "bb", "music", "movie", "travel", "afterdark"]
        ),
        NodeCollection(
            name: "Apple",
            systemIcon: "apple.logo",
            colorHex: "gray",
            nodeNames: [
                "apple",
                "iphone",
                "ipad",
                "mbp",
                "macos",
                "ios",
                "appletv",
                "idev",
            ]
        ),
        NodeCollection(
            name: "酷工作",
            systemIcon: "briefcase.fill",
            colorHex: "brown",
            nodeNames: ["jobs", "cv", "career", "meet", "outsourcing", "remote"]
        ),
        NodeCollection(
            name: "交易",
            systemIcon: "creditcard.fill",
            colorHex: "teal",
            nodeNames: ["all4all", "exchange", "free", "dn", "tuan"]
        ),
        NodeCollection(
            name: "城市",
            systemIcon: "building.2.fill",
            colorHex: "blue",
            nodeNames: [
                "life",
                "beijing",
                "shanghai",
                "shenzhen",
                "guangzhou",
                "hangzhou",
                "chengdu",
            ]
        ),
        NodeCollection(
            name: "问与答",
            systemIcon: "questionmark.bubble.fill",
            colorHex: "blue",
            nodeNames: ["qna"]
        ),
    ]
}
