//
//  Node.swift
//  Vole
//
//  Created by 杨权 on 5/26/25.
//
import Foundation
import SwiftSoup

public struct Node: Identifiable, Codable, Hashable, Sendable {

    public var id: Int?
    public let name: String
    public let title: String?
    public let url: String?
    public let topics: Int?
    public let footer: String?
    public let header: String?
    public let headerText: String?
    public let titleAlternative: String?
    public let avatar: String?
    public let avatarMini: String?
    public let avatarNormal: String?
    public let avatarLarge: String?
    public let stars: Int?
    public let aliases: [String]?
    public let root: Bool?
    public let parentNodeName: String?

    enum CodingKeys: String, CodingKey {
        case name, stars, aliases, root, id, title, url, topics, footer, header,
            avatar
        case headerText = "header_text"
        case titleAlternative = "title_alternative"
        case avatarMini = "avatar_mini"
        case avatarNormal = "avatar_normal"
        case avatarLarge = "avatar_large"
        case parentNodeName = "parent_node_name"
    }

    public var displaySubtitle: String {
        if let headerText, !headerText.isEmpty {
            return headerText
        }
        return name
    }

    public func getHighestQualityAvatar() -> String? {
        if let avatarLarge, !avatarLarge.isEmpty {
            return avatarLarge
        }
        if let avatarNormal, !avatarNormal.isEmpty {
            return avatarNormal
        }
        if let avatar, !avatar.isEmpty {
            return avatar
        }
        if let avatarMini, !avatarMini.isEmpty {
            return avatarMini
        }
        return nil
    }

    static func createVirtual(name: String, title: String? = nil) -> Node {
        Node(
            id: nil,  // ID 为 nil 是识别虚拟节点的标志
            name: name,
            title: title ?? name.capitalized,
            url: nil,
            topics: 0,
            footer: nil,
            header: nil,
            headerText: nil,
            titleAlternative: nil,
            avatar: nil,
            avatarMini: nil,
            avatarNormal: nil,
            avatarLarge: nil,
            stars: nil,
            aliases: nil,
            root: true,
            parentNodeName: nil,
        )
    }

    func withResolvedHeaderText() -> Node {
        let existingHeaderText = headerText?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let resolvedHeaderText: String
        if let existingHeaderText, !existingHeaderText.isEmpty {
            resolvedHeaderText = existingHeaderText
        } else {
            resolvedHeaderText = Self.plainText(from: header)
        }

        return Node(
            id: id,
            name: name,
            title: title,
            url: url,
            topics: topics,
            footer: footer,
            header: header,
            headerText: resolvedHeaderText.isEmpty ? nil : resolvedHeaderText,
            titleAlternative: titleAlternative,
            avatar: avatar,
            avatarMini: avatarMini,
            avatarNormal: avatarNormal,
            avatarLarge: avatarLarge,
            stars: stars,
            aliases: aliases,
            root: root,
            parentNodeName: parentNodeName
        )
    }

    private static func plainText(from html: String?) -> String {
        guard let html, !html.isEmpty else { return "" }
        do {
            return try SwiftSoup.parse(html).text()
        } catch {
            return ""
        }
    }
}
