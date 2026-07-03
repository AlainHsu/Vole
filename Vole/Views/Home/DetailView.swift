//
//  DetailView.swift
//  Vole
//
//  Created by 杨权 on 8/21/25.
//

import Kingfisher
import SwiftUI

private typealias ReplyConversation = [(reply: Reply, floor: Int)]
private typealias ReplyMentionMap = [Int: Set<String>]
private let replyMentionRegex = try! NSRegularExpression(
    pattern: "@([A-Za-z0-9_]+)"
)

struct DetailView: View {
    let topicId: Int?
    @State var topic: Topic?

    @State private var selectedConversation: ReplyConversation?
    @State private var selectedConversationReplyId: Int?
    @State private var conversationByReplyId: [Int: ReplyConversation] = [:]
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
        return visibleReplies(from: r)
    }

    @Environment(\.openURL) private var openURL
    @Environment(\.appOpenURL) private var appOpenURL
    @Binding var path: NavigationPath

    var body: some View {
        ZStack {
            if let topic = topic {
                // 浮层对话视图
                if let selectedConversation {
                    conversationView(selectedConversation, topic)
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
                    commentsSection(for: topic)

                }
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
        .onChange(of: blockManager.blockedUsernames) { _, _ in
            rebuildConversationCacheFromCurrentReplies()
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
        if (topic.stars ?? 0) > 0 || (topic.thanks ?? 0) > 0
            || (topic.replies ?? 0) > 0
        {
            HStack(spacing: 14) {
                if let stars = topic.stars, stars > 0 {
                    topicMetric(
                        value: stars,
                        label: "收藏",
                        systemImage: "star.fill",
                        tint: .yellow
                    )
                }

                if let thanks = topic.thanks, thanks > 0 {
                    topicMetric(
                        value: thanks,
                        label: "感谢",
                        systemImage: "heart.fill",
                        tint: .red
                    )
                }

                if let replies = topic.replies, replies > 0 {
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

            Text(value.formattedCount)
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

    @ViewBuilder
    private func commentsSection(for topic: Topic) -> some View {
        if isLoading {
            Section {
                commentsLoadingRow
                    .listRowInsets(
                        EdgeInsets(
                            top: 0,
                            leading: 16,
                            bottom: 0,
                            trailing: 16
                        )
                    )
            } header: {
                commentsSectionHeader(count: nil)
            }
        } else if let replies = filteredReplies {
            if replies.isEmpty {
                Section {
                    commentsEmptyRow
                        .listRowInsets(
                            EdgeInsets(
                                top: 0,
                                leading: 16,
                                bottom: 0,
                                trailing: 16
                            )
                        )
                } header: {
                    commentsSectionHeader(count: 0)
                }
            } else {
                Section {
                    ForEach(
                        Array(replies.enumerated()),
                        id: \.element.id
                    ) { index, reply in
                        let conversation =
                            conversationByReplyId[reply.id]
                            ?? [(reply: reply, floor: index)]
                        let hasConversation = conversation.count > 1

                        ReplyRowView(
                            path: $path,
                            topic: topic,
                            reply: reply,
                            floor: index,
                            showsConversationIndicator: hasConversation
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if hasConversation {
                                withAnimation(.spring(dampingFraction: 0.6)) {
                                    selectedConversationReplyId = reply.id
                                    selectedConversation = conversation
                                }
                            }
                        }
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: true
                        ) {
                            Button {
                                copyReplyContent(reply.content)
                            } label: {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                            .tint(.accentColor)
                        }
                        .listRowInsets(
                            EdgeInsets(
                                top: 0,
                                leading: 16,
                                bottom: 0,
                                trailing: 16
                            )
                        )
                    }
                } header: {
                    commentsSectionHeader(count: replies.count)
                }
            }
        }
    }

    private func commentsSectionHeader(count: Int?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text("评论")
                .font(.headline)
                .foregroundStyle(.primary)

            if let count {
                Text(count.formattedCount)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    )
            }
        }
        .textCase(nil)
        .padding(.top, 4)
    }

    private var commentsLoadingRow: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text("评论加载中")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var commentsEmptyRow: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("暂无评论")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("快来抢沙发吧")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func copyReplyContent(_ content: String) {
        UIPasteboard.general.string = content
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // 对话视图
    @ViewBuilder
    private func conversationView(
        _ conversation: ReplyConversation,
        _ topic: Topic
    ) -> some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissConversation()
                }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(
                        conversation,
                        id: \.reply.id
                    ) { item in
                        ReplyRowView(
                            path: $path,
                            topic: topic,
                            reply: item.reply,
                            floor: item.floor,
                            showsConversationIndicator: false
                        )
                        .padding()
                        Divider()
                    }
                }
                .padding()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                dismissConversation()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .transition(.opacity)
        .zIndex(1)
    }

    private func dismissConversation() {
        withAnimation(.easeOut(duration: 0.16)) {
            selectedConversation = nil
            selectedConversationReplyId = nil
        }
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

    private func conversation(
        for reply: Reply,
        in replies: [Reply],
        mentionsByReplyId: ReplyMentionMap
    ) -> ReplyConversation {
        guard let idx = replies.firstIndex(where: { $0.id == reply.id }) else {
            return [(reply: reply, floor: 0)]
        }

        let currentUser = reply.member.username
        let mentionedUsers = mentionsByReplyId[reply.id, default: []]

        var conversation: [(reply: Reply, floor: Int)] = []

        if !mentionedUsers.isEmpty {
            // 倒序遍历，收集自己 + 被提及用户的回复
            for i in stride(from: idx, through: 0, by: -1) {
                let r = replies[i]
                if r.member.username == currentUser
                    || mentionedUsers.contains(r.member.username)
                {
                    conversation.append((reply: r, floor: i))
                }
            }
            return conversation.reversed()
        } else {
            // 没有提及用户：表示是发表者自己发的
            // 从当前楼层往后遍历，收集所有回复了当前用户的评论
            conversation.append((reply: reply, floor: idx))
            for i in (idx + 1)..<replies.count {
                let r = replies[i]
                let rMentions = mentionsByReplyId[r.id, default: []]
                if rMentions.contains(currentUser) {
                    conversation.append((reply: r, floor: i))
                }
            }
            return conversation
        }
    }

    private func visibleReplies(from replies: [Reply]) -> [Reply] {
        replies.filter { !blockManager.isBlocked($0.member.username) }
    }

    private func rebuildConversationCacheFromCurrentReplies() {
        guard let replies else {
            conversationByReplyId = [:]
            selectedConversation = nil
            return
        }

        rebuildConversationCache(for: visibleReplies(from: replies))
    }

    private func rebuildConversationCache(for replies: [Reply]) {
        let mentionsByReplyId = Dictionary(
            uniqueKeysWithValues: replies.map {
                ($0.id, extractMentionedUsers(from: $0.content))
            }
        )
        var cache: [Int: ReplyConversation] = [:]

        for reply in replies {
            cache[reply.id] = conversation(
                for: reply,
                in: replies,
                mentionsByReplyId: mentionsByReplyId
            )
        }

        conversationByReplyId = cache
        if let selectedConversationReplyId {
            let updatedConversation = cache[selectedConversationReplyId]
            if let updatedConversation, updatedConversation.count > 1 {
                selectedConversation = updatedConversation
            } else {
                selectedConversation = nil
                self.selectedConversationReplyId = nil
            }
        }
    }

    // 提取 @ 用户名
    private func extractMentionedUsers(from content: String) -> Set<String> {
        let matches = replyMentionRegex.matches(
            in: content,
            range: NSRange(content.startIndex..., in: content)
        )
        return Set(matches.compactMap {
            Range($0.range(at: 1), in: content).map { String(content[$0]) }
        })
    }

    func loadReply(topicId: Int) async {
        guard replies == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let r = try await V2exAPI.shared.repliesAll(topicId: topicId)
            replies = r
            if let r {
                rebuildConversationCache(for: visibleReplies(from: r))
            } else {
                conversationByReplyId = [:]
            }
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
