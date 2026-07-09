//
//  ReplyConversation.swift
//  Vole
//
//  Created by Codex on 7/9/26.
//

import Foundation

struct ReplyConversationItem: Identifiable, Hashable {
    let reply: Reply
    let floor: Int
    let mentions: [String]

    var id: Int { reply.id }
    var author: String { reply.member.username }
}

struct ReplyConversation: Identifiable, Hashable {
    let id: Int
    let items: [ReplyConversationItem]
    let participants: [String]

    var hasMultipleReplies: Bool {
        items.count > 1
    }
}

struct ReplyConversationIndex {
    static let empty = ReplyConversationIndex(
        items: [],
        conversations: [:],
        itemsByAuthor: [:]
    )

    let items: [ReplyConversationItem]

    private let conversationsByReplyId: [Int: ReplyConversation]
    private let itemsByAuthor: [String: [ReplyConversationItem]]

    init(
        replies: [Reply],
        isIncluded: (Reply) -> Bool = { _ in true }
    ) {
        let items: [ReplyConversationItem] = replies.enumerated().compactMap {
            entry -> ReplyConversationItem? in
            let floor = entry.offset
            let reply = entry.element
            guard isIncluded(reply) else { return nil }

            return ReplyConversationItem(
                reply: reply,
                floor: floor,
                mentions: Self.mentionedUsernames(in: reply.content)
            )
        }

        self = Self.build(from: items)
    }

    private init(
        items: [ReplyConversationItem],
        conversations: [Int: ReplyConversation],
        itemsByAuthor: [String: [ReplyConversationItem]]
    ) {
        self.items = items
        self.conversationsByReplyId = conversations
        self.itemsByAuthor = itemsByAuthor
    }

    func conversation(containing replyId: Int) -> ReplyConversation? {
        conversationsByReplyId[replyId]
    }

    func items(byAuthor author: String) -> [ReplyConversationItem] {
        itemsByAuthor[author] ?? []
    }

    static func mentionedUsernames(in content: String) -> [String] {
        let nsContent = content as NSString
        let matches = mentionRegex.matches(
            in: content,
            range: NSRange(location: 0, length: nsContent.length)
        )
        var result: [String] = []
        var seen: Set<String> = []

        for match in matches {
            guard let range = Range(match.range(at: 1), in: content) else {
                continue
            }

            let username = String(content[range])
            guard !seen.contains(username) else { continue }

            seen.insert(username)
            result.append(username)
        }

        return result
    }

    private static func build(
        from items: [ReplyConversationItem]
    ) -> ReplyConversationIndex {
        guard !items.isEmpty else { return .empty }

        var latestReplyIndexByAuthor: [String: Int] = [:]
        var pendingMentionIndexesByUsername: [String: [Int]] = [:]
        var linkedReplyIndexesBySource: [Int: Set<Int>] = [:]
        var sourceReplyIndexesByTarget: [Int: Set<Int>] = [:]

        func link(source: Int, target: Int) {
            guard source != target else { return }

            linkedReplyIndexesBySource[source, default: []].insert(target)
            sourceReplyIndexesByTarget[target, default: []].insert(source)
        }

        for (index, item) in items.enumerated() {
            if let pendingMentionIndexes = pendingMentionIndexesByUsername[
                item.author
            ] {
                for pendingMentionIndex in pendingMentionIndexes {
                    link(source: pendingMentionIndex, target: index)
                }
                pendingMentionIndexesByUsername[item.author] = nil
            }

            for username in item.mentions {
                if let mentionedIndex = latestReplyIndexByAuthor[username] {
                    link(source: index, target: mentionedIndex)
                } else {
                    pendingMentionIndexesByUsername[username, default: []]
                        .append(index)
                }
            }

            latestReplyIndexByAuthor[item.author] = index
        }

        var conversationByReplyId: [Int: ReplyConversation] = [:]
        for index in items.indices {
            let conversationIndexes = conversationIndexes(
                containing: index,
                linkedReplyIndexesBySource: linkedReplyIndexesBySource,
                sourceReplyIndexesByTarget: sourceReplyIndexesByTarget
            )
            let conversationItems = conversationIndexes
                .sorted()
                .map { items[$0] }
            guard let firstItem = conversationItems.first else { continue }

            let conversation = ReplyConversation(
                id: firstItem.reply.id,
                items: conversationItems,
                participants: participants(in: conversationItems)
            )

            conversationByReplyId[items[index].reply.id] = conversation
        }

        return ReplyConversationIndex(
            items: items,
            conversations: conversationByReplyId,
            itemsByAuthor: Dictionary(grouping: items, by: \.author)
        )
    }

    private static func participants(
        in items: [ReplyConversationItem]
    ) -> [String] {
        var participants: [String] = []
        var seen: Set<String> = []

        func append(_ username: String) {
            guard !seen.contains(username) else { return }

            seen.insert(username)
            participants.append(username)
        }

        for item in items {
            append(item.author)
            item.mentions.forEach(append)
        }

        return participants
    }

    private static func conversationIndexes(
        containing index: Int,
        linkedReplyIndexesBySource: [Int: Set<Int>],
        sourceReplyIndexesByTarget: [Int: Set<Int>]
    ) -> Set<Int> {
        var result: Set<Int> = [index]
        collectContext(
            for: index,
            linkedReplyIndexesBySource: linkedReplyIndexesBySource,
            into: &result
        )

        if let sourceIndexes = sourceReplyIndexesByTarget[index] {
            result.formUnion(sourceIndexes)
        }

        return result
    }

    private static func collectContext(
        for index: Int,
        linkedReplyIndexesBySource: [Int: Set<Int>],
        into result: inout Set<Int>
    ) {
        guard let linkedIndexes = linkedReplyIndexesBySource[index] else {
            return
        }

        for linkedIndex in linkedIndexes {
            guard !result.contains(linkedIndex) else { continue }

            result.insert(linkedIndex)
            collectContext(
                for: linkedIndex,
                linkedReplyIndexesBySource: linkedReplyIndexesBySource,
                into: &result
            )
        }
    }

    private static let mentionRegex = try! NSRegularExpression(
        pattern: #"(?<![\p{L}0-9_])@([\p{L}0-9_]+)(?![\p{L}0-9_])"#
    )
}
