//
//  UserInfoView.swift
//  Vole
//
//  Created by 杨权 on 9/22/25.
//

import Kingfisher
import SwiftUI

struct MemberDetailView: View {
    @Environment(\.openURL) private var openURL
    var member: Member?

    var body: some View {
        if let member = member {
            memberSections(for: member)
        } else {
            loggedOutSection
        }
    }

    @ViewBuilder
    private func memberSections(for member: Member) -> some View {
        headerSection(for: member)

        let items = accountItems(for: member)
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    accountRow(item)
                }
            }
        }
    }

    private func headerSection(for member: Member) -> some View {
        Section {
            HStack(spacing: 8) {
                avatarView(for: member)

                VStack(spacing: 8) {
                    Text(member.username)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if let id = member.id {
                        Text("第 \(id) 位会员")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let tagline = nonEmpty(member.tagline) {
                        Text("\"\(tagline)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .listRowSeparator(.hidden)

            if let bio = nonEmpty(member.bio) {
                Text(bio)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func avatarView(for member: Member) -> some View {
        if let avatarURL = member.getHighestQualityAvatar(),
            let url = URL(string: avatarURL)
        {
            KFImage(url)
                .resizable()
                .scaledToFill()
                .frame(width: 128, height: 128)
                .clipShape(Circle())
                .padding(.top, 8)
        } else {
            Circle()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 128, height: 128)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func accountRow(_ item: MemberDetailItem) -> some View {
        if let url = item.url {
            Button {
                openURL(url)
            } label: {
                accountRowContent(item)
            }
            .buttonStyle(.plain)
        } else {
            accountRowContent(item)
        }
    }

    private func accountRowContent(_ item: MemberDetailItem) -> some View {
        HStack(spacing: 12) {
            rowLabel(title: item.title, systemImage: item.systemImage)
            Spacer(minLength: 12)
            Text(item.value)
                .lineLimit(1)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func rowLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .foregroundStyle(.primary)
        }
    }

    private func accountItems(for member: Member) -> [MemberDetailItem] {
        var items: [MemberDetailItem] = []

        if let created = member.created {
            items.append(
                MemberDetailItem(
                    id: "created",
                    title: "创建日期",
                    systemImage: "calendar",
                    value: formatDate(created)
                )
            )
        }

        appendAccountItem(
            &items,
            id: "location",
            title: "所在地区",
            systemImage: "mappin.and.ellipse",
            value: member.location
        )
        appendAccountItem(
            &items,
            id: "website",
            title: "个人网站",
            systemImage: "house",
            value: member.website,
            urlString: member.website
        )
        appendAccountItem(
            &items,
            id: "btc",
            title: "BTC",
            systemImage: "bitcoinsign.ring.dashed",
            value: member.btc,
            urlString: member.btc
        )
        appendAccountItem(
            &items,
            id: "github",
            title: "GitHub",
            systemImage: "network",
            value: member.github,
            urlString: member.github.map { "https://github.com/\($0)" }
        )
        appendAccountItem(
            &items,
            id: "twitter",
            title: "Twitter",
            systemImage: "network",
            value: member.twitter,
            urlString: member.twitter.map { "https://x.com/\($0)" }
        )
        appendAccountItem(
            &items,
            id: "psn",
            title: "PSN",
            systemImage: "network",
            value: member.psn,
            urlString: member.psn.map { "https://psnprofiles.com/\($0)" }
        )

        return items
    }

    private func appendAccountItem(
        _ items: inout [MemberDetailItem],
        id: String,
        title: String,
        systemImage: String,
        value: String?,
        urlString: String? = nil
    ) {
        guard let value = nonEmpty(value) else { return }

        items.append(
            MemberDetailItem(
                id: id,
                title: title,
                systemImage: systemImage,
                value: value,
                url: makeURL(from: urlString)
            )
        )
    }

    private func makeURL(from urlString: String?) -> URL? {
        guard let urlString = nonEmpty(urlString) else { return nil }
        return URL(string: urlString)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private var loggedOutSection: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                Text("未登录")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("登录后可查看账户资料、Token 状态和个人信息")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
        }
    }
}

private struct MemberDetailItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let value: String
    let url: URL?

    init(
        id: String,
        title: String,
        systemImage: String,
        value: String,
        url: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.value = value
        self.url = url
    }
}

#Preview {
    let member = Member(
        id: 1111,
        username: "oligi",
        location: "陕西",
        tagline: "NS 巫师3 真好玩",
        bio: "我是一名爱打游戏，爱编程、喜欢打羽毛球的INTP人格",
        created: 1
    )
    MemberDetailView(member: member)
}
