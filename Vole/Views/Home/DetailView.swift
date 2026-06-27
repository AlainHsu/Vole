//
//  DetailView.swift
//  Vole
//
//  Created by 杨权 on 8/21/25.
//

import Kingfisher
import SwiftUI

struct DetailView: View {
    let topicId: Int?
    @State var topic: Topic?

    @State private var allMentions: [Int: [String]] = [:]
    @State private var selectedReply: Reply? = nil
    @State private var showSafari = false
    @State private var safariURL: URL? = nil
    @State private var showUserInfo = false
    @State private var selectedUser: Member?
    @State private var showAlert = false
    @State private var showReportDialog = false
    @State private var topicLoadErrorMessage: String?

    @StateObject private var nodeManager = NodeManager.shared
    @ObservedObject var blockManager = BlockManager.shared
    @ObservedObject private var userManager = UserManager.shared

    @State private var replies: [Reply]? = nil
    @State var isLoading = false
    var filteredReplies: [Reply]? {
        guard let r = replies else { return nil }
        return r.filter { !blockManager.isBlocked($0.member.username) }
    }

    @Environment(\.openURL) private var openURL
    @Environment(\.appOpenURL) private var appOpenURL
    @Binding var path: NavigationPath

    var body: some View {
        ZStack {
            if let topic = topic {
                // 浮层对话视图
                if let reply = selectedReply {
                    conversationView(reply, topic)
                }

                List {
                    // 帖子详情部分
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            topicHeader(for: topic)

                            if let title = topic.title {
                                topicTitleButton(title, urlString: topic.url)
                            }

                            topicEngagementMetrics(for: topic)

                            if let content = topic.content, !content.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    if content.isLikelyHTML {
                                        HTMLContentNotice(
                                            url: topic.url.flatMap(URL.init(string:)),
                                            openURL: { url in
                                                safariURL = url
                                                showSafari = true
                                            }
                                        )
                                    }

                                    VoleMarkdownView(
                                        content: content,
                                        onMentionsChanged: nil,
                                        onLinkAction: { action in
                                            switch action {
                                            case .mention(let username):
                                                print("@\(username)")
                                            case .topic(let id):
                                                path.append(Route.topicId(id))
                                            default:
                                                break
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(
                            EdgeInsets(
                                top: 14,
                                leading: 16,
                                bottom: 14,
                                trailing: 16
                            )
                        )
                    }

                    if let supplements = topic.supplements,
                        !supplements.isEmpty
                    {
                        ForEach(supplements.indices, id: \.self) {
                            idx in
                            let supplement = supplements[idx]
                            Section(
                                header: HStack {
                                    Text("第 \(idx + 1)条附言")
                                    if let created = supplement.created {
                                        TimelineView(.everyMinute) {
                                            _ in
                                            Text(
                                                DateConverter
                                                    .relativeTimeString(
                                                        created
                                                    )
                                            )
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    VoleMarkdownView(
                                        content: supplement.content ?? "",
                                        onMentionsChanged: nil,
                                        onLinkAction: { action in
                                            switch action {
                                            case .mention(let username):
                                                print("@\(username)")
                                            case .topic(let id):
                                                path.append(Route.topicId(id))
                                            default:
                                                break
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    // 评论区
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView("评论加载中")
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    } else if let replies = filteredReplies {
                        if replies.isEmpty {
                            VStack {
                                Text("暂无评论，快来抢沙发吧~")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                        } else {
                            Section(
                                header: Text(
                                    replies.count > 0
                                        ? "评论(\(replies.count))" : "评论"
                                )
                                .font(.headline)
                                .foregroundColor(.secondary)
                            ) {
                                ForEach(
                                    Array((replies).enumerated()),
                                    id: \.1.id
                                ) { index, reply in
                                    ReplyRowView(
                                        path: $path,
                                        topic: topic,
                                        reply: reply,
                                        floor: index
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(
                                            .spring(dampingFraction: 0.6)
                                        ) {
                                            selectedReply = reply
                                        }
                                    }
                                    .swipeActions(
                                        edge: .trailing,
                                        allowsFullSwipe: true
                                    ) {
                                        Button {
                                            UIPasteboard.general.string =
                                                replies[index].content

                                            let generator =
                                                UINotificationFeedbackGenerator()
                                            generator.notificationOccurred(
                                                .success
                                            )
                                        } label: {
                                            Label(
                                                "复制",
                                                systemImage: "doc.on.doc"
                                            )
                                        }
                                        .tint(.accentColor)
                                    }
                                }
                            }
                        }
                    }

                }
                .disabled(selectedReply != nil)
                .refreshable {
                    let id =  topic.id
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            await loadTopic()
                        }
                        group.addTask {
                            await loadReply(topicId: id)
                        }
                    }
                }
                .task(id: topic.id) {
                    let id =  topic.id
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            await loadTopic()
                        }
                        group.addTask {
                            await loadReply(topicId: id)
                        }
                    }
                }
            } else if let errorMessage = topicLoadErrorMessage {
                topicUnavailableView(message: errorMessage)
            } else if topicId != nil {
                // 还没有加载到 topic
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await loadTopic()
                    }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                let shareURL = topic?.url ?? ""
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed)
            }
            ToolbarItem {
                let shareURL = topic?.url ?? ""
                Menu {
                    Button("访问节点", systemImage: "scale.3d") {
                        if let topic = topic, let node = topic.node {
                            path.append(Route.node(node))
                        }
                    }
                    Button("屏蔽内容", systemImage: "text.page.slash") {
                        showAlert = true
                    }
                    Button("举报内容", systemImage: "exclamationmark.bubble") {
                        showReportDialog = true
                    }
                    Button("在浏览器中打开", systemImage: "safari") {
                        presentSafari(for: shareURL)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showSafari) {
            if let safariURL {
                SafariView(url: safariURL)
                    .ignoresSafeArea()
                    .interactiveDismissDisabled(true)
            }
        }
        .sheet(item: $selectedUser) { member in
            NavigationStack {
                memberDetailView(for: member)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .environment(\.appOpenURL) { url in
            safariURL = url
            showSafari = true
        }
        .alert("确定要屏蔽该话题吗？", isPresented: $showAlert) {
            Button("确认屏蔽", role: .destructive) {
                Task {
                    await V2exAPI.shared.blockTopic(topic: topic)
                }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(
            "选择举报原因",
            isPresented: $showReportDialog,
            titleVisibility: .visible
        ) {
            Button("垃圾广告", role: .destructive) {
                Task {
                    await V2exAPI.shared.report(topic: topic, reason: "垃圾广告")
                }
            }
            Button("色情或低俗内容", role: .destructive) {
                Task {
                    await V2exAPI.shared.report(topic: topic, reason: "色情或低俗内容")
                }
            }
            Button("人身攻击 / 仇恨言论", role: .destructive) {
                Task {
                    await V2exAPI.shared.report(
                        topic: topic,
                        reason: "人身攻击 / 仇恨言论"
                    )
                }
            }
            Button("违法或不当内容", role: .destructive) {
                Task {
                    await V2exAPI.shared.report(topic: topic, reason: "违法或不当内容")
                }
            }
            Button("其他原因", role: .destructive) {
                Task {
                    await V2exAPI.shared.report(topic: topic, reason: "其他原因")
                }
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func topicUnavailableView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "text.page.slash")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.quaternary)

            VStack(spacing: 8) {
                Text("主题不存在")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func topicHeader(for topic: Topic) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                topicAuthorView(for: topic)

                Spacer(minLength: 12)

                if let node = topic.node {
                    topicNodeButton(node)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                topicAuthorView(for: topic)

                if let node = topic.node {
                    topicNodeButton(node)
                }
            }
        }
    }

    @ViewBuilder
    private func topicAuthorView(for topic: Topic) -> some View {
        if let member = topic.member {
            Button {
                selectedUser = member
                showUserInfo = true
            } label: {
                topicAuthorContent(member: member, created: topic.created)
            }
            .buttonStyle(.plain)
        } else {
            topicAuthorContent(member: nil, created: topic.created)
        }
    }

    private func topicAuthorContent(member: Member?, created: Int?) -> some View {
        HStack(spacing: 10) {
            topicAuthorAvatar(for: member)

            VStack(alignment: .leading, spacing: 2) {
                Text(member?.username ?? "匿名用户")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let created {
                    TimelineView(.everyMinute) { _ in
                        Text(DateConverter.relativeTimeString(created))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func topicAuthorAvatar(for member: Member?) -> some View {
        if let avatarURL = member?.avatarNormal ?? member?.avatar,
            let url = URL(string: avatarURL)
        {
            KFImage(url)
                .placeholder {
                    Circle()
                        .fill(Color.gray.opacity(0.18))
                }
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func topicNodeButton(_ node: Node) -> some View {
        Button {
            if let cachedNode = nodeManager.getNode(node.id) {
                path.append(Route.node(cachedNode))
            } else {
                path.append(Route.node(node))
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "square.stack.3d.up")
                    .imageScale(.small)

                Text(node.title ?? node.name)
                    .lineLimit(1)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func topicEngagementMetrics(for topic: Topic) -> some View {
        if topic.stars != nil || topic.replies != nil {
            HStack(spacing: 14) {
                if let stars = topic.stars {
                    topicMetric(
                        value: stars,
                        label: "收藏",
                        systemImage: "star.fill",
                        tint: .yellow
                    )
                }

                if let replies = topic.replies {
                    topicMetric(
                        value: replies,
                        label: "回复",
                        systemImage: "ellipsis.bubble.fill",
                        tint: .blue
                    )
                }
            }
        }
    }

    private func topicMetric(
        value: Int,
        label: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)

            Text("\(value)")
                .fontWeight(.semibold)

            Text(label)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func topicTitleButton(_ title: String, urlString: String?) -> some View {
        Button {
            presentSafari(for: urlString)
        } label: {
            Text(title)
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityHint("打开主题原网页")
    }

    private func presentSafari(for urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        safariURL = url
        showSafari = true
    }

    // 回话视图
    @ViewBuilder
    private func conversationView(_ reply: Reply, _ topic: Topic) -> some View {
        ZStack {
            // 全屏背景模糊
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            // 浮层内容
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(
                        conversation(for: reply),
                        id: \.0.id
                    ) {
                        r,
                        floor in
                        ReplyRowView(
                            path: $path,
                            topic: topic,
                            reply: r,
                            floor: floor
                        )
                        .padding()
                        Divider()
                    }
                }
                .padding()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(dampingFraction: 0.6)) {
                    selectedReply = nil
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .transition(.opacity)
        .zIndex(1)
    }

    @ViewBuilder
    private func memberDetailView(for member: Member) -> some View {
        List {
            MemberDetailView(member: member)
        }
        .navigationTitle(member.username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(role: .destructive) {
                    showAlert = true
                } label: {
                    Image(systemName: "person.slash")
                        .foregroundStyle(.red)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    selectedUser = nil
                } label: {
                    if #available(iOS 26.0, *) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .font(.title)
                    }
                }
            }
        }
        .alert("确定要屏蔽该用户吗？", isPresented: $showAlert) {
            Button("确认屏蔽", role: .destructive) {
                withAnimation(.spring()) {
                    BlockManager.shared.block(member.username)
                }
                selectedUser = nil
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func loadTopic() async {
        guard topic == nil else { return }
        guard let id = topicId else { return }
        topicLoadErrorMessage = nil
        do {
            if userManager.token != nil {
                let response = try await V2exAPI.shared.topic(topicId: id)
                if let r = response, r.success, let newTopic = r.result {
                    topic = newTopic
                } else {
                    topicLoadErrorMessage = response?.message ?? "无法加载该主题"
                }
            } else {
                let response = try await V2exAPI.shared.topicV1(topicId: id)
                if let newTopic = response?.first {
                    topic = newTopic
                } else {
                    topicLoadErrorMessage = "无法加载该主题"
                }
            }
        } catch {
            print("❌ 获取 Topic 失败: \(error)")
            if (error as? URLError)?.code != .cancelled {
                topicLoadErrorMessage = "无法加载该主题"
            }
        }
    }

    // 获取当前点击回复的对话列表，并返回实际楼层
    private func conversation(for reply: Reply) -> [(Reply, Int)] {
        guard let replies = filteredReplies else { return [] }
        guard let idx = replies.firstIndex(where: { $0.id == reply.id }) else {
            return [(reply, 0)]
        }

        let currentUser = reply.member.username
        let mentionedUsers = extractMentionedUsers(from: reply.content)

        var conversation: [(Reply, Int)] = []

        if !mentionedUsers.isEmpty {
            // 倒序遍历，收集自己 + 被提及用户的回复
            for i in stride(from: idx, through: 0, by: -1) {
                let r = replies[i]
                if r.member.username == currentUser
                    || mentionedUsers.contains(r.member.username)
                {
                    conversation.append((r, i))
                }
            }
            return conversation.reversed()
        } else {
            // 没有提及用户：表示是发表者自己发的
            // 从当前楼层往后遍历，收集所有回复了当前用户的评论
            conversation.append((reply, idx))  // 先加自己
            for i in (idx + 1)..<replies.count {
                let r = replies[i]
                let rMentions = extractMentionedUsers(from: r.content)
                if rMentions.contains(currentUser) {
                    conversation.append((r, i))
                }
            }
            return conversation
        }
    }

    // 提取 @ 用户名
    private func extractMentionedUsers(from content: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "@([A-Za-z0-9_]+)")
        let matches = regex.matches(
            in: content,
            range: NSRange(content.startIndex..., in: content)
        )
        return matches.compactMap {
            Range($0.range(at: 1), in: content).map { String(content[$0]) }
        }
    }

    func loadReply(topicId: Int) async {
        guard replies == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let r = try await V2exAPI.shared.repliesAll(topicId: topicId)
            replies = r
        } catch {
            if (error as? URLError)?.code != .cancelled {
                print("真正的错误: \(error)")
            }
        }
    }
}

private struct HTMLContentNotice: View {
    let url: URL?
    let openURL: (URL) -> Void

    private let noticeColor = Color.yellow

    var body: some View {
        Group {
            if let url {
                Button {
                    openURL(url)
                } label: {
                    noticeContent(showsOpenIndicator: true)
                }
                .buttonStyle(.plain)
            } else {
                noticeContent(showsOpenIndicator: false)
            }
        }
    }

    private func noticeContent(showsOpenIndicator: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 4) {
                Text("该主题内容包含 HTML")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("当前页面可能无法完整显示，建议访问网页版。")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsOpenIndicator {
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.forward.app")
            }
        }
        .foregroundStyle(noticeColor)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(noticeShape.fill(noticeColor.opacity(0.12)))
        .contentShape(noticeShape)
    }

    private var noticeShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }
}

private extension String {
    var isLikelyHTML: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("<"), trimmed.contains(">") else {
            return false
        }

        return trimmed.range(
            of: Self.htmlTagPattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    static let htmlTagPattern =
        #"<\s*/?\s*(?:html|head|body|div|section|article|p|br|hr|a|img|figure|figcaption|table|thead|tbody|tr|td|th|ul|ol|li|span|strong|em|b|i|blockquote|pre|code|h[1-6]|script|style|iframe|video|audio|source)\b[^>]*>"#
}

#Preview {
    //    @Previewable @State var path = NavigationPath()
    //    let topic: Topic = ModelData().topics[0]
    //    DetailView(topicId: nil, topic: topic, path: $path)
}
