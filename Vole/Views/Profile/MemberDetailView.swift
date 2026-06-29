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
        Section {
            headerCard(for: member)
                .profileListRowCardStyle(top: 12, bottom: 8)
        }

        let items = accountItems(for: member)
        if !items.isEmpty {
            Section("个人资料") {
                ForEach(items) { item in
                    accountRow(item)
                }
            }
        }
    }

    private func headerCard(for member: Member) -> some View {
        VStack(spacing: 18) {
            avatarView(for: member)

            VStack(spacing: 8) {
                Text(member.username)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                if let tagline = nonEmpty(member.tagline) {
                    Text(tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            let chips = headerChips(for: member)
            if !chips.isEmpty {
                ViewThatFits {
                    HStack(spacing: 8) {
                        ForEach(chips) { chip in
                            headerChip(chip)
                        }
                    }

                    VStack(spacing: 8) {
                        ForEach(chips) { chip in
                            headerChip(chip)
                        }
                    }
                }
            }

            if let bio = nonEmpty(member.bio) {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.18),
                            Color(.secondarySystemGroupedBackground),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.accentColor.opacity(0.10), lineWidth: 1)
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
                .frame(width: 108, height: 108)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.9), lineWidth: 4)
                }
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        } else {
            Circle()
                .fill(Color.gray.opacity(0.18))
                .frame(width: 108, height: 108)
                .overlay {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                }
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
        ProfileInfoRow(
            systemImage: item.systemImage,
            tint: item.tint,
            title: item.title,
            subtitle: item.value
        ) {
            if item.url != nil {
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
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
                    tint: .indigo,
                    value: formatDate(created)
                )
            )
        }

        appendAccountItem(
            &items,
            id: "location",
            title: "所在地区",
            systemImage: "mappin.and.ellipse",
            tint: .orange,
            value: member.location
        )
        appendAccountItem(
            &items,
            id: "website",
            title: "个人网站",
            systemImage: "globe",
            tint: .blue,
            value: member.website,
            urlString: member.website
        )
        appendAccountItem(
            &items,
            id: "btc",
            title: "BTC",
            systemImage: "bitcoinsign.ring.dashed",
            tint: .brown,
            value: member.btc,
            urlString: member.btc
        )
        appendAccountItem(
            &items,
            id: "github",
            title: "GitHub",
            systemImage: "network",
            tint: .gray,
            value: member.github,
            urlString: member.github.map { "https://github.com/\($0)" }
        )
        appendAccountItem(
            &items,
            id: "twitter",
            title: "Twitter",
            systemImage: "network",
            tint: .cyan,
            value: member.twitter,
            urlString: member.twitter.map { "https://x.com/\($0)" }
        )
        appendAccountItem(
            &items,
            id: "psn",
            title: "PSN",
            systemImage: "network",
            tint: .indigo,
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
        tint: Color,
        value: String?,
        urlString: String? = nil
    ) {
        guard let value = nonEmpty(value) else { return }

        items.append(
            MemberDetailItem(
                id: id,
                title: title,
                systemImage: systemImage,
                tint: tint,
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

    private func isPro(_ member: Member) -> Bool {
        (member.pro ?? 0) > 0
    }

    private var loggedOutSection: some View {
        Section {
            VStack(spacing: 14) {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 84, height: 84)
                    .overlay {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 34))
                            .foregroundStyle(Color.accentColor)
                    }

                Text("未登录")
                    .font(.title3.weight(.bold))

                Text("登录后可查看账户资料、Token 状态和个人信息")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            }
        }
        .profileListRowCardStyle(top: 12, bottom: 8)
    }

    private func headerChips(for member: Member) -> [HeaderChip] {
        var chips: [HeaderChip] = []

        if let id = member.id {
            chips.append(
                HeaderChip(
                    id: "member-id",
                    text: "第 \(id.formatted(.number)) 位会员",
                    tint: .indigo
                )
            )
        }

        if isPro(member) {
            chips.append(
                HeaderChip(
                    id: "pro",
                    text: "Pro会员",
                    systemImage: "rosette",
                    tint: .yellow
                )
            )
        }

        return chips
    }

    private func headerChip(_ chip: HeaderChip) -> some View {
        HStack(spacing: 5) {
            if let systemImage = chip.systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }

            Text(chip.text)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(chip.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(chip.tint.opacity(0.12))
            )
    }
}

private struct MemberDetailItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let tint: Color
    let value: String
    let url: URL?

    init(
        id: String,
        title: String,
        systemImage: String,
        tint: Color,
        value: String,
        url: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.value = value
        self.url = url
    }
}

private struct HeaderChip: Identifiable {
    let id: String
    let text: String
    var systemImage: String? = nil
    let tint: Color
}

struct ProfileCardRow<Accessory: View>: View {
    let systemImage: String
    let tint: Color
    let title: String
    let subtitle: String?
    @ViewBuilder let accessory: () -> Accessory

    init(
        systemImage: String,
        tint: Color,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 12)

            accessory()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ProfileInfoRow<Accessory: View>: View {
    let systemImage: String
    let tint: Color
    let title: String
    let subtitle: String?
    @ViewBuilder let accessory: () -> Accessory

    init(
        systemImage: String,
        tint: Color,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 12)

            accessory()
        }
        .padding(.vertical, 2)
    }
}

struct ProfileStatusBadge: View {
    let text: String
    var systemImage: String? = nil
    let tint: Color
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }

            Text(text)
        }
            .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 5 : 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
    }
}

extension View {
    func profileListRowCardStyle(
        top: CGFloat = 6,
        bottom: CGFloat = 6
    ) -> some View {
        listRowInsets(
            EdgeInsets(top: top, leading: 16, bottom: bottom, trailing: 16)
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    let member = Member(
        id: 1111,
        username: "oligi",
        location: "陕西",
        tagline: "NS 巫师3 真好玩",
        bio: "我是一名爱打游戏，爱编程、喜欢打羽毛球的INTP人格",
        created: 1,
        pro: 1
    )
    MemberDetailView(member: member)
}
