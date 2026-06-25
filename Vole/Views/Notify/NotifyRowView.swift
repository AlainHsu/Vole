//
//  NotifyRowView.swift
//  Vole
//
//  Created by 杨权 on 11/18/25.
//

import Kingfisher
import SwiftSoup
import SwiftUI

struct NotifyRowView: View {
    let item: Notification
    let onTap: (Int) -> Void

    @ObservedObject private var notifyManager = NotifyManager.shared

    private var parsedNotification: ParsedNotification? {
        parseNotificationHTML(item)
    }

    private var isRead: Bool {
        notifyManager.isRead(item.id)
    }

    var body: some View {
        if let parsedNotification {
            Button {
                guard let topicId = parsedNotification.topicId else { return }
                notifyManager.markRead(item.id)
                onTap(topicId)
            } label: {
                notificationCard(parsedNotification)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                if !isRead {
                    Button {
                        notifyManager.markRead(item.id)
                    } label: {
                        Label("已读", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
            }
        }
    }

    private func notificationCard(_ parsed: ParsedNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            unreadIndicator
                .padding(.top, 8)

            avatarView(
                for: item.member,
                fallbackColor: parsed.color,
                fallbackSymbol: parsed.icon
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(parsed.username)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            kindBadge(parsed)
                        }

                        Text(parsed.action)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        if let title = parsed.topicTitle, !title.isEmpty {
                            Text(title)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 8) {
                        if let created = item.created {
                            TimelineView(.everyMinute) { _ in
                                Text(DateConverter.relativeTimeString(created))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let payload = parsed.payload, !payload.isEmpty {
                    Text(payload)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor(for: parsed))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardBorderColor(for: parsed), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var unreadIndicator: some View {
        ZStack {
            if !isRead {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: 8, height: 20)
    }

    private func cardBackgroundColor(for parsed: ParsedNotification) -> some ShapeStyle {
        if isRead {
            return AnyShapeStyle(Color(.secondarySystemBackground))
        }
        return AnyShapeStyle(parsed.color.opacity(0.08))
    }

    private func cardBorderColor(for parsed: ParsedNotification) -> Color {
        if isRead {
            return Color.primary.opacity(0.05)
        }
        return parsed.color.opacity(0.18)
    }

    private func kindBadge(_ parsed: ParsedNotification) -> some View {
        Text(parsed.badgeText)
            .font(.caption.weight(.semibold))
        .foregroundStyle(parsed.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(parsed.color.opacity(0.12))
        )
    }

    @ViewBuilder
    private func avatarView(
        for member: Member?,
        fallbackColor: Color,
        fallbackSymbol: String
    ) -> some View {
        if let avatarURL = member?.getHighestQualityAvatar(),
           let url = URL(string: avatarURL) {
            KFImage(url)
                .placeholder {
                    Circle()
                        .fill(fallbackColor.opacity(0.16))
                }
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(fallbackColor.opacity(0.14))
                    .frame(width: 40, height: 40)

                Image(systemName: fallbackSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(fallbackColor)
            }
        }
    }

    private func parseNotificationHTML(_ item: Notification) -> ParsedNotification? {
        do {
            let doc = try SwiftSoup.parse(item.text ?? "")

            let firstA = try doc.select("a[href^=/member/]").first()
            let username = try firstA?.text() ?? "系统通知"

            let topicA = try doc.select("a.topic-link, a[href^=/t/]").last()
            let topicTitle = try topicA?.text()
            let topicURL = try topicA?.attr("href")

            var topicId: Int? = nil
            if let url = topicURL,
               let match = url.split(separator: "/").last?.split(separator: "#").first,
               let id = Int(match) {
                topicId = id
            }

            let fullText = try doc.text()
            var actionText = ""
            var icon = "message.fill"
            var color: Color = .accentColor
            var badgeText = "通知"
            var parsedPayload: String? = item.payload

            if fullText.contains("提到了你") {
                actionText = "提到了你"
                icon = "at"
                color = .orange
                badgeText = "提到"
            } else if fullText.contains("回复了你") {
                actionText = "回复了你"
                icon = "bubble.left.and.bubble.right.fill"
                color = .blue
                badgeText = "回复"
            } else if fullText.contains("收藏") {
                actionText = "收藏了你发布的主题"
                icon = "star.fill"
                color = .yellow
                badgeText = "收藏"
            } else if fullText.contains("感谢") {
                actionText = "感谢了你发布的主题"
                icon = "heart.fill"
                color = .red
                badgeText = "感谢"
            } else if fullText.contains("打赏") {
                icon = "dollarsign.circle.fill"
                color = .yellow
                badgeText = "打赏"
                parsedPayload = nil

                if let payload = item.payload,
                   payload.hasPrefix("topic:"),
                   let id = Int(payload.dropFirst("topic:".count)) {
                    topicId = id
                }

                let tipLink = try doc.select("a[href^=/solana]").first()
                if let tipText = try tipLink?.text() {
                    actionText = "打赏了你 \(tipText)"
                }
            } else {
                actionText = fullText
            }

            return ParsedNotification(
                username: username,
                action: actionText,
                badgeText: badgeText,
                icon: icon,
                color: color,
                topicTitle: topicTitle,
                topicId: topicId,
                payload: parsedPayload
            )
        } catch {
            print("HTML 解析失败: \(error)")
            return nil
        }
    }
}

private struct ParsedNotification {
    let username: String
    let action: String
    let badgeText: String
    let icon: String
    let color: Color
    let topicTitle: String?
    let topicId: Int?
    let payload: String?
}

#Preview {
    let notification = Notification(
        id: 1,
        memberID: 123,
        forMemberID: 456,
        text:
            "<a href=\"/member/tomyail\" target=\"_blank\"><strong>tomyail</strong></a> 在回复 <a href=\"/t/1163971#reply3\" class=\"topic-link\">摸鱼刷 Reddit 太累了？写了个 AI 总结工具，一键看精华</a> 时提到了你",
        payload:
            "@oligi 有查询频率限制，没有次数限制,显示有2000条通知没有一键已读，强迫症都犯了强迫症都犯了强迫症都犯了强迫症都犯了",
        payloadRendered: nil,
        created: 123123,
        member: nil
    )
    NotifyRowView(item: notification) { _ in }
}
