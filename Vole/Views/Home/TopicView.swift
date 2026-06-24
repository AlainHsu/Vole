//
//  TopicView.swift
//  Vole
//
//  Created by 杨权 on 8/17/25.
//

import Kingfisher
import SwiftUI

let formatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full  // full: 一天前, short: 1d ago
    f.locale = Locale.autoupdatingCurrent
    return f
}()

struct TopicRow: View {
    let topic: Topic
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 头像 + 昵称 + 节点
            HStack {
                if let member = topic.member {

                    if let avatarURL = member.avatarNormal,
                        let url = URL(string: avatarURL)
                    {
                        KFImage(url)
                            .placeholder {
                                Color.gray
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 24, height: 24)
                    }
                    Text(member.username)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .bold()
                    Spacer()
                    Text(topic.node?.title ?? "")
                        .font(.callout)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 8,
                                style: .continuous
                            )
                            .fill(
                                Color.accentColor.opacity(0.15)
                            )
                        )
                }
            }

            // 标题
            if let title = topic.title {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            // 内容
            if let content = topic.content {
                Text(content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            // 发布时间 + 互动数据
            HStack {
                if let created = topic.created {
                    TimelineView(.everyMinute) { _ in
                        Text(
                            DateConverter.relativeTimeString(created)
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                Spacer()

                HStack(spacing: 12) {
                    if let stars = topic.stars, stars > 0 {
                        topicMetric(
                            stars,
                            systemImage: "star.fill",
                            color: .yellow
                        )
                    }
                    if let thanks = topic.thanks, thanks > 0 {
                        topicMetric(
                            thanks,
                            systemImage: "heart.fill",
                            color: .red
                        )
                    }
                    if let replies = topic.replies {
                        topicMetric(replies, systemImage: "ellipsis.bubble")
                    }
                }
            }

        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = topic.url
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }) {
                Label("复制链接", systemImage: "link")
            }
            ShareLink(item: topic.url ?? "") {
                Label("分享", systemImage: "square.and.arrow.up")
            }
        }
        .swipeActions(
            edge: .trailing,
            allowsFullSwipe: true
        ) {
            ShareLink(item: topic.url ?? "") {
                Label("分享", systemImage: "square.and.arrow.up")
            }
            .tint(.accentColor)
        }
    }

    private func topicMetric(
        _ value: Int,
        systemImage: String,
        color: Color = .secondary
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text("\(value)")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

#Preview {
    //    let topic = ModelData().topics[0]
    //    TopicRow(topic: topic) {
    //
    //    }
}
