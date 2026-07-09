//
//  ReplyConversationIndexTests.swift
//  VoleTests
//
//  Created by Codex on 7/9/26.
//

import Testing
@testable import Vole

struct ReplyConversationIndexTests {
    @Test func linksMentionToNearestPreviousReplyByThatUser() {
        let replies = [
            reply(1, author: "alice", content: "first idea"),
            reply(2, author: "alice", content: "second idea"),
            reply(3, author: "bob", content: "@alice this one"),
        ]

        let conversation = ReplyConversationIndex(replies: replies)
            .conversation(containing: 3)

        #expect(conversation?.items.map(\.reply.id) == [2, 3])
    }

    @Test func chainsMultipleMentionsInFloorOrder() {
        let replies = [
            reply(1, author: "alice", content: "base"),
            reply(2, author: "bob", content: "@alice follow up"),
            reply(3, author: "carol", content: "@bob @moderator another point"),
        ]

        let conversation = ReplyConversationIndex(replies: replies)
            .conversation(containing: 3)

        #expect(conversation?.items.map(\.reply.id) == [1, 2, 3])
        #expect(
            conversation?.participants == [
                "alice",
                "bob",
                "carol",
                "moderator",
            ]
        )
    }

    @Test func mentionWithoutPreviousReplyStaysInParticipantsOnly() {
        let replies = [
            reply(1, author: "alice", content: "@moderator please check"),
        ]

        let conversation = ReplyConversationIndex(replies: replies)
            .conversation(containing: 1)

        #expect(conversation?.items.map(\.reply.id) == [1])
        #expect(conversation?.participants == ["alice", "moderator"])
        #expect(conversation?.hasMultipleReplies == false)
    }

    @Test func laterReplyByMentionedExternalUserJoinsConversation() {
        let replies = [
            reply(1, author: "alice", content: "@moderator please check"),
            reply(2, author: "moderator", content: "checking now"),
        ]

        let conversation = ReplyConversationIndex(replies: replies)
            .conversation(containing: 1)

        #expect(conversation?.items.map(\.reply.id) == [1, 2])
        #expect(conversation?.participants == ["alice", "moderator"])
    }

    @Test func referencedReplyDoesNotPullMentionSiblings() {
        let replies = [
            reply(1, author: "alice", content: "cheap plan"),
            reply(2, author: "bob", content: "another cheap plan"),
            reply(3, author: "carol", content: "@alice @bob how"),
        ]

        let index = ReplyConversationIndex(replies: replies)

        #expect(
            index.conversation(containing: 1)?.items.map(\.reply.id) == [1, 3]
        )
        #expect(
            index.conversation(containing: 2)?.items.map(\.reply.id) == [2, 3]
        )
        #expect(
            index.conversation(containing: 3)?.items.map(\.reply.id) == [
                1, 2, 3,
            ]
        )
    }

    @Test func excludedRepliesDoNotBecomeConversationTargets() {
        let replies = [
            reply(1, author: "alice", content: "visible"),
            reply(2, author: "blocked", content: "@alice hidden"),
            reply(3, author: "carol", content: "@blocked no visible target"),
        ]

        let index = ReplyConversationIndex(replies: replies) { reply in
            reply.member.username != "blocked"
        }
        let conversation = index.conversation(containing: 3)

        #expect(index.items.map(\.reply.id) == [1, 3])
        #expect(conversation?.items.map(\.reply.id) == [3])
        #expect(conversation?.participants == ["carol", "blocked"])
    }

    @Test func groupsRepliesByAuthorInFloorOrder() {
        let replies = [
            reply(1, author: "alice", content: "first"),
            reply(2, author: "bob", content: "middle"),
            reply(3, author: "alice", content: "@carol second"),
        ]

        let index = ReplyConversationIndex(replies: replies)

        #expect(index.items(byAuthor: "alice").map(\.reply.id) == [1, 3])
        #expect(index.items(byAuthor: "alice").map(\.floor) == [0, 2])
        #expect(index.items(byAuthor: "missing").isEmpty)
    }
}

private func reply(
    _ id: Int,
    author username: String,
    content: String
) -> Reply {
    Reply(
        id: id,
        content: content,
        contentRendered: "",
        created: id,
        member: member(username)
    )
}

private func member(_ username: String) -> Member {
    Member(
        id: nil,
        username: username,
        url: nil,
        website: nil,
        twitter: nil,
        psn: nil,
        github: nil,
        btc: nil,
        location: nil,
        tagline: nil,
        bio: nil,
        avatar: nil,
        avatarMini: nil,
        avatarNormal: nil,
        avatarLarge: nil,
        avatarXLarge: nil,
        avatarXXLarge: nil,
        avatarXXXLarge: nil,
        created: nil,
        lastModified: nil,
        pro: nil
    )
}
